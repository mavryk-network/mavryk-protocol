(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2023 Trili Tech, <contact@trili.tech>                       *)
(* Copyright (c) 2023 Marigold  <contact@tmarigold.dev>                      *)
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

module V0 = struct
  let v0_prefix = Api_version.v0_prefix

  let get_preimage =
    Mavryk_rpc.Service.get_service
      ~description:"Retrieves a page by its page hash and returns its contents"
      ~query:Mavryk_rpc.Query.empty
      ~output:Data_encoding.bytes
      Mavryk_rpc.Path.(v0_prefix / "preimage" /: Dac_plugin.raw_hash_rpc_arg)

  let put_dac_member_signature =
    Mavryk_rpc.Service.put_service
      ~description:
        "Verifies and stores the Dac member signature of a root page hash"
      ~query:Mavryk_rpc.Query.empty
      ~input:Signature_repr.encoding
      ~output:Data_encoding.empty
      Mavryk_rpc.Path.(v0_prefix / "dac_member_signature")

  let get_certificate =
    Mavryk_rpc.Service.get_service
      ~description:
        "Retrieve the Dac certificate associated with the given root page hash"
      ~query:Mavryk_rpc.Query.empty
      ~output:Certificate_repr.encoding
      Mavryk_rpc.Path.(
        v0_prefix / "certificates" /: Dac_plugin.raw_hash_rpc_arg)

  let get_serialized_certificate =
    Mavryk_rpc.Service.get_service
      ~description:
        "Retrieve the Dac certificate encoded in binary associated with the \
         given root page hash. The contained [root_hash] is compatible with \
         Kernel SDK."
      ~query:Mavryk_rpc.Query.empty
      ~output:Data_encoding.(option (string' Hex))
      Mavryk_rpc.Path.(
        v0_prefix / "serialized_certificates" /: Dac_plugin.raw_hash_rpc_arg)

  let get_missing_page =
    Mavryk_rpc.Service.get_service
      ~description:
        "Fetch a given page by forwarding the request to a Coordinator's GET \
         /preimage. The page is then saved to the node's page store before \
         being returned in the response. The endpoint should only be exposed \
         in Observer mode."
      ~query:Mavryk_rpc.Query.empty
      ~output:Data_encoding.bytes
      Mavryk_rpc.Path.(
        v0_prefix / "missing_page" /: Dac_plugin.raw_hash_rpc_arg)

  (* TODO: https://gitlab.com/tezos/tezos/-/issues/4935
     Coordinator's "POST /preimage" endpoint should in addition to root page hash
     also return expiration level. Additionally, when it pushes a new root hash to
     all attached subscribers, it should push it together with expiration level. *)

  module Coordinator = struct
    (** [Coordinator]'s endpoint for serializing dac payload. In addition to
    returning a root page hash, it also pushes it to the subscribed [Observer]s
    and [Dac_member]s. *)
    let post_preimage =
      Mavryk_rpc.Service.post_service
        ~description:
          "Stores the preimage in a sequence of pages. Returns a root page \
           hash representing the stored preimage. Additionally, it triggers \
           streaming of root page hash to subscribed committee members and \
           observers. "
        ~query:Mavryk_rpc.Query.empty
        ~input:Data_encoding.bytes
        ~output:Dac_plugin.raw_hash_encoding
        Mavryk_rpc.Path.(v0_prefix / "preimage")
  end
end

let get_health_live =
  Mavryk_rpc.Service.get_service
    ~description:"Check that DAC node is alive"
    ~query:Mavryk_rpc.Query.empty
    ~output:Data_encoding.bool
    Mavryk_rpc.Path.(open_root / "health" / "live")

let get_health_ready =
  Mavryk_rpc.Service.get_service
    ~description:"Check that DAC node is ready"
    ~query:Mavryk_rpc.Query.empty
    ~output:Data_encoding.bool
    Mavryk_rpc.Path.(open_root / "health" / "ready")

module V1 = struct
  let v1_prefix = Api_version.v1_prefix

  let get_pages =
    Mavryk_rpc.Service.get_service
      ~description:"Retrieves a page by its page hash and returns its contents"
      ~query:Mavryk_rpc.Query.empty
      ~output:Data_encoding.bytes
      Mavryk_rpc.Path.(v1_prefix / "pages" /: Dac_plugin.raw_hash_rpc_arg)
end
