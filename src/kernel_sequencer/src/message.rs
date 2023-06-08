// SPDX-FileCopyrightText: 2023 Marigold <contact@marigold.dev>
//
// SPDX-License-Identifier: MIT

use nom::{
    branch::alt,
    bytes::complete::tag,
    combinator::{all_consuming, map},
    sequence::preceded,
};
use tezos_crypto_rs::hash::Signature;
use tezos_data_encoding::{
    enc::{self, BinResult, BinWriter},
    nom::{NomReader, NomResult},
};
use tezos_smart_rollup_encoding::public_key::PublicKey;
use tezos_smart_rollup_encoding::smart_rollup::SmartRollupAddress;

/// Trait that indicates what is the tag of the message in the Framing protocol
pub trait Tag {
    /// Returns the tag of the message
    fn tag() -> u8;
}

/// Framing protocol v0
///
/// The framing protocol starts with a 0, then the address of the rollup, then the message
/// The message should start by a tag, provided by the Tag trait
///
/// [0x00, smart rollup address, tag, message]
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Framed<P>
where
    P: NomReader + BinWriter + Tag,
{
    pub destination: SmartRollupAddress,
    pub payload: P,
}

/// Messages sent by the user to the sequencer
#[derive(NomReader, BinWriter, Clone, Debug, PartialEq, Eq)]
pub struct Bytes {
    #[encoding(dynamic, list)]
    inner: Vec<u8>,
}

/// Sequence of messages sent by the sequencer
///
/// The sequence contains the number of messages
/// that should be processed from the delayed inbox
/// and the messages from the sequencer
///  
/// The delayed messages will be processed first
/// And then the messages will be processed
#[derive(NomReader, BinWriter, Clone, Debug, PartialEq, Eq)]
pub struct Sequence {
    nonce: u32,
    delayed_messages: u32,
    #[encoding(dynamic, list)]
    messages: Vec<Bytes>,
    signature: Signature,
}

impl Tag for Sequence {
    fn tag() -> u8 {
        0 // Tag of the Sequence
    }
}

/// Message to set the appropriate sequencer
///
/// This message should be sent by the admin public key
/// This admin key should sign the new sequencer public key
#[derive(NomReader, BinWriter, Clone, Debug, PartialEq, Eq)]
pub struct SetSequencer {
    nonce: u32,
    admin_public_key: PublicKey,
    sequencer_public_key: PublicKey,
    signature: Signature,
}

