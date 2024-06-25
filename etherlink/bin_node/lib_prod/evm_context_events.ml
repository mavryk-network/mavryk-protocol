(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2024 Nomadic Labs <contact@nomadic-labs.com>                *)
(*                                                                           *)
(*****************************************************************************)

include Internal_event.Simple

let section = Events.section @ ["evm_context"]

let ready =
  declare_0
    ~section
    ~name:"evm_context_is_ready"
    ~msg:"EVM Context worker is ready"
    ~level:Info
    ()

let shutdown =
  declare_0
    ~section
    ~name:"evm_context_shutdown"
    ~msg:"EVM Context worker is shutting down"
    ~level:Info
    ()

let ready () = emit ready ()

let shutdown () = emit shutdown ()
