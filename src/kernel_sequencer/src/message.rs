// SPDX-FileCopyrightText: 2023 Marigold <contact@marigold.dev>
//
// SPDX-License-Identifier: MIT

use tezos_smart_rollup_host::input::Message;

/// Different messages that can be received from the sequencer kernel
pub enum KernelMessage {
    Msg(Message), // tag: 0x00
}

impl TryFrom<Message> for KernelMessage {
    type Error = &'static str;

    fn try_from(value: Message) -> Result<Self, Self::Error> {
        let bytes = value.as_ref();
        let (tag, remaining) = bytes.split_first().ok_or("Not a valid message")?;
        let is_internal = tag == &0x00;
        if is_internal {
            return Ok(KernelMessage::Msg(value));
        }
        let (tag, remaining) = remaining.split_first().ok_or("Unknown message")?;
        match tag {
            0x00 => {
                // Message matched
                let mut payload = [0x01].to_vec();
                payload.append(&mut remaining.to_vec());

                let msg = Message::new(value.level, value.id, payload.to_vec());
                Ok(KernelMessage::Msg(msg))
            }
            _ => Err("unknown message"),
        }
    }
}

#[cfg(test)]
mod tests {
    use tezos_smart_rollup_host::input::Message;

    use crate::message::KernelMessage;

    #[test]
    fn test_normal_message_deserialization() {
        let msg = [0x01, 0x00, 0x03, 0x04].to_vec();
        let msg = Message::new(0, 0, msg);
        let msg = KernelMessage::try_from(msg).unwrap();
        assert!(matches!(msg, KernelMessage::Msg(_)));
    }

    #[test]
    fn test_unknown_encoding_deserialization() {
        let msg = [0x01, 0x044, 0x03, 0x04].to_vec();
        let msg = Message::new(0, 0, msg);
        let msg = KernelMessage::try_from(msg);
        assert!(matches!(msg, Err(_)));
    }

    #[test]
    fn test_internal_message_deserialization() {
        let msg = [0x00, 0x044, 0x03, 0x04].to_vec();
        let msg = Message::new(0, 0, msg);
        let msg = KernelMessage::try_from(msg).unwrap();
        assert!(matches!(msg, KernelMessage::Msg(_)));
    }

    #[test]
    fn test_external_message_good_payload() {
        let msg = [0x01, 0x00, 0x03, 0x04].to_vec();
        let msg = Message::new(0, 0, msg);
        let msg = KernelMessage::try_from(msg).unwrap();
        let KernelMessage::Msg(msg) = msg;
        let payload = msg.as_ref();
        assert!(payload == [0x01, 0x03, 0x04]);
    }
}
