// SPDX-FileCopyrightText: 2023 Marigold <contact@marigold.dev>
//
// SPDX-License-Identifier: MIT

use serde::{Deserialize, Serialize};
use tezos_crypto_rs::{
    hash::{Signature, SmartRollupHash},
    PublicKeySignatureVerifier,
};
use tezos_smart_rollup_host::input::Message;

use crate::{crypto::PublicKey, delayed_inbox::MessageId};

/// Sequence message
///
/// It contains the delayed messages that has to be included from the delayed inbox
/// And the sent messages to the sequencer
#[derive(Debug, PartialEq, Deserialize, Serialize)]
pub struct Sequence {
    public_key: PublicKey,
    signature: Signature,
    payload: SequencePayload,
}

#[derive(Debug, PartialEq, Deserialize, Serialize)]
pub struct SequencePayload {
    rollup_addr: SmartRollupHash,
    delayed_messages: Vec<MessageId>,
    messages: Vec<Vec<u8>>,
}

#[derive(Debug, PartialEq, Deserialize, Serialize)]
pub struct SetSequencer {
    public_key: PublicKey,
    signature: Signature,
    payload: SetSequencerPayload,
}

#[derive(Debug, PartialEq, Deserialize, Serialize)]
struct SetSequencerPayload {
    rollup_addr: SmartRollupHash,
    /// The key of the new sequencer
    sequencer_public_key: PublicKey,
}

/// Different messages that can be received from the sequencer kernel
#[derive(Debug)]
pub enum KernelMessage {
    Msg(Message),               // tag: 0x00
    Sequence(Sequence),         // tag: 0x01
    SetSequencer(SetSequencer), // tag: 0x02
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
            0x01 => {
                let sequence = bincode::deserialize::<Sequence>(remaining)
                    .map_err(|_| "Cannot deserialize Sequence message")?;

                Ok(KernelMessage::Sequence(sequence))
            }
            0x02 => {
                let set_sequencer = bincode::deserialize::<SetSequencer>(remaining)
                    .map_err(|_| "Cannot deserialize Sequence message")?;

                Ok(KernelMessage::SetSequencer(set_sequencer))
            }
            _ => Err("unknown message"),
        }
    }
}

impl Sequence {
    /// Verify the signature of the sequence
    /// If the signature is correct then it returns the payload of the sequence
    pub fn verify_signature(self) -> Result<SequencePayload, &'static str> {
        // Compute the bytes that was signed
        let bytes = bincode::serialize(&self.payload)
            .map_err(|_| "signed payload deserialization error")?;

        // Verify the signature
        let is_correct = self
            .public_key
            .verify_signature(&self.signature, &bytes)
            .map_err(|_| "signature verification of Sequence failed")?;

        match is_correct {
            true => Ok(self.payload),
            false => Err("incorrect signature"),
        }
    }
}

#[cfg(test)]
mod tests {
    use std::assert_eq;

    use tezos_crypto_rs::hash::{SecretKeyEd25519, SeedEd25519, Signature, SmartRollupHash};
    use tezos_smart_rollup_host::input::Message;

    use crate::{crypto::PublicKey, message::KernelMessage};

    use super::{Sequence, SequencePayload, SetSequencer, SetSequencerPayload};

    /// Generate the secret and the public key of a given seed
    fn key_pair(seed: &str) -> (PublicKey, SecretKeyEd25519) {
        let (public_key, secret) = SeedEd25519::from_base58_check(seed)
            .unwrap()
            .keypair()
            .unwrap();

        let public_key = PublicKey::Ed25519(public_key);
        (public_key, secret)
    }

