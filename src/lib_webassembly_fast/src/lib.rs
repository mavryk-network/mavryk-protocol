use core::ffi::c_char;
use core::slice;
use std::iter;
use wasmer::{
    CompileError, Cranelift, Engine, Extern, Function, FunctionMiddleware, Imports, Instance,
    Module, ModuleMiddleware, RuntimeError, Store,
};
use wasmer_types::compilation::symbols::ModuleMetadataSymbolRegistry;
use wasmer_types::{ImportIndex, ImportKey, ModuleInfo};

pub use wasmer::FunctionType;
pub use wasmer::Value;

#[derive(Debug)]
struct DummyFunctionMiddleware;

impl FunctionMiddleware for DummyFunctionMiddleware {}

#[derive(Debug)]
struct ImportMemoryMiddleware;

impl ModuleMiddleware for ImportMemoryMiddleware {
    fn generate_function_middleware(
        &self,
        _local_function_index: wasmer::LocalFunctionIndex,
    ) -> Box<dyn wasmer::FunctionMiddleware> {
        Box::new(DummyFunctionMiddleware)
    }

    fn transform_module_info(&self, info: &mut ModuleInfo) {
        for (idx, _ty) in &info.memories {
            info.imports.insert(
                ImportKey {
                    module: "env".to_string(),
                    field: format!("memory{}", idx.as_u32()),
                    import_idx: info.imports.len() as u32,
                },
                ImportIndex::Memory(idx),
            );
        }
    }
}

pub struct TezosEngine {
    engine: Engine,
}

ocaml::custom!(TezosEngine);

#[ocaml::func]
pub fn engine_new() -> TezosEngine {
    let mut engine = Cranelift::new();
    engine.canonicalize_nans(true);
    TezosEngine {
        engine: engine.into(),
    }
}

#[no_mangle]
pub extern "C" fn tezos_webassembly_engine_new() -> Box<TezosEngine> {
    let mut engine = Cranelift::new();
    engine.canonicalize_nans(true);
    Box::new(TezosEngine {
        engine: engine.into(),
    })
}

#[no_mangle]
pub extern "C" fn tezos_webassembly_engine_delete(_engine: Box<TezosEngine>) {}

pub struct TezosModule {
    module: Module,
}

ocaml::custom!(TezosModule);

#[ocaml::func]
pub fn module_new(
    engine: ocaml::Pointer<TezosEngine>,
    code: String,
) -> (Option<TezosModule>, Option<String>) {
    let engine = &engine.as_ref().engine;
    let module = match Module::new(engine, &code) {
        Ok(m) => m,
        Err(err) => return (None, Some(err.to_string())),
    };
    (Some(TezosModule { module }), None)
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_module_new(
    engine: Option<&TezosEngine>,
    code: *const c_char,
    code_len: usize,
) -> Option<Box<TezosModule>> {
    let engine = engine?;
    let code = if code.is_null() {
        return None;
    } else {
        slice::from_raw_parts(code.cast(), code_len)
    };
    let module = Module::new(&engine.engine, code).ok()?;
    Some(Box::new(TezosModule { module }))
}

#[no_mangle]
pub extern "C" fn tezos_webassembly_module_delete(_module: Box<TezosModule>) {}

pub struct TezosStore {
    store: Store,
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_store_new(engine: &TezosEngine) -> Box<TezosStore> {
    let store = Store::new(engine.engine.clone());
    Box::new(TezosStore { store })
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_store_delete(_store: Box<TezosStore>) {}

pub struct TezosInstance {
    instance: Instance,
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_instance_new(
    store: &mut TezosStore,
    module: &TezosModule,
    imports: *mut *mut TezosImport,
) -> Option<Box<TezosInstance>> {
    let import_items = if imports.is_null() {
        return None;
    } else {
        let mut index = 0;
        let iter = iter::from_fn(move || {
            let ptr = imports.offset(index).read();
            if ptr.is_null() {
                None
            } else {
                index += 1;
                Some(ptr.read())
            }
        });
        iter
    };

    let mut imports = Imports::new();
    imports.register_namespace(
        "smart_rollup_core",
        import_items.map(|import| (import.name, *import.value)),
    );

    let instance = Instance::new(&mut store.store, &module.module, &imports).ok()?;
    Some(Box::new(TezosInstance { instance }))
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_instance_delete(_instance: Box<TezosInstance>) {}

pub struct TezosImport {
    name: String,
    value: Box<Extern>,
}

pub type FunctionCallback =
    unsafe extern "C" fn(args: *const Value, results: &mut Vec<Value>) -> Option<Box<String>>;

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_import_new_function(
    store: &mut TezosStore,
    name: *const c_char,
    name_len: usize,
    typ: Box<FunctionType>,
    fun: FunctionCallback,
) -> Option<Box<TezosImport>> {
    let name = String::from_utf8(Vec::from(slice::from_raw_parts(name.cast(), name_len))).ok()?;
    let fun = Function::new(&mut store.store, *typ, move |inputs| {
        let mut results = Vec::new();
        match (fun)(inputs.as_ptr(), &mut results) {
            Some(msg) => Err(RuntimeError::new(*msg)),
            None => Ok(results),
        }
    });
    let value = Box::new(Extern::Function(fun));
    Some(Box::new(TezosImport { name, value }))
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_value_vec_new(capacity: usize) -> Box<Vec<Value>> {
    Box::new(Vec::with_capacity(capacity))
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_value_vec_add_i32(vec: &mut Vec<Value>, value: i32) {
    vec.push(Value::I32(value))
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_value_vec_add_i64(vec: &mut Vec<Value>, value: i64) {
    vec.push(Value::I64(value))
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_value_string_new(mut str: *const c_char) -> Box<String> {
    let str = if str.is_null() {
        String::new()
    } else {
        String::from_iter(iter::from_fn(|| {
            let char = *str;
            str = str.offset(1);

            if char == 0 {
                None
            } else {
                char::from_u32(char as u32)
            }
        }))
    };
    Box::new(str)
}
