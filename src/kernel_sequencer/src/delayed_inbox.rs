// SPDX-FileCopyrightText: 2023 Marigold <contact@marigold.dev>
//
// SPDX-License-Identifier: MIT

use crate::message::KernelMessage;
use tezos_smart_rollup_host::{
    input::Message,
    metadata::RollupMetadata,
    runtime::{Runtime, RuntimeError},
};

use crate::routing::FilterBehavior;

/// Return a message from the inbox
///
/// This function drives the delayed inbox:
///  - add messages to the delayed inbox
///  - process messages from the sequencer
///  - returns message as "normal" message to the user kernel
pub fn read_input<Host: Runtime>(
    host: &mut Host,
    filter_behavior: FilterBehavior,
) -> Result<Option<Message>, RuntimeError> {
    let RollupMetadata {
        raw_rollup_address, ..
    } = host.reveal_metadata()?;
    loop {
        let msg = host.read_input()?;
        match msg {
            None => return Ok(None), // No more messages to be processed
            Some(msg) => {
                let payload = msg.as_ref();
                if filter_behavior.predicate(payload, &raw_rollup_address) {
                    let msg = KernelMessage::try_from(msg);
                    match msg {
                        Ok(KernelMessage::Msg(message)) => return Ok(Some(message)),
                        Err(_) => {
                            // If it's an error, then the message is ignored
                        }
                    }
                }
            }
        }
    }
}
