(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2022 TriliTech <contact@trili.tech>                         *)
(*                                                                           *)
(* Permission is hereby granted, free of charge, to any person obtaining a   *)
(* copy of this software and associated documentation files (the "Software"),*)
(* to deal in the Software without restriction, including without limitation *)
(* the rights to use, copy, modify, merge, publish, distribute, sublicense,  *)
(* and/or sell copies of the Software, and to permit persons to whom the     *)
(* Software is furnished to do so, subject to the following conditions:      *)
(*                                                                           *)
(* The above copyright notice and this permission notice shall be included   *)
(* in all copies or substantial portions of the Software.                    *)
(*                                                                           *)
(* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR*)
(* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  *)
(* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL   *)
(* THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER*)
(* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING   *)
(* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER       *)
(* DEALINGS IN THE SOFTWARE.                                                 *)
(*                                                                           *)
(*****************************************************************************)

open Ctypes
module Types = Api_types

module Functions (S : FOREIGN) = struct
  open S

  module Engine = struct
    let new_ =
      foreign
        "tezos_webassembly_engine_new"
        (void @-> returning (ptr Types.Engine.t))

    let delete =
      foreign
        "tezos_webassembly_engine_delete"
        (ptr Types.Engine.t @-> returning void)
  end

  module Store = struct
    let new_ =
      foreign
        "tezos_webassembly_store_new"
        (ptr Types.Engine.t @-> returning (ptr Types.Store.t))

    let delete =
      foreign
        "tezos_webassembly_store_delete"
        (ptr Types.Store.t @-> returning void)
  end

  module Module = struct
    let new_ =
      foreign
        "tezos_webassembly_module_new"
        (ptr Types.Engine.t @-> string @-> size_t
        @-> returning (ptr Types.Module.t))

    let num_imports =
      foreign
        "tezos_webassembly_module_num_imports"
        (ptr Types.Module.t @-> returning size_t)

    let imports =
      foreign
        "tezos_webassembly_module_imports"
        (ptr Types.Module.t @-> ptr (ptr Types.ImportType.t) @-> returning void)

    let num_exports =
      foreign
        "tezos_webassembly_module_num_exports"
        (ptr Types.Module.t @-> returning size_t)

    let exports =
      foreign
        "tezos_webassembly_module_exports"
        (ptr Types.Module.t @-> ptr (ptr Types.ExportType.t) @-> returning void)

    let delete =
      foreign
        "tezos_webassembly_module_delete"
        (ptr Types.Module.t @-> returning void)
  end

  module ImportType = struct
    let delete_n =
      foreign
        "tezos_webassembly_import_type_delete_n"
        (ptr (ptr Types.ImportType.t) @-> size_t @-> returning void)

    let module_ =
      foreign
        "tezos_webassembly_import_type_module"
        (ptr Types.ImportType.t @-> returning (ptr Types.String.t))

    let name =
      foreign
        "tezos_webassembly_import_type_name"
        (ptr Types.ImportType.t @-> returning (ptr Types.String.t))

    let kind =
      foreign
        "tezos_webassembly_import_type_kind"
        (ptr Types.ImportType.t @-> returning uint64_t)
  end

  module ExportType = struct
    let delete_n =
      foreign
        "tezos_webassembly_export_type_delete_n"
        (ptr (ptr Types.ExportType.t) @-> size_t @-> returning void)
  end

  module ValueType = struct end

  module FunctionType = struct
    let new_ =
      foreign
        "tezos_webassembly_function_type_new"
        (ptr Types.ValueType.t @-> size_t @-> ptr Types.ValueType.t @-> size_t
        @-> returning (ptr Types.FunctionType.t))

    let delete =
      foreign
        "tezos_webassembly_function_type_delete"
        (ptr Types.FunctionType.t @-> returning void)

    let num_params =
      foreign
        "tezos_webassembly_function_type_num_params"
        (ptr Types.FunctionType.t @-> returning size_t)

    let params =
      foreign
        "tezos_webassembly_function_type_params"
        (ptr Types.FunctionType.t @-> ptr Types.ValueType.t @-> returning void)

    let num_results =
      foreign
        "tezos_webassembly_function_type_num_results"
        (ptr Types.FunctionType.t @-> returning size_t)

    let results =
      foreign
        "tezos_webassembly_function_type_results"
        (ptr Types.FunctionType.t @-> ptr Types.ValueType.t @-> returning void)
  end

  module Value = struct
    let delete =
      foreign
        "tezos_webassembly_value_delete"
        (ptr Types.Value.t @-> returning void)

    let type_ =
      foreign
        "tezos_webassembly_value_type"
        (ptr Types.Value.t @-> returning Types.ValueType.t)

    let i32 =
      foreign
        "tezos_webassembly_value_i32"
        (ptr Types.Value.t @-> returning int32_t)

    let i64 =
      foreign
        "tezos_webassembly_value_i64"
        (ptr Types.Value.t @-> returning int64_t)

    let f32 =
      foreign
        "tezos_webassembly_value_f32"
        (ptr Types.Value.t @-> returning float)

    let f64 =
      foreign
        "tezos_webassembly_value_f64"
        (ptr Types.Value.t @-> returning double)
  end

  module ValueVector = struct
    let new_ =
      foreign
        "tezos_webassembly_value_vec_new"
        (size_t @-> returning (ptr Types.ValueVector.t))

    let add_i32 =
      foreign
        "tezos_webassembly_value_vec_add_i32"
        (ptr Types.ValueVector.t @-> int32_t @-> returning void)

    let add_i64 =
      foreign
        "tezos_webassembly_value_vec_add_i64"
        (ptr Types.ValueVector.t @-> int64_t @-> returning void)

    let add_f32 =
      foreign
        "tezos_webassembly_value_vec_add_f32"
        (ptr Types.ValueVector.t @-> float @-> returning void)

    let add_f64 =
      foreign
        "tezos_webassembly_value_vec_add_f64"
        (ptr Types.ValueVector.t @-> double @-> returning void)
  end

  module String = struct
    let new_ =
      foreign
        "tezos_webassembly_string_new"
        (string @-> returning (ptr Types.String.t))

    let delete =
      foreign
        "tezos_webassembly_string_delete"
        (ptr Types.String.t @-> returning void)

    let contents =
      foreign
        "tezos_webassembly_string_contents"
        (ptr Types.String.t @-> returning string)
  end

  module Function = struct
    let new_ =
      foreign
        "tezos_webassembly_function_new"
        (ptr Types.Store.t @-> ptr Types.FunctionType.t
       @-> Types.FunctionCallback.t
        @-> returning (ptr Types.Function.t))

    let type_ =
      foreign
        "tezos_webassembly_function_type"
        (ptr Types.Function.t @-> returning (ptr Types.FunctionType.t))

    let num_results =
      foreign
        "tezos_webassembly_function_num_results"
        (ptr Types.Function.t @-> returning size_t)

    let call =
      foreign
        "tezos_webassembly_function_call"
        (ptr Types.Function.t @-> ptr Types.ValueVector.t
        @-> ptr (ptr Types.Value.t)
        @-> returning (ptr_opt Types.String.t))
  end

  module Extern = struct
    let from_function =
      foreign
        "tezos_webassembly_extern_from_function"
        (ptr Types.Function.t @-> returning (ptr Types.Extern.t))

    let delete_n =
      foreign
        "tezos_webassembly_extern_delete_n"
        (ptr (ptr Types.Extern.t) @-> size_t @-> returning void)
  end

  module Imports = struct
    let new_ =
      foreign
        "tezos_webassembly_imports_new"
        (void @-> returning (ptr Types.Imports.t))

    let define =
      foreign
        "tezos_webassembly_imports_define"
        (ptr Types.Imports.t @-> ptr Types.String.t @-> ptr Types.String.t
       @-> ptr Types.Extern.t @-> returning void)
  end

  module Instance = struct
    let new_ =
      foreign
        "tezos_webassembly_instance_new"
        (ptr Types.Store.t @-> ptr Types.Module.t @-> ptr Types.Imports.t
        @-> returning (ptr Types.Instance.t))

    let exports =
      foreign
        "tezos_webassembly_instance_exports"
        (ptr Types.Instance.t @-> returning (ptr Types.Exports.t))

    let delete =
      foreign
        "tezos_webassembly_instance_delete"
        (ptr Types.Instance.t @-> returning void)
  end

  module Exports = struct
    let get_function =
      foreign
        "tezos_webassembly_exports_get_function"
        (ptr Types.Exports.t @-> ptr Types.String.t
        @-> returning (ptr_opt Types.Function.t))

    let get_memory =
      foreign
        "tezos_webassembly_exports_get_memory"
        (ptr Types.Exports.t @-> ptr Types.String.t
        @-> returning (ptr_opt Types.Memory.t))

    let get_memory0 =
      foreign
        "tezos_webassembly_exports_get_memory0"
        (ptr Types.Exports.t @-> returning (ptr_opt Types.Memory.t))

    let delete =
      foreign
        "tezos_webassembly_exports_delete"
        (ptr Types.Exports.t @-> returning void)
  end

  module Memory = struct
    let new_ =
      foreign
        "tezos_webassembly_memory_new"
        (ptr Types.Store.t @-> uint32_t @-> returning (ptr Types.Memory.t))

    let data_size =
      foreign
        "tezos_webassembly_memory_data_size"
        (ptr Types.Memory.t @-> returning uint64_t)

    let read_u8 =
      foreign
        "tezos_webassembly_memory_read_u8"
        (ptr Types.Memory.t @-> uint64_t @-> returning uint16_t)

    let read =
      foreign
        "tezos_webassembly_memory_read"
        (ptr Types.Memory.t @-> uint64_t @-> ptr uint8_t @-> size_t
       @-> returning bool)

    let write_u8 =
      foreign
        "tezos_webassembly_memory_write_u8"
        (ptr Types.Memory.t @-> uint64_t @-> uint8_t @-> returning bool)

    let write =
      foreign
        "tezos_webassembly_memory_write"
        (ptr Types.Memory.t @-> uint64_t @-> ptr uint8_t @-> size_t
       @-> returning bool)
  end
end
