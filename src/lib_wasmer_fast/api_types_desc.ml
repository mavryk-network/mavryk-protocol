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

module Types (S : Ctypes.TYPE) = struct
  open S

  module Make_type (P : sig
    val name : string
  end) =
  struct
    type s

    type t = s Ctypes.structure

    let t : t typ = typedef (structure P.name) P.name
  end

  module Engine = Make_type (struct
    let name = "TezosEngine"
  end)

  module Store = Make_type (struct
    let name = "TezosStore"
  end)

  module Module = Make_type (struct
    let name = "TezosModule"
  end)

  module ImportType = Make_type (struct
    let name = "TezosImportType"
  end)

  module ExportType = Make_type (struct
    let name = "TezosExportType"
  end)

  module ValueType = struct
    type t = I32 | I64 | F32 | F64 | V128 | ExternRef | FuncRef
    [@@deriving show, eq]

    let t : t typ =
      let name = "TezosValueType" in
      typedef
        (enum
           name
           [
             (I32, constant "I32" int64_t);
             (I64, constant "I64" int64_t);
             (F32, constant "F32" int64_t);
             (F64, constant "F64" int64_t);
             (V128, constant "V128" int64_t);
             (ExternRef, constant "ExternRef" int64_t);
             (FuncRef, constant "FuncRef" int64_t);
           ])
        name
  end

  module FunctionType = Make_type (struct
    let name = "TezosFunctionType"
  end)

  module Value = Make_type (struct
    let name = "TezosValue"
  end)

  module ValueVector = Make_type (struct
    let name = "Vec_Value"
  end)

  module Function = Make_type (struct
    let name = "TezosFunction"
  end)

  module String = Make_type (struct
    let name = "String"
  end)

  module FunctionCallback = struct
    let fn =
      ptr (ptr Value.t) @-> ptr ValueVector.t @-> returning (ptr_opt String.t)

    let m =
      Foreign.dynamic_funptr ~runtime_lock:true ~thread_registration:true fn

    let t = static_funptr fn
  end

  module Extern = Make_type (struct
    let name = "TezosExtern"
  end)

  module Imports = Make_type (struct
    let name = "TezosImports"
  end)

  module Instance = Make_type (struct
    let name = "TezosInstance"
  end)

  module Exports = Make_type (struct
    let name = "TezosExports"
  end)

  module Memory = Make_type (struct
    let name = "TezosMemory"
  end)
end
