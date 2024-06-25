// SPDX-FileCopyrightText: 2023 Nomadic Labs <contact@nomadic-labs.com>
//
// SPDX-License-Identifier: MIT

use crate::blueprint::Blueprint;
use crate::configuration::{Configuration, ConfigurationMode};
use crate::error::{Error, StorageError};
use crate::inbox::{Transaction, TransactionContent};
use crate::sequencer_blueprint::{BlueprintWithDelayedHashes, SequencerBlueprint};
use crate::storage::{
    self, read_current_block_number, read_rlp, store_read_slice, store_rlp,
};
use crate::{delayed_inbox, DelayedInbox};
use primitive_types::{H256, U256};
use rlp::{Decodable, DecoderError, Encodable};
use sha3::{Digest, Keccak256};
use tezos_ethereum::rlp_helpers;
use tezos_ethereum::tx_common::EthereumTransactionCommon;
use tezos_evm_logging::{log, Level::*};
use tezos_smart_rollup_core::MAX_INPUT_MESSAGE_SIZE;
use tezos_smart_rollup_host::path::*;
use tezos_smart_rollup_host::runtime::{Runtime, RuntimeError};

pub const EVM_BLUEPRINTS: RefPath = RefPath::assert_from(b"/evm/blueprints");

const EVM_BLUEPRINT_NB_CHUNKS: RefPath = RefPath::assert_from(b"/nb_chunks");

/// The store representation of a blueprint.
/// It's designed to support storing sequencer blueprints,
/// which can be chunked, and blueprints constructed from
/// inbox messages. Note that the latter are only to be
/// used when the kernel isn't running with a sequencer.
#[derive(PartialEq, Debug, Clone)]
enum StoreBlueprint {
    SequencerChunk(Vec<u8>),
    InboxBlueprint(Blueprint),
}

const SEQUENCER_CHUNK_TAG: u8 = 0;
const INBOX_BLUEPRINT_TAG: u8 = 1;

impl Encodable for StoreBlueprint {
    fn rlp_append(&self, stream: &mut rlp::RlpStream) {
        stream.begin_list(2);
        match &self {
            StoreBlueprint::SequencerChunk(chunk) => {
                stream.append(&SEQUENCER_CHUNK_TAG);
                stream.append(chunk);
            }
            StoreBlueprint::InboxBlueprint(blueprint) => {
                stream.append(&INBOX_BLUEPRINT_TAG);
                stream.append(blueprint);
            }
        }
    }
}

impl Decodable for StoreBlueprint {
    fn decode(decoder: &rlp::Rlp) -> Result<Self, DecoderError> {
        if !decoder.is_list() {
            return Err(DecoderError::RlpExpectedToBeList);
        }
        if decoder.item_count()? != 2 {
            return Err(DecoderError::RlpIncorrectListLen);
        }
        let tag: u8 = decoder.at(0)?.as_val()?;
        let rest = decoder.at(1)?;
        match tag {
            SEQUENCER_CHUNK_TAG => {
                let chunk: Vec<u8> = rest.as_val()?;
                Ok(Self::SequencerChunk(chunk))
            }
            INBOX_BLUEPRINT_TAG => {
                let blueprint = rlp_helpers::decode_field(&rest, "blueprint")?;
                Ok(Self::InboxBlueprint(blueprint))
            }
            _ => Err(DecoderError::Custom("Unknown store blueprint tag.")),
        }
    }
}

pub fn blueprint_path(number: U256) -> Result<OwnedPath, StorageError> {
    let number_as_path: Vec<u8> = format!("/{}", number).into();
    // The key being an integer value, it will always be valid as a path,
    // `assert_from` cannot fail.
    let number_subkey = RefPath::assert_from(&number_as_path);
    concat(&EVM_BLUEPRINTS, &number_subkey).map_err(StorageError::from)
}

fn blueprint_chunk_path(
    blueprint_path: &OwnedPath,
    chunk_index: u16,
) -> Result<OwnedPath, StorageError> {
    let chunk_index_as_path: Vec<u8> = format!("/{}", chunk_index).into();
    let chunk_index_subkey = RefPath::assert_from(&chunk_index_as_path);
    concat(blueprint_path, &chunk_index_subkey).map_err(StorageError::from)
}

fn blueprint_nb_chunks_path(
    blueprint_path: &OwnedPath,
) -> Result<OwnedPath, StorageError> {
    concat(blueprint_path, &EVM_BLUEPRINT_NB_CHUNKS).map_err(StorageError::from)
}

