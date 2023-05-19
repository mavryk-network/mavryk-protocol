// SPDX-FileCopyrightText: 2023 Marigold <contact@marigold.dev>
//
// SPDX-License-Identifier: MIT

use nom::{bytes::complete::tag, sequence::preceded};
use tezos_data_encoding::{
    enc::{self, BinResult, BinWriter},
    nom::{NomReader, NomResult},
};
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
