(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2022 Nomadic Labs, <contact@nomadic-labs.com>               *)
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

let of_memory_tree (t : Mavryk_context_memory.Context.tree) :
    Mavryk_protocol_environment.Proxy_delegate.t =
  (module struct
    let proxy_dir_mem key =
      let open Lwt_syntax in
      let* v = Mavryk_context_memory.Context.Tree.mem_tree t key in
      return_ok v

    let proxy_get key =
      let open Lwt_syntax in
      let* v = Mavryk_context_memory.Context.Tree.find_tree t key in
      return_ok v

    let proxy_mem key =
      let open Lwt_syntax in
      let* v = Mavryk_context_memory.Context.Tree.mem t key in
      return_ok v
  end : Mavryk_protocol_environment.Proxy_delegate.T)

let of_memory_context (m : Mavryk_context_memory.Context.t) :
    Mavryk_protocol_environment.Proxy_delegate.t =
  (module struct
    let proxy_dir_mem key =
      let open Lwt_syntax in
      let* v = Mavryk_context_memory.Context.mem_tree m key in
      return_ok v

    let proxy_get key =
      let open Lwt_syntax in
      let* v = Mavryk_context_memory.Context.find_tree m key in
      return_ok v

    let proxy_mem key =
      let open Lwt_syntax in
      let* v = Mavryk_context_memory.Context.mem m key in
      return_ok v
  end : Mavryk_protocol_environment.Proxy_delegate.T)

let make_index ~(context_path : string) : Mavryk_context.Context.index Lwt.t =
  Mavryk_context.Context.init ~readonly:true context_path

let of_index ~(index : Mavryk_context.Context.index)
    (hash : Mavryk_crypto.Hashed.Context_hash.t) :
    Mavryk_protocol_environment.Proxy_delegate.t tzresult Lwt.t =
  let open Lwt_syntax in
  let* ctxt = Mavryk_context.Context.checkout index hash in
  match ctxt with
  | None ->
      failwith
        "Couldn't check out the hash %s"
        (Mavryk_crypto.Hashed.Context_hash.to_string hash)
  | Some ctxt ->
      let proxy_data_dir : Mavryk_protocol_environment.Proxy_delegate.t =
        (module struct
          let proxy_dir_mem (key : Mavryk_context.Context.key) :
              bool tzresult Lwt.t =
            let* (res : bool) = Mavryk_context.Context.mem_tree ctxt key in
            return_ok res

          let proxy_get (key : Mavryk_context.Context.key) :
              Mavryk_context_memory.Context.tree option tzresult Lwt.t =
            let* res = Mavryk_context.Context.to_memory_tree ctxt key in
            return_ok res

          let proxy_mem (key : Mavryk_context.Context.key) : bool tzresult Lwt.t
              =
            let* res = Mavryk_context.Context.mem ctxt key in
            return_ok res
        end)
      in
      return_ok proxy_data_dir