fn read_blueprint_nb_chunks<Host: Runtime>(
    host: &Host,
    blueprint_path: &OwnedPath,
) -> Result<u16, Error> {
    let path = blueprint_nb_chunks_path(blueprint_path)?;
    let mut buffer = [0u8; 2];
    store_read_slice(host, &path, &mut buffer, 2)?;
    Ok(u16::from_le_bytes(buffer))
}

fn store_blueprint_nb_chunks<Host: Runtime>(
    host: &mut Host,
    blueprint_path: &OwnedPath,
    nb_chunks: u16,
) -> Result<(), Error> {
    let path = blueprint_nb_chunks_path(blueprint_path)?;
    let bytes = nb_chunks.to_le_bytes();
    host.store_write_all(&path, &bytes).map_err(Error::from)
}

pub fn store_sequencer_blueprint<Host: Runtime>(
    host: &mut Host,
    blueprint: SequencerBlueprint,
) -> Result<(), Error> {
    let blueprint_path = blueprint_path(blueprint.blueprint.number)?;
    store_blueprint_nb_chunks(host, &blueprint_path, blueprint.blueprint.nb_chunks)?;
    let blueprint_chunk_path =
        blueprint_chunk_path(&blueprint_path, blueprint.blueprint.chunk_index)?;
    let store_blueprint = StoreBlueprint::SequencerChunk(blueprint.blueprint.chunk);
    store_rlp(&store_blueprint, host, &blueprint_chunk_path)
}

pub fn store_inbox_blueprint_by_number<Host: Runtime>(
    host: &mut Host,
    blueprint: Blueprint,
    number: U256,
) -> Result<(), Error> {
    let blueprint_path = blueprint_path(number)?;
    store_blueprint_nb_chunks(host, &blueprint_path, 1)?;
    let chunk_path = blueprint_chunk_path(&blueprint_path, 0)?;
    let store_blueprint = StoreBlueprint::InboxBlueprint(blueprint);
    store_rlp(&store_blueprint, host, &chunk_path)
}

pub fn store_inbox_blueprint<Host: Runtime>(
    host: &mut Host,
    blueprint: Blueprint,
) -> Result<(), Error> {
    let number = read_next_blueprint_number(host)?;
    store_inbox_blueprint_by_number(host, blueprint, number)
}

#[inline(always)]
pub fn read_next_blueprint_number<Host: Runtime>(host: &Host) -> Result<U256, Error> {
    match read_current_block_number(host) {
        Err(Error::Storage(StorageError::Runtime(RuntimeError::HostErr(
            tezos_smart_rollup_host::Error::StoreNotAValue,
        )))) => Ok(U256::zero()),
        Err(err) => Err(err),
        Ok(block_number) => Ok(block_number.saturating_add(U256::one())),
    }
}

// Used to store a blueprint made out of forced delayed transactions.
pub fn store_immediate_blueprint<Host: Runtime>(
    host: &mut Host,
    blueprint: Blueprint,
    number: U256,
) -> Result<(), Error> {
    let blueprint_path = blueprint_path(number)?;
    store_blueprint_nb_chunks(host, &blueprint_path, 1)?;
    let chunk_path = blueprint_chunk_path(&blueprint_path, 0)?;
    let store_blueprint = StoreBlueprint::InboxBlueprint(blueprint);
    store_rlp(&store_blueprint, host, &chunk_path)
}

/// For the tick model we only accept blueprints where cumulative size of chunks
/// less or equal than 512kB. A chunk weights 4kB, then (512 * 1024) / 4096 =
/// 128.
pub const MAXIMUM_NUMBER_OF_CHUNKS: u16 = 128;

const MAXIMUM_SIZE_OF_BLUEPRINT: usize =
    MAXIMUM_NUMBER_OF_CHUNKS as usize * MAX_INPUT_MESSAGE_SIZE;

const MAXIMUM_SIZE_OF_DELAYED_TRANSACTION: usize = MAX_INPUT_MESSAGE_SIZE;

/// Possible errors when validating a blueprint
/// Only used for test, as all errors are handled in the same way
#[derive(Debug, PartialEq)]
pub enum BlueprintValidity {
    Valid(Blueprint),
    InvalidParentHash,
    DecoderError(DecoderError),
    DelayedHashMissing(delayed_inbox::Hash),
    BlueprintTooLarge,
}

