(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2023 Nomadic Labs, <contact@nomadic-labs.com>               *)
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

module Map = Map.Make (struct
  include Int32
end)

type t = Cryptobox.t Map.t

let add t level cryptobox = Map.add level cryptobox t

let find t level =
  let candidate =
    (* We search for the cryptobox from the most recent level to the least recent one. *)
    Map.bindings t |> List.rev
    |> List.iter_e (fun (candidate_level, cryptobox) ->
           (* We stop the search once we have found the first level below the candidate one. *)
           if candidate_level < level then Error cryptobox else Ok ())
  in
  match candidate with Error cryptobox -> Some cryptobox | Ok () -> None

let empty = Map.empty

let encoding =
  let open Data_encoding in
  conv_with_guard
    (fun map ->
      Map.to_seq map
      |> Seq.map (fun (level, cryptobox) ->
             (level, Cryptobox.parameters cryptobox))
      |> List.of_seq)
    (fun bindings ->
      (* We compute the cryptobox from the parameters and stop at the first error. *)
      bindings |> List.to_seq
      |> Seq.map (fun (level, parameters) ->
             Cryptobox.make parameters
             |> Result.map_error (fun (`Fail message) -> message)
             |> Result.map (fun cryptobox -> (level, cryptobox)))
      |> Seq.fold_left
           (fun result binding ->
             match result with
             | Error err -> Error err
             | Ok seq -> (
                 match binding with
                 | Ok (level, cryptobox) -> Ok (Seq.cons (level, cryptobox) seq)
                 | Error err -> Error err))
           (Ok Seq.empty)
      |> Result.map Map.of_seq)
    (list
       (obj2
          (req "level" int32)
          (req "parameters" Cryptobox.parameters_encoding)))
