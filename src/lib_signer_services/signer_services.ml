(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2018 Dynamic Ledger Solutions, Inc. <contact@tezos.com>     *)
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

let query =
  let open Mavryk_rpc.Query in
  query (fun signature -> signature)
  |+ opt_field
       ~descr:
         "Must be provided if the signer requires authentication. In this \
          case, it must be the signature of the public key hash and message \
          concatenated, by one of the keys authorized by the signer."
       "authentication"
       Mavryk_crypto.Signature.rpc_arg
       (fun signature -> signature)
  |> seal

let sign =
  Mavryk_rpc.Service.post_service
    ~description:"Sign a piece of data with a given remote key"
    ~query
    ~input:Data_encoding.bytes
    ~output:
      Data_encoding.(obj1 (req "signature" Mavryk_crypto.Signature.encoding))
    Mavryk_rpc.Path.(
      root / "keys" /: Mavryk_crypto.Signature.Public_key_hash.rpc_arg)

let deterministic_nonce =
  Mavryk_rpc.Service.post_service
    ~description:
      "Obtain some random data generated deterministically from some piece of \
       data with a given remote key"
    ~query
    ~input:Data_encoding.bytes
    ~output:Data_encoding.(obj1 (req "deterministic_nonce" bytes))
    Mavryk_rpc.Path.(
      root / "keys" /: Mavryk_crypto.Signature.Public_key_hash.rpc_arg)

let deterministic_nonce_hash =
  Mavryk_rpc.Service.post_service
    ~description:
      "Obtain the hash of some random data generated deterministically from \
       some piece of data with a given remote key"
    ~query
    ~input:Data_encoding.bytes
    ~output:Data_encoding.(obj1 (req "deterministic_nonce_hash" bytes))
    Mavryk_rpc.Path.(
      root / "keys" /: Mavryk_crypto.Signature.Public_key_hash.rpc_arg)

let supports_deterministic_nonces =
  Mavryk_rpc.Service.get_service
    ~description:
      "Obtain whether the signing service supports the deterministic nonces \
       functionality"
    ~query:Mavryk_rpc.Query.empty
    ~output:Data_encoding.(obj1 (req "supports_deterministic_nonces" bool))
    Mavryk_rpc.Path.(
      root / "keys" /: Mavryk_crypto.Signature.Public_key_hash.rpc_arg)

let public_key =
  Mavryk_rpc.Service.get_service
    ~description:"Retrieve the public key of a given remote key"
    ~query:Mavryk_rpc.Query.empty
    ~output:
      Data_encoding.(
        obj1 (req "public_key" Mavryk_crypto.Signature.Public_key.encoding))
    Mavryk_rpc.Path.(
      root / "keys" /: Mavryk_crypto.Signature.Public_key_hash.rpc_arg)

let authorized_keys =
  Mavryk_rpc.Service.get_service
    ~description:
      "Retrieve the public keys that can be used to authenticate signing \
       commands.\n\
       If the empty object is returned, the signer has been set to accept \
       unsigned commands."
    ~query:Mavryk_rpc.Query.empty
    ~output:
      Data_encoding.(
        obj1
          (opt
             "authorized_keys"
             (list Mavryk_crypto.Signature.Public_key_hash.encoding)))
    Mavryk_rpc.Path.(root / "authorized_keys")