/// Check that the parent hash of the [blueprint_with_hashes] is equal
/// to the current block hash
fn valid_parent_hash<Host: Runtime>(
    host: &Host,
    blueprint_with_hashes: &BlueprintWithDelayedHashes,
) -> bool {
    let genesis_parent = |_| {
        H256::from_slice(
            &hex::decode(
                "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
            )
            .unwrap(),
        )
    };
    let current_block_hash =
        storage::read_current_block_hash(host).unwrap_or_else(genesis_parent);
    current_block_hash == blueprint_with_hashes.parent_hash
}

fn fetch_delayed_txs<Host: Runtime>(
    host: &mut Host,
    blueprint_with_hashes: BlueprintWithDelayedHashes,
    delayed_inbox: &mut DelayedInbox,
    current_blueprint_size: usize,
) -> anyhow::Result<(BlueprintValidity, usize)> {
    let mut delayed_txs = vec![];
    let mut total_size = current_blueprint_size;
    for tx_hash in blueprint_with_hashes.delayed_hashes {
        let tx = delayed_inbox.find_and_remove_transaction(host, tx_hash)?;
        // This is overestimated, as the transactions cannot be chunked in the
        // delayed bridge.
        total_size += MAXIMUM_SIZE_OF_DELAYED_TRANSACTION;
        // If the size would overflow the 512KB, reject the blueprint
        if MAXIMUM_SIZE_OF_BLUEPRINT < total_size {
            return Ok((BlueprintValidity::BlueprintTooLarge, total_size));
        }
        match tx {
            Some(tx) => delayed_txs.push(tx.0),
            None => {
                return Ok((BlueprintValidity::DelayedHashMissing(tx_hash), total_size))
            }
        }
    }

    let transactions_with_hashes = blueprint_with_hashes
        .transactions
        .into_iter()
        .map(|tx_common| {
            let tx_hash = Keccak256::digest(&tx_common).into();
            let tx_common = EthereumTransactionCommon::from_bytes(&tx_common)?;

            Ok(Transaction {
                tx_hash,
                content: TransactionContent::Ethereum(tx_common),
            })
        })
        .collect::<anyhow::Result<Vec<Transaction>>>()?;

    delayed_txs.extend(transactions_with_hashes);
    Ok((
        BlueprintValidity::Valid(Blueprint {
            transactions: delayed_txs,
            timestamp: blueprint_with_hashes.timestamp,
        }),
        total_size,
    ))
}

fn parse_and_validate_blueprint<Host: Runtime>(
    host: &mut Host,
    bytes: &[u8],
    delayed_inbox: &mut DelayedInbox,
    current_blueprint_size: usize,
) -> anyhow::Result<(BlueprintValidity, usize)> {
    // Decode
    match rlp::decode(bytes) {
        Err(e) => Ok((BlueprintValidity::DecoderError(e), bytes.len())),
        Ok(blueprint_with_hashes) => {
            // Validate parent hash
            if !valid_parent_hash(host, &blueprint_with_hashes) {
                Ok((BlueprintValidity::InvalidParentHash, bytes.len()))
            } else {
                // Fetch delayed transactions
                fetch_delayed_txs(
                    host,
                    blueprint_with_hashes,
                    delayed_inbox,
                    current_blueprint_size,
                )
            }
        }
    }
}

fn invalidate_blueprint<Host: Runtime>(
    host: &mut Host,
    blueprint_path: &OwnedPath,
    error: &BlueprintValidity,
) -> Result<(), RuntimeError> {
    log!(
        host,
        Info,
        "Deleting invalid blueprint at path {}, error: {:?}",
        blueprint_path,
        error
    );
    // Remove invalid blueprint from storage
    host.store_delete(blueprint_path)
}

fn read_all_chunks_and_validate<Host: Runtime>(
    host: &mut Host,
    blueprint_path: &OwnedPath,
    nb_chunks: u16,
    config: &mut Configuration,
) -> anyhow::Result<(Option<Blueprint>, usize)> {
    let mut chunks = vec![];
    let mut size = 0;
    if nb_chunks > MAXIMUM_NUMBER_OF_CHUNKS {
        invalidate_blueprint(
            host,
            blueprint_path,
            &BlueprintValidity::BlueprintTooLarge,
        )?;
        return Ok((None, 0));
    };
    for i in 0..nb_chunks {
        let path = blueprint_chunk_path(blueprint_path, i)?;
        let stored_chunk = read_rlp(host, &path)?;
        // The tick model is based on the size of the chunk, we overapproximate it.
        size += MAX_INPUT_MESSAGE_SIZE;
        match stored_chunk {
            StoreBlueprint::InboxBlueprint(blueprint) => {
                // Special case when there's an inbox blueprint stored.
                // There must be only one chunk in this case.
                return Ok((Some(blueprint), size));
            }
            StoreBlueprint::SequencerChunk(chunk) => chunks.push(chunk),
        }
    }
    match &mut config.mode {
        ConfigurationMode::Proxy => Ok((None, size)),
        ConfigurationMode::Sequencer { delayed_inbox, .. } => {
            let validity = parse_and_validate_blueprint(
                host,
                chunks.concat().as_slice(),
                delayed_inbox,
                size,
            )?;
            if let (BlueprintValidity::Valid(blueprint), size_with_delayed_transactions) =
                validity
            {
                Ok((Some(blueprint), size_with_delayed_transactions))
            } else {
                invalidate_blueprint(host, blueprint_path, &validity.0)?;
                Ok((None, size))
            }
        }
    }
}

