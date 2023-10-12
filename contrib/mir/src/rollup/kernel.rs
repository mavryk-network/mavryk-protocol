/******************************************************************************/
/*                                                                            */
/* SPDX-License-Identifier: MIT                                               */
/* Copyright (c) [2023] Serokell <hi@serokell.io>                             */
/*                                                                            */
/******************************************************************************/

use tezos_smart_rollup::{
    inbox::{InboxMessage, InternalInboxMessage},
    prelude::{debug_msg, Runtime},
    storage::path::RefPath,
    types::Message,
};

use crate::rollup::demo::{process_external_message, process_internal_message};

use super::types::*;

// This module follows the reference examples: https://gitlab.com/tezos/kernel-gallery

pub type Error = String;

/// The root method of the kernel.
///
/// Executed every level. Can be asked from inside to be run again at the same
/// level to handle some of the messages in the inbox, mind the limits on
/// execution time of one such call.
pub fn kernel_entry(host: &mut impl Runtime) {
    // Ways of observing that kernel has indeed been invoked, helps in testing
    let _ = host.store_write(&RefPath::assert_from(b"/started"), &[1], 0);

    // Handle all the messages we got at this level
    loop {
        match host.read_input() {
            Ok(Some(msg)) => {
                // TODO [#6411]: wrap into catch_unwind
                let res = process_message(host, &msg);
                res.unwrap_or_else(|err| {
                    debug_msg!(host, "Processing message #{} failed: {}\n", msg.id, err)
                })
            }
            // The kernel gallery and some experienced devs advise to keep
            // reading, errors in messages reading are really unlikely here.
            Err(_) => continue,
            Ok(None) => break,
        }
    }
}

pub fn process_message(host: &mut impl Runtime, msg: &Message) -> Result<(), Error> {
    let msg_id = msg.id;
    let level = msg.level;
    let (rest, msg) =
        InboxMessage::<IncomingTransferParam>::parse(msg.as_ref()).map_err(|x| x.to_string())?;
    // Likely we don't want to restrict the unparsed input for the sake of
    // forward compatibility. And the reference kernels do the same thing.
    debug_assert!(rest.is_empty());
    match msg {
        InboxMessage::External(payload) => {
            debug_msg!(
                host,
                "Message #{msg_id} at level #{level}: external {payload:x?}\n"
            );
            process_external_message(host, &payload)?
        }
        // [optimization] If payload is bytes, it should not be hard
        // to avoid copying payload when parsing if we use our own structures.
        // If it is not necessarily bytes, Nom lib still supports returning borrowed
        // data and for concrete small type we won't need to write much of a
        // decoding logic.
        InboxMessage::Internal(in_msg) => match in_msg {
            InternalInboxMessage::Transfer(transfer) => {
                debug_msg!(
                    host,
                    "Message #{msg_id} at level #{level}: internal transfer to {} with payload: {:x?}\n",
                    transfer.destination,
                    &transfer.payload.0
                );
                process_internal_message(host, &transfer)?
            }
            InternalInboxMessage::StartOfLevel => {}
            InternalInboxMessage::InfoPerLevel(_) => {}
            InternalInboxMessage::EndOfLevel => {}
        },
    }
    Ok(())
}