impl Tag for SetSequencer {
    fn tag() -> u8 {
        1 // Tag of the SetSequencer
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum KernelMessage {
    Sequence(Framed<Sequence>),
    SetSequencer(Framed<SetSequencer>),
    Message(Vec<u8>),
}

impl<P> NomReader for Framed<P>
where
    P: NomReader + BinWriter + Tag,
{
    fn nom_read(input: &[u8]) -> NomResult<Self> {
        // Extract the rollup address from the framing protocolg
        let (input, destination) = preceded(tag([0]), SmartRollupAddress::nom_read)(input)?;

        // Check the tag of the message
        let (remaining, _) = tag([P::tag()])(input)?;

        // Extract the payload
        let (remaining, payload) = P::nom_read(remaining)?;

        Ok((
            remaining,
            Framed {
                destination,
                payload,
            },
        ))
    }
}

impl<P> BinWriter for Framed<P>
where
    P: NomReader + BinWriter + Tag,
{
    fn bin_write(&self, output: &mut Vec<u8>) -> BinResult {
        // bytes of the framing protocol
        enc::put_byte(&0x00, output);

        // bytes of the rollup address
        self.destination.bin_write(output)?;

        // add the byte of the payload
        enc::put_byte(&P::tag(), output);

        // bytes of the payload
        self.payload.bin_write(output)
    }
}

impl NomReader for KernelMessage {
    fn nom_read(input: &[u8]) -> NomResult<Self> {
        all_consuming(alt((
            all_consuming(map(
                preceded(tag([1]), Framed::<Sequence>::nom_read),
                KernelMessage::Sequence,
            )),
            all_consuming(map(
                preceded(tag([1]), Framed::<SetSequencer>::nom_read),
                KernelMessage::SetSequencer,
            )),
            map(
                |bytes: &[u8]| Ok(([].as_slice(), bytes.to_vec())),
                KernelMessage::Message,
            ),
        )))(input)
    }
}

impl BinWriter for KernelMessage {
    fn bin_write(&self, output: &mut Vec<u8>) -> enc::BinResult {
        match self {
            KernelMessage::Sequence(sequencer) => {
                // external message tag
                enc::put_byte(&0x01, output);
                sequencer.bin_write(output)?;
            }
            KernelMessage::SetSequencer(set_sequencer) => {
                // external message tag
                enc::put_byte(&0x01, output);
                set_sequencer.bin_write(output)?;
            }
            KernelMessage::Message(message) => enc::put_bytes(message, output),
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use crate::message::Framed;

    use super::{KernelMessage, Sequence};
    use crate::message::SetSequencer;
    use tezos_crypto_rs::hash::{SecretKeyEd25519, SeedEd25519};
    use tezos_data_encoding::enc::{self, BinWriter};
    use tezos_data_encoding::nom::NomReader;
    use tezos_smart_rollup_encoding::public_key::PublicKey;
    use tezos_smart_rollup_encoding::smart_rollup::SmartRollupAddress;

    /// Generate a public key and a secret key
    fn key_pair(seed: &str) -> (PublicKey, SecretKeyEd25519) {
        let (public_key, secret) = SeedEd25519::from_base58_check(seed)
            .expect("seed parsing should work")
            .keypair()
            .expect("make key pair should work");

        let public_key = PublicKey::Ed25519(public_key);
        (public_key, secret)
    }

    #[test]
    fn test_sequence_serialization() {
        let (_, secret) = key_pair("edsk3a5SDDdMWw3Q5hPiJwDXUosmZMTuKQkriPqY6UqtSfdLifpZbB");
        let signature = secret.sign([0x0]).expect("sign should work");

        let sequence = KernelMessage::Sequence(Framed {
            destination: SmartRollupAddress::from_b58check("sr1EzLeJYWrvch2Mhvrk1nUVYrnjGQ8A4qdb")
                .expect("decoding should work"),
            payload: Sequence {
                nonce: 0,
                delayed_messages: 0,
                messages: Vec::default(),
                signature,
            },
        });

        // Serializing
        let mut bin: Vec<u8> = Vec::new();
        sequence.bin_write(&mut bin).unwrap();

        // Deserializing
        let (_, msg_read) = KernelMessage::nom_read(&bin).expect("deserialization should work");

        assert_eq!(msg_read, sequence);
    }

    #[test]
    fn test_set_sequencer_serialization() {
        let (public_key, secret) =
            key_pair("edsk3a5SDDdMWw3Q5hPiJwDXUosmZMTuKQkriPqY6UqtSfdLifpZbB");
        let signature = secret.sign([0x0]).expect("sign should work");

        let sequence = KernelMessage::SetSequencer(Framed {
            destination: SmartRollupAddress::from_b58check("sr1EzLeJYWrvch2Mhvrk1nUVYrnjGQ8A4qdb")
                .expect("decoding should work"),
            payload: SetSequencer {
                nonce: 0,
                admin_public_key: public_key.clone(),
                sequencer_public_key: public_key,
                signature,
            },
        });

        // Serializing
        let mut bin: Vec<u8> = Vec::new();
        sequence.bin_write(&mut bin).unwrap();

        println!("{:?}", bin);

        // Deserializing
        let (_, msg_read) = KernelMessage::nom_read(&bin).expect("deserialization should work");

        assert_eq!(msg_read, sequence);
    }

    #[test]
    fn test_user_message_serialization() {
        let sequence = KernelMessage::Message(vec![0x01, 0x0, 0x01, 0x02, 0x02]);

        // Serializing
        let mut bin: Vec<u8> = Vec::new();
        sequence.bin_write(&mut bin).unwrap();

        // Deserializing
        let (_, msg_read) = KernelMessage::nom_read(&bin).expect("deserialization should work");

        assert_eq!(msg_read, sequence);
    }

    #[test]
    fn test_message_default() {
        let (_, secret) = key_pair("edsk3a5SDDdMWw3Q5hPiJwDXUosmZMTuKQkriPqY6UqtSfdLifpZbB");
        let signature = secret.sign([0x0]).expect("sign should work");

        let sequence = KernelMessage::Sequence(Framed {
            destination: SmartRollupAddress::from_b58check("sr1EzLeJYWrvch2Mhvrk1nUVYrnjGQ8A4qdb")
                .expect("decoding should work"),
            payload: Sequence {
                nonce: 0,
                signature,
                delayed_messages: 5,
                messages: Vec::default(),
            },
        });

        // Serializing
        let mut bin: Vec<u8> = Vec::new();
        sequence.bin_write(&mut bin).unwrap();
        enc::put_bytes(&[0x01, 0x02, 0x03, 0x04], &mut bin);

        println!("{:?}", bin);

        // Deserializing
        let (remaining, msg_read) =
            KernelMessage::nom_read(&bin).expect("deserialization should work");

        assert!(remaining.is_empty());
        assert_eq!(msg_read, KernelMessage::Message(bin))
    }
}
