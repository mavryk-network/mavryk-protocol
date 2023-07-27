use core::{ffi::c_char, slice};
use std::{
    iter,
    sync::{Arc, Mutex, MutexGuard},
};
use wasmer::{
    Cranelift, Engine, ExportType, Exports, Extern, ExternType, Function, FunctionMiddleware,
    FunctionType, ImportType, Imports, Instance, Memory, MemoryType, Module, ModuleMiddleware,
    RuntimeError, Store, Type, Value,
};
use wasmer_types::{ImportIndex, ImportKey, ModuleInfo};

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

pub struct TezosImportType(ImportType);

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_import_type_name(
    import: &TezosImportType,
) -> Box<String> {
    Box::new(import.0.name().to_string())
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_import_type_module(
    import: &TezosImportType,
) -> Box<String> {
    Box::new(import.0.module().to_string())
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_import_type_kind(import: &TezosImportType) -> u64 {
    match import.0.ty() {
        ExternType::Function(_) => 0,
        ExternType::Global(_) => 1,
        ExternType::Table(_) => 2,
        ExternType::Memory(_) => 3,
    }
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_import_type_delete_n(
    import: *mut Box<TezosImportType>,
    mut len: usize,
) {
    let mut offset = 0isize;
    while len > 0 {
        import.offset(offset).drop_in_place();
        len -= 1;
        offset += 1;
    }
}

pub struct TezosExportType(ExportType);

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_export_type_name(
    export: &TezosExportType,
) -> Box<String> {
    Box::new(export.0.name().to_string())
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_export_type_kind(export: &TezosExportType) -> u64 {
    match export.0.ty() {
        ExternType::Function(_) => 0,
        ExternType::Global(_) => 1,
        ExternType::Table(_) => 2,
        ExternType::Memory(_) => 3,
    }
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_export_type_delete_n(
    export: *mut Box<TezosExportType>,
    mut len: usize,
) {
    let mut offset = 0isize;
    while len > 0 {
        export.offset(offset).drop_in_place();
        len -= 1;
        offset += 1;
    }
}

pub struct TezosModule(Module);

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_module_new(
    engine: &TezosEngine,
    code: *const c_char,
    code_len: usize,
) -> Option<Box<TezosModule>> {
    let code = if code.is_null() {
        return None;
    } else {
        slice::from_raw_parts(code.cast(), code_len)
    };
    let module = Module::new(&engine.engine, code).ok()?;
    Some(Box::new(TezosModule(module)))
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_module_num_imports(module: &TezosModule) -> usize {
    module.0.imports().len()
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_module_imports(
    module: &TezosModule,
    imports: *mut Box<TezosImportType>,
) {
    let mut offset = 0isize;
    for typ in module.0.imports() {
        let ptr = imports.offset(offset);
        offset += 1;
        *ptr = Box::new(TezosImportType(typ));
    }
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_module_num_exports(module: &TezosModule) -> usize {
    module.0.exports().len()
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_module_exports(
    module: &TezosModule,
    exports: *mut Box<TezosExportType>,
) {
    let mut offset = 0isize;
    for typ in module.0.exports() {
        let ptr = exports.offset(offset);
        offset += 1;
        *ptr = Box::new(TezosExportType(typ));
    }
}

#[no_mangle]
pub extern "C" fn tezos_webassembly_module_delete(_module: Option<Box<TezosModule>>) {}

#[derive(Clone)]
pub struct TezosStore(Arc<Mutex<Store>>);

impl TezosStore {
    fn new(store: Store) -> Box<Self> {
        Box::new(TezosStore(Arc::new(Mutex::new(store))))
    }

    fn get(&self) -> MutexGuard<Store> {
        self.0.lock().expect("Lock poison")
    }
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_store_new(engine: &TezosEngine) -> Box<TezosStore> {
    let store = Store::new(engine.engine.clone());
    TezosStore::new(store)
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_store_delete(_store: Box<TezosStore>) {}

pub struct TezosImports(Imports);

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_imports_new() -> Box<TezosImports> {
    Box::new(TezosImports(Imports::new()))
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_imports_define(
    imports: &mut TezosImports,
    modul: Box<String>,
    name: Box<String>,
    ext: Box<TezosExtern>,
) {
    imports.0.define(modul.as_str(), name.as_str(), ext.0)
}

pub struct TezosInstance(Instance, TezosStore);

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_instance_new(
    store: &TezosStore,
    module: &TezosModule,
    imports: Box<TezosImports>,
) -> Option<Box<TezosInstance>> {
    let instance = Instance::new(&mut store.get(), &module.0, &imports.0).ok()?;
    Some(Box::new(TezosInstance(instance, store.clone())))
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_instance_delete(_instance: Option<Box<TezosInstance>>) {}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_instance_exports(
    instance: &TezosInstance,
) -> Box<TezosExports> {
    Box::new(TezosExports(&instance.0.exports, instance.1.clone()))
}

pub struct TezosExports<'a>(&'a Exports, TezosStore);

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_exports_get_function(
    exports: &TezosExports,
    name: Box<String>,
) -> Option<Box<TezosFunction>> {
    let fun = exports.0.get_function(name.as_str()).ok()?;
    Some(Box::new(TezosFunction(fun.clone(), exports.1.clone())))
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_exports_get_memory(
    exports: &TezosExports,
    name: Box<String>,
) -> Option<Box<TezosMemory>> {
    let mem = exports.0.get_memory(name.as_str()).ok()?;
    Some(Box::new(TezosMemory(mem.clone(), exports.1.clone())))
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_exports_get_memory0(
    exports: &TezosExports,
) -> Option<Box<TezosMemory>> {
    let (_, ext) = exports
        .0
        .iter()
        .find(|(_name, ext)| ext.ty(&exports.1.get()).memory().is_some())?;
    let mem = match ext {
        Extern::Memory(mem) => mem,
        _ => {
            return None;
        }
    };
    Some(Box::new(TezosMemory(mem.clone(), exports.1.clone())))
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_exports_delete(_exports: Box<TezosExports>) {}

pub struct TezosValue<'a>(&'a Value);

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_value_delete(value: Box<TezosValue>) {
    unsafe {
        let value = value.0 as *const Value as *mut Value;
        value.read();
    }
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_value_type(value: &TezosValue) -> TezosValueType {
    TezosValueType::from_wasmer(&value.0.ty())
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_value_i32(value: &TezosValue) -> i32 {
    value.0.unwrap_i32()
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_value_i64(value: &TezosValue) -> i64 {
    value.0.unwrap_i64()
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_value_f32(value: &TezosValue) -> f32 {
    value.0.unwrap_f32()
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_value_f64(value: &TezosValue) -> f64 {
    value.0.unwrap_f64()
}

#[repr(C)]
pub enum TezosValueType {
    I32,
    I64,
    F32,
    F64,
    V128,
    ExternRef,
    FuncRef,
}

impl TezosValueType {
    fn to_wasmer(&self) -> Type {
        match self {
            TezosValueType::I32 => Type::I32,
            TezosValueType::I64 => Type::I64,
            TezosValueType::F32 => Type::F32,
            TezosValueType::F64 => Type::F64,
            TezosValueType::V128 => Type::V128,
            TezosValueType::ExternRef => Type::ExternRef,
            TezosValueType::FuncRef => Type::FuncRef,
        }
    }

    fn from_wasmer(value: &Type) -> Self {
        match value {
            Type::I32 => TezosValueType::I32,
            Type::I64 => TezosValueType::I64,
            Type::F32 => TezosValueType::F32,
            Type::F64 => TezosValueType::F64,
            Type::V128 => TezosValueType::V128,
            Type::ExternRef => TezosValueType::ExternRef,
            Type::FuncRef => TezosValueType::FuncRef,
        }
    }
}

pub struct TezosFunctionType(FunctionType);

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_function_type_new(
    inputs: *const TezosValueType,
    inputs_len: usize,
    outputs: *const TezosValueType,
    outputs_len: usize,
) -> Box<TezosFunctionType> {
    let params: Box<[Type]> = Box::from_iter(
        slice::from_raw_parts(inputs, inputs_len)
            .into_iter()
            .map(TezosValueType::to_wasmer),
    );
    let returns: Box<[Type]> = Box::from_iter(
        slice::from_raw_parts(outputs, outputs_len)
            .into_iter()
            .map(TezosValueType::to_wasmer),
    );
    Box::new(TezosFunctionType(FunctionType::new(params, returns)))
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_function_type_num_params(
    funtype: &TezosFunctionType,
) -> usize {
    funtype.0.params().len()
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_function_type_params(
    funtype: &TezosFunctionType,
    params: *mut TezosValueType,
) {
    let mut offset = 0isize;
    for param in funtype.0.params() {
        let ptr = params.offset(offset);
        offset += 1;
        *ptr = TezosValueType::from_wasmer(param);
    }
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_function_type_num_results(
    funtype: &TezosFunctionType,
) -> usize {
    funtype.0.results().len()
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_function_type_results(
    funtype: &TezosFunctionType,
    results: *mut TezosValueType,
) {
    let mut offset = 0isize;
    for param in funtype.0.results() {
        let ptr = results.offset(offset);
        offset += 1;
        *ptr = TezosValueType::from_wasmer(param);
    }
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_function_type_delete(_funtype: Box<TezosFunctionType>) {}

pub struct TezosFunction(Function, TezosStore);

pub type TezosFunctionCallback = unsafe extern "C" fn(
    args: *const Box<TezosValue>,
    results: &mut Vec<Value>,
) -> Option<Box<String>>;

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_function_new(
    store: &TezosStore,
    typ: Box<TezosFunctionType>,
    fun: TezosFunctionCallback,
) -> Box<TezosFunction> {
    let num_params = typ.0.results().len();
    let fun = Function::new(&mut store.get(), typ.0, move |inputs| {
        let inputs: Vec<_> = inputs.iter().map(|v| Box::new(TezosValue(v))).collect();
        let mut results = Vec::with_capacity(num_params);
        match (fun)(inputs.as_ptr(), &mut results) {
            Some(msg) => Err(RuntimeError::new(*msg)),
            None => Ok(results),
        }
    });
    Box::new(TezosFunction(fun, store.clone()))
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_function_call(
    fun: &TezosFunction,
    inputs: Box<Vec<Value>>,
    outputs: *mut Box<TezosValue>,
) -> Option<Box<String>> {
    match fun.0.call(&mut fun.1.get(), &inputs) {
        Ok(results) => {
            for (i, value) in results.into_vec().into_iter().enumerate() {
                let value = Box::leak(Box::new(value));
                outputs
                    .offset(i.try_into().ok()?)
                    .write(Box::new(TezosValue(value)));
            }
            None
        }
        Err(err) => Some(Box::new(err.to_string())),
    }
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_function_type(
    fun: &TezosFunction,
) -> Box<TezosFunctionType> {
    Box::new(TezosFunctionType(fun.0.ty(&fun.1.get())))
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_function_num_results(fun: &TezosFunction) -> usize {
    fun.0.param_arity(&mut fun.1.get())
}

pub struct TezosMemory(Memory, TezosStore);

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_memory_new(
    store: &TezosStore,
    pages: u32,
) -> Option<Box<TezosMemory>> {
    let ty = MemoryType::new(pages, None, false);
    let mem = Memory::new(&mut store.get(), ty).ok()?;
    Some(Box::new(TezosMemory(mem, store.clone())))
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_memory_data_size(mem: &TezosMemory) -> u64 {
    mem.0.view(&mem.1.get()).data_size()
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_memory_read_u8(mem: &TezosMemory, offset: u64) -> u16 {
    match mem.0.view(&mem.1.get()).read_u8(offset).ok() {
        Some(r) => r as u16,
        None => u16::MAX,
    }
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_memory_write_u8(
    mem: &TezosMemory,
    offset: u64,
    value: u8,
) -> bool {
    mem.0.view(&mem.1.get()).write_u8(offset, value).is_ok()
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_memory_read(
    mem: &TezosMemory,
    offset: u64,
    data: *mut u8,
    length: usize,
) -> bool {
    mem.0
        .view(&mem.1.get())
        .read(offset, slice::from_raw_parts_mut(data, length))
        .is_ok()
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_memory_write(
    mem: &TezosMemory,
    offset: u64,
    data: *const u8,
    length: usize,
) -> bool {
    mem.0
        .view(&mem.1.get())
        .write(offset, slice::from_raw_parts(data, length))
        .is_ok()
}

pub struct TezosExtern(Extern);

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_extern_from_function(
    fun: Box<TezosFunction>,
) -> Box<TezosExtern> {
    Box::new(TezosExtern(Extern::Function(fun.0)))
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_extern_delete_n(
    externs: *mut Box<TezosExtern>,
    mut len: usize,
) {
    let mut offset = 0isize;
    while len > 0 {
        externs.offset(offset).drop_in_place();
        len -= 1;
        offset += 1;
    }
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_value_vec_new(cap: usize) -> Box<Vec<Value>> {
    Box::new(Vec::with_capacity(cap))
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
pub unsafe extern "C" fn tezos_webassembly_value_vec_add_f32(vec: &mut Vec<Value>, value: f32) {
    vec.push(Value::F32(value))
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_value_vec_add_f64(vec: &mut Vec<Value>, value: f64) {
    vec.push(Value::F64(value))
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_string_new(mut str: *const c_char) -> Box<String> {
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

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_string_contents(str: &String) -> *const char {
    str.as_str().as_ptr() as *const char
}

#[no_mangle]
pub unsafe extern "C" fn tezos_webassembly_string_delete(_str: Option<Box<String>>) {}
