(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2022 Nomadic Labs <contact@nomadic-labs.com>                *)
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

let collect_storage = true

let collect_lambdas = true

let collect_gas = true

let measure_code_size = true

let print_contracts = true

let fatal = true

let _mainnet_genesis =
  Genesis.
    {
      time = Time.Protocol.of_notation_exn "2025-08-14T11:18:23Z";
      block =
        Block_hash.of_b58check_exn
          "BLockGenesisGenesisGenesisGenesisGenesis23a82evMK9F";
      protocol =
        Protocol_hash.of_b58check_exn
          "Ps9mPmXaRzmzk35gbAYNCAw6UXdE2qoABTHbN2oEEc1qM7CwT9P";
    }

let basenet_genesis =
  Genesis.
    {
      time = Time.Protocol.of_notation_exn "2025-08-14T11:46:32Z";
      block =
        Block_hash.of_b58check_exn
          "BLockGenesisGenesisGenesisGenesisGenesis8a5a3c7Wpaw";
      protocol =
        Protocol_hash.of_b58check_exn
          "Ps9mPmXaRzmzk35gbAYNCAw6UXdE2qoABTHbN2oEEc1qM7CwT9P";
    }

let known_networks =
  [
    (* ("mainnet", mainnet_genesis); *)
    (* ("jakartanet", jakartanet_genesis); *)
    ("basenet", basenet_genesis);
  ]
