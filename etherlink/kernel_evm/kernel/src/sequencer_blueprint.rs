// SPDX-FileCopyrightText: 2023 Nomadic Labs <contact@nomadic-labs.com>
//
// SPDX-License-Identifier: MIT

use primitive_types::{H256, U256};
use rlp::{Decodable, DecoderError, Encodable};
use mavryk_crypto_rs::hash::Signature;
use mavryk_ethereum::rlp_helpers::{
    self, append_timestamp, append_u16_le, append_u256_le, decode_field_u16_le,
    decode_field_u256_le, decode_timestamp,
};
use mavryk_smart_rollup::types::Timestamp;

use crate::delayed_inbox::Hash;

#[derive(Debug, Clone)]
pub struct BlueprintWithDelayedHashes {
    pub parent_hash: H256,
    pub delayed_hashes: Vec<Hash>,
    // We are using `Vec<u8>` for the transaction instead of `EthereumTransactionCommon`
    // to avoid decoding then re-encoding to compute the hash.
    pub transactions: Vec<Vec<u8>>,
    pub timestamp: Timestamp,
}

impl Encodable for BlueprintWithDelayedHashes {
    fn rlp_append(&self, stream: &mut rlp::RlpStream) {
        let BlueprintWithDelayedHashes {
            parent_hash,
            delayed_hashes,
            transactions,
            timestamp,
        } = self;
        stream.begin_list(4);
        rlp_helpers::append_h256(stream, *parent_hash);
        stream.append_list(delayed_hashes);
        stream.append_list::<Vec<u8>, _>(transactions);
        append_timestamp(stream, *timestamp);
    }
}

impl Decodable for BlueprintWithDelayedHashes {
    fn decode(decoder: &rlp::Rlp) -> Result<Self, DecoderError> {
        if !decoder.is_list() {
            return Err(DecoderError::RlpExpectedToBeList);
        }
        if decoder.item_count()? != 4 {
            return Err(DecoderError::RlpIncorrectListLen);
        }

        let mut it = decoder.iter();
        let parent_hash =
            rlp_helpers::decode_field_h256(&rlp_helpers::next(&mut it)?, "parent_hash")?;
        let delayed_hashes =
            rlp_helpers::decode_list(&rlp_helpers::next(&mut it)?, "delayed_hashes")?;
        let transactions =
            rlp_helpers::decode_list(&rlp_helpers::next(&mut it)?, "transactions")?;
        let timestamp = decode_timestamp(&rlp_helpers::next(&mut it)?)?;

        Ok(Self {
            delayed_hashes,
            parent_hash,
            transactions,
            timestamp,
        })
    }
}

#[derive(PartialEq, Debug, Clone)]
pub struct UnsignedSequencerBlueprint {
    pub chunk: Vec<u8>,
    pub number: U256,
    pub nb_chunks: u16,
    pub chunk_index: u16,
}

#[derive(PartialEq, Debug, Clone)]
pub struct SequencerBlueprint {
    pub timestamp: Timestamp,
    pub transactions: Vec<u8>,
}

impl Encodable for SequencerBlueprint {
    fn rlp_append(&self, stream: &mut rlp::RlpStream) {
        stream.begin_list(2);
        stream.append_list(&self.transactions);
        append_timestamp(stream, self.timestamp);
    }
}

impl Decodable for SequencerBlueprint {
    fn decode(decoder: &rlp::Rlp) -> Result<Self, DecoderError> {
        if !decoder.is_list() {
            return Err(DecoderError::RlpExpectedToBeList);
        }
        if decoder.item_count()? != 2 {
            return Err(DecoderError::RlpIncorrectListLen);
        }
        let mut it = decoder.iter();
        let transactions =
            rlp_helpers::decode_list(&rlp_helpers::next(&mut it)?, "transactions")?;
        let timestamp = decode_timestamp(&rlp_helpers::next(&mut it)?)?;
        Ok(Self {
            blueprint,
            signature,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::{SequencerBlueprint, UnsignedSequencerBlueprint};
    use crate::blueprint::Blueprint;
    use crate::inbox::Transaction;
    use crate::inbox::TransactionContent::Ethereum;
    use primitive_types::{H160, U256};
    use rlp::Encodable;
    use mavryk_crypto_rs::hash::Signature;
    use mavryk_ethereum::rlp_helpers::FromRlpBytes;
    use mavryk_ethereum::{
        transaction::TRANSACTION_HASH_SIZE, tx_common::EthereumTransactionCommon,
    };
    use mavryk_smart_rollup_encoding::timestamp::Timestamp;

    fn sequencer_blueprint_roundtrip(v: SequencerBlueprint) {
        let bytes = v.rlp_bytes();
        let v2: SequencerBlueprint = FromRlpBytes::from_rlp_bytes(&bytes)
            .expect("Sequencer blueprint should be decodable");
        assert_eq!(v, v2, "Roundtrip failed on {:?}", v)
    }

    fn address_from_str(s: &str) -> Option<H160> {
        let data = &hex::decode(s).unwrap();
        Some(H160::from_slice(data))
    }

    fn tx_(i: u64) -> EthereumTransactionCommon {
        EthereumTransactionCommon::new(
            mavryk_ethereum::transaction::TransactionType::Legacy,
            Some(U256::one()),
            i,
            U256::from(40000000u64),
            U256::from(40000000u64),
            21000u64,
            address_from_str("423163e58aabec5daa3dd1130b759d24bef0f6ea"),
            U256::from(500000000u64),
            vec![],
            vec![],
            None,
        )
    }

    fn dummy_transaction(i: u8) -> Transaction {
        Transaction {
            tx_hash: [i; TRANSACTION_HASH_SIZE],
            content: Ethereum(tx_(i.into())),
        }
    }

    fn dummy_blueprint() -> SequencerBlueprint {
        let transactions = vec![dummy_transaction(0), dummy_transaction(1)];
        let timestamp = Timestamp::from(42);
        let blueprint = Blueprint {
            timestamp,
            transactions,
            timestamp,
        })
    }
}
