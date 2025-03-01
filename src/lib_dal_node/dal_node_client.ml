(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2022 Trili Tech <contact@trili.tech>                        *)
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

open Mavryk_dal_node_services

class type cctxt =
  object
    inherit Mavryk_rpc.Context.generic
  end

class unix_cctxt ~rpc_config : cctxt =
  object
    inherit
      Mavryk_rpc_http_client_unix.RPC_client_unix.http_ctxt
        rpc_config
        (Mavryk_rpc_http.Media_type.Command_line.of_command_line
           rpc_config.media_type)
  end

let make_unix_cctxt endpoint =
  let rpc_config =
    {Mavryk_rpc_http_client_unix.RPC_client_unix.default_config with endpoint}
  in
  new unix_cctxt ~rpc_config

let call (cctxt : #cctxt) = cctxt#call_service

let get_slot cctxt header =
  call cctxt Services.get_commitment_slot ((), header) () ()

let get_slot_pages cctxt header =
  call cctxt Services.slot_pages ((), header) () ()

let get_page_proof cctxt page_index slot_data =
  call cctxt Services.get_page_proof ((), page_index) () slot_data