    /// Add a magic byte to the payload and the byte 0x01
    fn to_payload(magic_byte: u8, mut bytes: Vec<u8>) -> Vec<u8> {
        let mut payload = [0x01, magic_byte].to_vec();
        payload.append(&mut bytes);
        payload
    }

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
        if let KernelMessage::Msg(msg) = msg {
            let payload = msg.as_ref();
            assert!(payload == [0x01, 0x03, 0x04]);
        } else {
            assert!(false)
        }
    }

    #[test]
    fn test_sequence_serialization() {
        let rollup_addr =
            SmartRollupHash::from_base58_check("sr188sNVfv9EABYhwLxfKGLFvsXCJsyVzZ8M").unwrap();

        let (public_key, _) = key_pair("edsk3a5SDDdMWw3Q5hPiJwDXUosmZMTuKQkriPqY6UqtSfdLifpZbB");

        let delayed_messages = vec![];
        let messages = vec![];

        let payload = SequencePayload {
            rollup_addr: rollup_addr.clone(),
            delayed_messages: delayed_messages.clone(),
            messages,
        };
        let signature = Signature::from_base58_check("sigrJ2jqanLupARzKGvzWgL1Lv6NGUqDovHKQg9MX4PtNtHXgcvG6131MRVzujJEXfvgbuRtfdGbXTFaYJJjuUVLNNZTf5q1").unwrap();

        let sequence = Sequence {
            public_key,
            signature,
            payload,
        };

        let bytes = bincode::serialize(&sequence).unwrap();
        let payload = to_payload(0x01, bytes);

        let msg = Message::new(0, 0, payload);
        let sequence_read = KernelMessage::try_from(msg);

        match sequence_read {
            Ok(KernelMessage::Sequence(sequence_read)) => assert_eq!(sequence_read, sequence),
            _ => assert!(false),
        }
    }

    #[test]
    fn test_set_sequencer_serialization() {
        let rollup_addr =
            SmartRollupHash::from_base58_check("sr188sNVfv9EABYhwLxfKGLFvsXCJsyVzZ8M").unwrap();

        let (public_key, _) = key_pair("edsk3a5SDDdMWw3Q5hPiJwDXUosmZMTuKQkriPqY6UqtSfdLifpZbB");

        let payload = SetSequencerPayload {
            rollup_addr,
            sequencer_public_key: public_key.clone(),
        };
        let signature = Signature::from_base58_check("sigrJ2jqanLupARzKGvzWgL1Lv6NGUqDovHKQg9MX4PtNtHXgcvG6131MRVzujJEXfvgbuRtfdGbXTFaYJJjuUVLNNZTf5q1").unwrap();

        let set_sequencer = SetSequencer {
            public_key,
            signature,
            payload,
        };

        let bytes = bincode::serialize(&set_sequencer).unwrap();
        let payload = to_payload(0x02, bytes);

        let msg = Message::new(0, 0, payload);
        let sequence_read = KernelMessage::try_from(msg);

        match sequence_read {
            Ok(KernelMessage::SetSequencer(set_sequencer_read)) => {
                assert_eq!(set_sequencer_read, set_sequencer)
            }
            _ => assert!(false),
        }
    }

    #[test]
    fn test_sequence_correct_signature() {
        let rollup_addr =
            SmartRollupHash::from_base58_check("sr188sNVfv9EABYhwLxfKGLFvsXCJsyVzZ8M").unwrap();

        let (public_key, secret) =
            key_pair("edsk3a5SDDdMWw3Q5hPiJwDXUosmZMTuKQkriPqY6UqtSfdLifpZbB");

        let delayed_messages = vec![];
        let messages = vec![];

        let sequence_payload = SequencePayload {
            rollup_addr: rollup_addr.clone(),
            delayed_messages: delayed_messages.clone(),
            messages: messages.clone(),
        };
        let bytes = bincode::serialize(&sequence_payload).unwrap();
        let signature = secret.sign(&bytes).unwrap();

        let sequence = Sequence {
            public_key,
            signature,
            payload: sequence_payload,
        };
        let bytes = bincode::serialize(&sequence).unwrap();
        let payload = to_payload(0x01, bytes);

        // Deserialize the message
        let msg = Message::new(0, 0, payload);
        let kernel_message = KernelMessage::try_from(msg).unwrap();
        if let KernelMessage::Sequence(sequence) = kernel_message {
            assert!(sequence.verify_signature().is_ok())
        } else {
            assert!(false)
        }
    }

    #[test]
    fn test_sequence_not_correct_signature() {
        let rollup_addr =
            SmartRollupHash::from_base58_check("sr188sNVfv9EABYhwLxfKGLFvsXCJsyVzZ8M").unwrap();

        let (public_key, _) = key_pair("edsk3a5SDDdMWw3Q5hPiJwDXUosmZMTuKQkriPqY6UqtSfdLifpZbB");

        let delayed_messages = vec![];
        let messages = vec![];

        let sequence_payload = SequencePayload {
            rollup_addr: rollup_addr.clone(),
            delayed_messages: delayed_messages.clone(),
            messages: messages.clone(),
        };
        let signature = Signature::from_base58_check("sigrJ2jqanLupARzKGvzWgL1Lv6NGUqDovHKQg9MX4PtNtHXgcvG6131MRVzujJEXfvgbuRtfdGbXTFaYJJjuUVLNNZTf5q1").unwrap();

        let sequence = Sequence {
            public_key,
            signature,
            payload: sequence_payload,
        };
        let bytes = bincode::serialize(&sequence).unwrap();
        let payload = to_payload(0x01, bytes);

        // Deserialize the message
        let msg = Message::new(0, 0, payload);
        let kernel_message = KernelMessage::try_from(msg).unwrap();
        if let KernelMessage::Sequence(sequence) = kernel_message {
            assert!(sequence.verify_signature().is_err())
        } else {
            assert!(false)
        }
    }
}