pub fn read_next_blueprint<Host: Runtime>(
    host: &mut Host,
    config: &mut Configuration,
) -> anyhow::Result<(Option<Blueprint>, usize)> {
    let number = read_next_blueprint_number(host)?;
    let blueprint_path = blueprint_path(number)?;
    let exists = host.store_has(&blueprint_path)?.is_some();
    if exists {
        let nb_chunks = read_blueprint_nb_chunks(host, &blueprint_path)?;
        let n_subkeys = host.store_count_subkeys(&blueprint_path)?;
        let available_chunks = n_subkeys as u16 - 1;
        if available_chunks == nb_chunks {
            // All chunks are available
            let (blueprint, size) =
                read_all_chunks_and_validate(host, &blueprint_path, nb_chunks, config)?;
            Ok((blueprint, size))
        } else {
            if available_chunks > nb_chunks {
                // We are in an inconsistent state (a previous blueprint was submitted with more
                // chunks).
                // As-is, the rollup is blocked. Easiest way to recover is to delete the whole
                // blueprint and let the sequencer re-submit it later.
                host.store_delete(&blueprint_path).map_err(Error::from)?;
            }

            Ok((None, 0))
        }
    } else {
        Ok((None, 0))
    }
}

pub fn drop_blueprint<Host: Runtime>(host: &mut Host, number: U256) -> Result<(), Error> {
    let path = blueprint_path(number)?;
    host.store_delete(&path).map_err(Error::from)
}

pub fn clear_all_blueprint<Host: Runtime>(host: &mut Host) -> Result<(), Error> {
    if host.store_has(&EVM_BLUEPRINTS)?.is_some() {
        Ok(host.store_delete(&EVM_BLUEPRINTS)?)
    } else {
        Ok(())
    }
}

#[cfg(test)]
mod tests {

    use super::*;
    use crate::configuration::TezosContracts;
    use crate::delayed_inbox::Hash;
    use crate::sequencer_blueprint::UnsignedSequencerBlueprint;
    use crate::Timestamp;
    use primitive_types::H256;
    use tezos_crypto_rs::hash::ContractKt1Hash;
    use tezos_crypto_rs::hash::Signature;
    use tezos_ethereum::transaction::TRANSACTION_HASH_SIZE;
    use tezos_smart_rollup_encoding::public_key::PublicKey;
    use tezos_smart_rollup_mock::MockHost;

