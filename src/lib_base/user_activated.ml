(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2019 Nomadic Labs, <contact@nomadic-labs.com>               *)
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

type upgrades = (Int32.t * Mavryk_crypto.Hashed.Protocol_hash.t) list

let upgrades_encoding =
  let open Data_encoding in
  def
    "user_activated.upgrades"
    ~title:"User activated upgrades"
    ~description:
      "User activated upgrades: at given level, switch to given protocol."
    (list
       (obj2
          (req "level" int32)
          (req
             "replacement_protocol"
             Mavryk_crypto.Hashed.Protocol_hash.encoding)))

type protocol_overrides =
  (Mavryk_crypto.Hashed.Protocol_hash.t * Mavryk_crypto.Hashed.Protocol_hash.t)
  list

let protocol_overrides_encoding =
  let open Data_encoding in
  def
    "user_activated.protocol_overrides"
    ~title:"User activated protocol overrides"
    ~description:
      "User activated protocol overrides: activate a protocol instead of \
       another."
  @@ list
       (obj2
          (req "replaced_protocol" Mavryk_crypto.Hashed.Protocol_hash.encoding)
          (req
             "replacement_protocol"
             Mavryk_crypto.Hashed.Protocol_hash.encoding))

let () =
  Data_encoding.Registration.register upgrades_encoding ;
  Data_encoding.Registration.register protocol_overrides_encoding
