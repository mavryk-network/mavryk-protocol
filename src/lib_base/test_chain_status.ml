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

type t =
  | Not_running
  | Forking of {
      protocol : Mavryk_crypto.Hashed.Protocol_hash.t;
      expiration : Time.Protocol.t;
    }
  | Running of {
      chain_id : Mavryk_crypto.Hashed.Chain_id.t;
      genesis : Mavryk_crypto.Hashed.Block_hash.t;
      protocol : Mavryk_crypto.Hashed.Protocol_hash.t;
      expiration : Time.Protocol.t;
    }

let equal s1 s2 =
  match (s1, s2) with
  | Not_running, Not_running -> true
  | ( Forking {protocol = p1; expiration = e1},
      Forking {protocol = p2; expiration = e2} ) ->
      Mavryk_crypto.Hashed.Protocol_hash.equal p1 p2
      && Time.Protocol.equal e1 e2
  | ( Running {chain_id = c1; genesis = g1; protocol = p1; expiration = e1},
      Running {chain_id = c2; genesis = g2; protocol = p2; expiration = e2} ) ->
      Mavryk_crypto.Hashed.Chain_id.equal c1 c2
      && Mavryk_crypto.Hashed.Block_hash.equal g1 g2
      && Mavryk_crypto.Hashed.Protocol_hash.equal p1 p2
      && Time.Protocol.equal e1 e2
  | Not_running, (Forking _ | Running _)
  | (Forking _ | Running _), Not_running
  | Forking _, Running _
  | Running _, Forking _ ->
      false

let encoding =
  let open Data_encoding in
  def
    "test_chain_status"
    ~description:
      "The status of the test chain: not_running (there is no test chain at \
       the moment), forking (the test chain is being setup), running (the test \
       chain is running)."
  @@ union
       [
         case
           (Tag 0)
           ~title:"Not_running"
           (obj1 (req "status" (constant "not_running")))
           (function Not_running -> Some () | _ -> None)
           (fun () -> Not_running);
         case
           (Tag 1)
           ~title:"Forking"
           (obj3
              (req "status" (constant "forking"))
              (req "protocol" Mavryk_crypto.Hashed.Protocol_hash.encoding)
              (req "expiration" Time.Protocol.encoding))
           (function
             | Forking {protocol; expiration} -> Some ((), protocol, expiration)
             | _ -> None)
           (fun ((), protocol, expiration) -> Forking {protocol; expiration});
         case
           (Tag 2)
           ~title:"Running"
           (obj5
              (req "status" (constant "running"))
              (req "chain_id" Mavryk_crypto.Hashed.Chain_id.encoding)
              (req "genesis" Mavryk_crypto.Hashed.Block_hash.encoding)
              (req "protocol" Mavryk_crypto.Hashed.Protocol_hash.encoding)
              (req "expiration" Time.Protocol.encoding))
           (function
             | Running {chain_id; genesis; protocol; expiration} ->
                 Some ((), chain_id, genesis, protocol, expiration)
             | _ -> None)
           (fun ((), chain_id, genesis, protocol, expiration) ->
             Running {chain_id; genesis; protocol; expiration});
       ]

let pp ppf = function
  | Not_running -> Format.fprintf ppf "@[<v 2>Not running@]"
  | Forking {protocol; expiration} ->
      Format.fprintf
        ppf
        "@[<v 2>Forking %a (expires %a)@]"
        Mavryk_crypto.Hashed.Protocol_hash.pp
        protocol
        Time.System.pp_hum
        (Time.System.of_protocol_exn expiration)
  | Running {chain_id; genesis; protocol; expiration} ->
      Format.fprintf
        ppf
        "@[<v 2>Running %a@ Genesis: %a@ Net id: %a@ Expiration: %a@]"
        Mavryk_crypto.Hashed.Protocol_hash.pp
        protocol
        Mavryk_crypto.Hashed.Block_hash.pp
        genesis
        Mavryk_crypto.Hashed.Chain_id.pp
        chain_id
        Time.System.pp_hum
        (Time.System.of_protocol_exn expiration)

let () = Data_encoding.Registration.register ~pp encoding