    #[test]
    fn test_invalid_sequencer_blueprint_is_removed() {
        let mut host = MockHost::default();
        let delayed_inbox =
            DelayedInbox::new(&mut host).expect("Delayed inbox should be created");
        let delayed_bridge: ContractKt1Hash =
            ContractKt1Hash::from_base58_check("KT18amZmM5W7qDWVt2pH6uj7sCEd3kbzLrHT")
                .unwrap();
        let sequencer: PublicKey = PublicKey::from_b58check(
            "edpkuDMUm7Y53wp4gxeLBXuiAhXZrLn8XB1R83ksvvesH8Lp8bmCfK",
        )
        .unwrap();
        let mut config = Configuration {
            tezos_contracts: TezosContracts::default(),
            mode: ConfigurationMode::Sequencer {
                delayed_bridge,
                delayed_inbox: Box::new(delayed_inbox),
                sequencer,
            },
        };

        let dummy_tx_hash = Hash([0u8; TRANSACTION_HASH_SIZE]);
        let dummy_parent_hash = H256::from_slice(
            &hex::decode(
                "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
            )
            .unwrap(),
        );

        let blueprint_with_invalid_hash: BlueprintWithDelayedHashes =
            BlueprintWithDelayedHashes {
                delayed_hashes: vec![dummy_tx_hash],
                parent_hash: dummy_parent_hash,
                timestamp: Timestamp::from(42),
                transactions: vec![],
            };
        let blueprint_with_hashes_bytes =
            rlp::Encodable::rlp_bytes(&blueprint_with_invalid_hash);
        let signature = Signature::from_base58_check(
          "sigdGBG68q2vskMuac4AzyNb1xCJTfuU8MiMbQtmZLUCYydYrtTd5Lessn1EFLTDJzjXoYxRasZxXbx6tHnirbEJtikcMHt3"
      ).expect("signature decoding should work");

        let seq_blueprint = SequencerBlueprint {
            blueprint: UnsignedSequencerBlueprint {
                chunk: blueprint_with_hashes_bytes.clone().into(),
                number: U256::from(0),
                nb_chunks: 1u16,
                chunk_index: 0u16,
            },
            signature,
        };

        let mut delayed_inbox =
            DelayedInbox::new(&mut host).expect("Delayed inbox should be created");
        // Blueprint should have invalid parent hash
        let validity = parse_and_validate_blueprint(
            &mut host,
            blueprint_with_hashes_bytes.as_ref(),
            &mut delayed_inbox,
            0,
        )
        .expect("Should be able to parse blueprint");
        assert_eq!(
            validity.0,
            BlueprintValidity::DelayedHashMissing(dummy_tx_hash)
        );

        // Store blueprint
        store_sequencer_blueprint(&mut host, seq_blueprint)
            .expect("Should be able to store sequencer blueprint");

        // Blueprint 0 should be stored
        let blueprint_path = blueprint_path(U256::zero()).unwrap();
        let exists = host.store_has(&blueprint_path).unwrap().is_some();
        assert!(exists);

        // Reading the next blueprint should be None, as the delayed hash
        // isn't in the delayed inbox
        let blueprint = read_next_blueprint(&mut host, &mut config)
            .expect("Reading next blueprint should work");
        assert!(blueprint.0.is_none());

        // Next number should be 0, as we didn't read one
        let number = read_next_blueprint_number(&host)
            .expect("Should be able to read next blueprint number");
        assert!(number.is_zero());

        // The blueprint 0 should have been removed
        let exists = host.store_has(&blueprint_path).unwrap().is_some();
        assert!(!exists);

        // Test with invalid parent hash
        let blueprint_with_invalid_parent_hash: BlueprintWithDelayedHashes =
            BlueprintWithDelayedHashes {
                delayed_hashes: vec![],
                parent_hash: H256::zero(),
                timestamp: Timestamp::from(42),
                transactions: vec![],
            };
        let blueprint_with_hashes_bytes =
            rlp::Encodable::rlp_bytes(&blueprint_with_invalid_parent_hash);
        let signature = Signature::from_base58_check(
          "sigdGBG68q2vskMuac4AzyNb1xCJTfuU8MiMbQtmZLUCYydYrtTd5Lessn1EFLTDJzjXoYxRasZxXbx6tHnirbEJtikcMHt3"
      ).expect("signature decoding should work");

        let seq_blueprint = SequencerBlueprint {
            blueprint: UnsignedSequencerBlueprint {
                chunk: blueprint_with_hashes_bytes.clone().into(),
                number: U256::from(0),
                nb_chunks: 1u16,
                chunk_index: 0u16,
            },
            signature,
        };

        let mut delayed_inbox =
            DelayedInbox::new(&mut host).expect("Delayed inbox should be created");
        // Blueprint should have invalid parent hash
        let validity = parse_and_validate_blueprint(
            &mut host,
            blueprint_with_hashes_bytes.as_ref(),
            &mut delayed_inbox,
            0,
        )
        .expect("Should be able to parse blueprint");
        assert_eq!(validity.0, BlueprintValidity::InvalidParentHash);

        // Store blueprint
        store_sequencer_blueprint(&mut host, seq_blueprint)
            .expect("Should be able to store sequencer blueprint");
        // Blueprint 0 should be stored
        let exists = host.store_has(&blueprint_path).unwrap().is_some();
        assert!(exists);

        // Reading the next blueprint should be None, as the parent hash
        // is invalid
        let blueprint = read_next_blueprint(&mut host, &mut config)
            .expect("Reading next blueprint should work");
        assert!(blueprint.0.is_none());

        // The blueprint 0 should have been removed
        let exists = host.store_has(&blueprint_path).unwrap().is_some();
        assert!(!exists)
    }
}
