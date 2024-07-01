// SPDX-FileCopyrightText: 2022-2023 TriliTech <contact@trili.tech>
// SPDX-FileCopyrightText: 2023 Nomadic Labs <contact@nomadic-labs.com>
// SPDX-FileCopyrightText: 2023 Functori <contact@functori.com>
// SPDX-FileCopyrightText: 2023 Marigold <contact@marigold.dev>
//
// SPDX-License-Identifier: MIT

use crate::blueprint_storage::store_sequencer_blueprint;
use crate::configuration::MavrykContracts;
use crate::delayed_inbox::DelayedInbox;
use crate::parsing::{
    Input, InputResult, Parsable, ProxyInput, SequencerInput, SequencerParsingContext,
    MAX_SIZE_PER_CHUNK,
};

use crate::storage::{
    chunked_hash_transaction_path, chunked_transaction_num_chunks,
    chunked_transaction_path, clear_events, create_chunked_transaction,
    get_and_increment_deposit_nonce, read_l1_level, read_last_info_per_level_timestamp,
    remove_chunked_transaction, remove_sequencer, store_l1_level,
    store_last_info_per_level_timestamp, store_transaction_chunk,
};
use crate::tick_model::constants::{MAX_ALLOWED_TICKS, TICKS_FOR_BLUEPRINT_INTERCEPT};
use crate::tick_model::maximum_ticks_for_sequencer_chunk;
use crate::upgrade::*;
use crate::Error;
use crate::{simulation, upgrade};
use primitive_types::{H160, U256};
use rlp::{Decodable, DecoderError, Encodable};
use sha3::{Digest, Keccak256};
use tezos_crypto_rs::hash::ContractKt1Hash;
use mavryk_ethereum::rlp_helpers::{decode_field, decode_tx_hash, next};
use mavryk_ethereum::transaction::{
    TransactionHash, TransactionType, TRANSACTION_HASH_SIZE,
};
use mavryk_ethereum::tx_common::EthereumTransactionCommon;
use mavryk_evm_logging::{log, Level::*};
use mavryk_smart_rollup_encoding::public_key::PublicKey;
use mavryk_smart_rollup_host::runtime::Runtime;

#[derive(Debug, PartialEq, Clone)]
pub struct Deposit {
    pub amount: U256,
    pub receiver: H160,
}

impl Encodable for Deposit {
    fn rlp_append(&self, stream: &mut rlp::RlpStream) {
        stream.begin_list(2);
        stream.append(&self.amount);
        stream.append(&self.receiver);
    }
}

impl Decodable for Deposit {
    fn decode(decoder: &rlp::Rlp) -> Result<Self, DecoderError> {
        if !decoder.is_list() {
            return Err(DecoderError::RlpExpectedToBeList);
        }
        if decoder.item_count()? != 2 {
            return Err(DecoderError::RlpIncorrectListLen);
        }

        let mut it = decoder.iter();
        let amount: U256 = decode_field(&next(&mut it)?, "amount")?;
        let receiver: H160 = decode_field(&next(&mut it)?, "receiver")?;
        Ok(Deposit { amount, receiver })
    }
}

#[allow(clippy::large_enum_variant)]
#[derive(Debug, PartialEq, Clone)]
pub enum TransactionContent {
    Ethereum(EthereumTransactionCommon),
    Deposit(Deposit),
    EthereumDelayed(EthereumTransactionCommon),
}

const ETHEREUM_TX_TAG: u8 = 1;
const DEPOSIT_TX_TAG: u8 = 2;
const ETHEREUM_DELAYED_TX_TAG: u8 = 3;

impl Encodable for TransactionContent {
    fn rlp_append(&self, stream: &mut rlp::RlpStream) {
        stream.begin_list(2);
        match &self {
            TransactionContent::Ethereum(eth) => {
                stream.append(&ETHEREUM_TX_TAG);
                eth.rlp_append(stream)
            }
            TransactionContent::Deposit(dep) => {
                stream.append(&DEPOSIT_TX_TAG);
                dep.rlp_append(stream)
            }
            TransactionContent::EthereumDelayed(eth) => {
                stream.append(&ETHEREUM_DELAYED_TX_TAG);
                eth.rlp_append(stream)
            }
        }
    }
}

impl Decodable for TransactionContent {
    fn decode(decoder: &rlp::Rlp) -> Result<Self, DecoderError> {
        if !decoder.is_list() {
            return Err(DecoderError::RlpExpectedToBeList);
        }
        if decoder.item_count()? != 2 {
            return Err(DecoderError::RlpIncorrectListLen);
        }
        let tag: u8 = decoder.at(0)?.as_val()?;
        let tx = decoder.at(1)?;
        match tag {
            DEPOSIT_TX_TAG => {
                let deposit = Deposit::decode(&tx)?;
                Ok(Self::Deposit(deposit))
            }
            ETHEREUM_TX_TAG => {
                let eth = EthereumTransactionCommon::decode(&tx)?;
                Ok(Self::Ethereum(eth))
            }
            ETHEREUM_DELAYED_TX_TAG => {
                let eth = EthereumTransactionCommon::decode(&tx)?;
                Ok(Self::EthereumDelayed(eth))
            }
            _ => Err(DecoderError::Custom("Unknown transaction tag.")),
        }
    }
}

#[derive(Debug, PartialEq, Clone)]
pub struct Transaction {
    pub tx_hash: TransactionHash,
    pub content: TransactionContent,
}

impl Transaction {
    pub fn data_size(&self) -> u64 {
        match &self.content {
            TransactionContent::Deposit(_) => 0,
            TransactionContent::Ethereum(e) | TransactionContent::EthereumDelayed(e) => {
                e.data.len() as u64
            }
        }
    }

    pub fn is_delayed(&self) -> bool {
        match &self.content {
            TransactionContent::Deposit(_) | TransactionContent::EthereumDelayed(_) => {
                true
            }
            TransactionContent::Ethereum(_) => false,
        }
    }
}

impl Encodable for Transaction {
    fn rlp_append(&self, stream: &mut rlp::RlpStream) {
        stream.begin_list(2);
        stream.append_iter(self.tx_hash);
        stream.append(&self.content);
    }
}

impl Decodable for Transaction {
    fn decode(decoder: &rlp::Rlp) -> Result<Self, rlp::DecoderError> {
        if !decoder.is_list() {
            return Err(DecoderError::RlpExpectedToBeList);
        }
        if decoder.item_count()? != 2 {
            return Err(DecoderError::RlpIncorrectListLen);
        }
        let mut it = decoder.iter();
        let tx_hash: TransactionHash = decode_tx_hash(next(&mut it)?)?;
        let content: TransactionContent =
            decode_field(&next(&mut it)?, "Transaction content")?;
        Ok(Transaction { tx_hash, content })
    }
}

impl Transaction {
    pub fn type_(&self) -> TransactionType {
        match &self.content {
            // The deposit is considered arbitrarily as a legacy transaction
            TransactionContent::Deposit(_) => TransactionType::Legacy,
            TransactionContent::Ethereum(tx)
            | TransactionContent::EthereumDelayed(tx) => tx.type_,
        }
    }
}

#[derive(Debug, PartialEq)]
pub struct ProxyInboxContent {
    pub transactions: Vec<Transaction>,
}

pub fn read_input<Host: Runtime, Mode: Parsable>(
    host: &mut Host,
    smart_rollup_address: [u8; 20],
    mavryk_contracts: &MavrykContracts,
    inbox_is_empty: &mut bool,
    parsing_context: &mut Mode::Context,
) -> Result<InputResult<Mode>, Error> {
    let input = host.read_input()?;

    match input {
        Some(input) => {
            *inbox_is_empty = false;
            Ok(InputResult::parse(
                host,
                input,
                smart_rollup_address,
                mavryk_contracts,
                parsing_context,
            ))
        }
        None => Ok(InputResult::NoInput),
    }
}

/// The InputHandler abstracts how the input is handled once it has been parsed.
pub trait InputHandler {
    /// Abstracts the type used to store the inputs once handled
    type Inbox;

    fn handle_input<Host: Runtime>(
        host: &mut Host,
        input: Self,
        inbox_content: &mut Self::Inbox,
    ) -> anyhow::Result<()>;

    fn handle_deposit<Host: Runtime>(
        host: &mut Host,
        deposit: Deposit,
        inbox_content: &mut Self::Inbox,
    ) -> anyhow::Result<()>;
}

impl InputHandler for ProxyInput {
    // In case of the proxy, the Inbox is unchanged: we keep the InboxContent as
    // everything is doable in a single kernel_run.
    type Inbox = ProxyInboxContent;

    fn handle_input<Host: Runtime>(
        host: &mut Host,
        input: Self,
        inbox_content: &mut Self::Inbox,
    ) -> anyhow::Result<()> {
        match input {
            Self::SimpleTransaction(tx) => inbox_content.transactions.push(*tx),
            Self::NewChunkedTransaction {
                tx_hash,
                num_chunks,
                chunk_hashes,
            } => create_chunked_transaction(host, &tx_hash, num_chunks, chunk_hashes)?,
            Self::TransactionChunk {
                tx_hash,
                i,
                chunk_hash,
                data,
            } => {
                if let Some(tx) =
                    handle_transaction_chunk(host, tx_hash, i, chunk_hash, data)?
                {
                    inbox_content.transactions.push(tx)
                }
            }
        }
        Ok(())
    }

    fn handle_deposit<Host: Runtime>(
        host: &mut Host,
        deposit: Deposit,
        inbox_content: &mut Self::Inbox,
    ) -> anyhow::Result<()> {
        inbox_content
            .transactions
            .push(handle_deposit(host, deposit)?);
        Ok(())
    }
}

impl InputHandler for SequencerInput {
    // For the sequencer, inputs are stored directly in the storage. The delayed
    // inbox represents part of the storage, but `Unit` would also be enough as
    // there is nothing to return in the end.
    type Inbox = DelayedInbox;

    fn handle_input<Host: Runtime>(
        host: &mut Host,
        input: Self,
        delayed_inbox: &mut Self::Inbox,
    ) -> anyhow::Result<()> {
        match input {
            Self::DelayedInput(tx) => {
                let previous_timestamp = read_last_info_per_level_timestamp(host)?;
                let level = read_l1_level(host)?;
                delayed_inbox.save_transaction(host, *tx, previous_timestamp, level)?
            }
            Self::SequencerBlueprint(seq_blueprint) => {
                log!(
                    host,
                    Debug,
                    "Storing chunk {} of sequencer blueprint number {}",
                    seq_blueprint.blueprint.chunk_index,
                    seq_blueprint.blueprint.number
                );
                store_sequencer_blueprint(host, seq_blueprint)?
            }
        }
        Ok(())
    }

    fn handle_deposit<Host: Runtime>(
        host: &mut Host,
        deposit: Deposit,
        delayed_inbox: &mut Self::Inbox,
    ) -> anyhow::Result<()> {
        let previous_timestamp = read_last_info_per_level_timestamp(host)?;
        let level = read_l1_level(host)?;
        let tx = handle_deposit(host, deposit)?;
        delayed_inbox.save_transaction(host, tx, previous_timestamp, level)
    }
}

fn handle_transaction_chunk<Host: Runtime>(
    host: &mut Host,
    tx_hash: TransactionHash,
    i: u16,
    chunk_hash: TransactionHash,
    data: Vec<u8>,
) -> Result<Option<Transaction>, Error> {
    // If the number of chunks doesn't exist in the storage, the chunked
    // transaction wasn't created, so the chunk is ignored.
    let num_chunks = match chunked_transaction_num_chunks(host, &tx_hash) {
        Ok(x) => x,
        Err(_) => {
            log!(
                host,
                Info,
                "Ignoring chunk {} of unknown transaction {}",
                i,
                hex::encode(tx_hash)
            );
            return Ok(None);
        }
    };
    // Checks that the transaction is not out of bounds.
    if i >= num_chunks {
        return Ok(None);
    }
    // Check if the chunk hash is part of the announced chunked hashes.
    let chunked_transaction_path = chunked_transaction_path(&tx_hash)?;
    let chunk_hash_path =
        chunked_hash_transaction_path(&chunk_hash, &chunked_transaction_path)?;
    if host.store_read(&chunk_hash_path, 0, 0).is_err() {
        return Ok(None);
    }
    // Sanity check to verify that the transaction chunk uses the maximum
    // space capacity allowed.
    if i != num_chunks - 1 && data.len() < MAX_SIZE_PER_CHUNK {
        remove_chunked_transaction(host, &tx_hash)?;
        return Ok(None);
    };
    // When the transaction is stored in the storage, it returns the full transaction
    // if `data` was the missing chunk.
    if let Some(data) = store_transaction_chunk(host, &tx_hash, i, data)? {
        let full_data_hash: [u8; TRANSACTION_HASH_SIZE] = Keccak256::digest(&data).into();
        if full_data_hash == tx_hash {
            if let Ok(tx) = EthereumTransactionCommon::from_bytes(&data) {
                let content = TransactionContent::Ethereum(tx);
                return Ok(Some(Transaction { tx_hash, content }));
            }
        }
    }
    Ok(None)
}

fn handle_deposit<Host: Runtime>(
    host: &mut Host,
    deposit: Deposit,
) -> Result<Transaction, Error> {
    let deposit_nonce = get_and_increment_deposit_nonce(host)?;

    let mut buffer_amount = [0; 32];
    deposit.amount.to_little_endian(&mut buffer_amount);

    let mut to_hash = vec![];
    to_hash.extend_from_slice(&buffer_amount);
    to_hash.extend_from_slice(&deposit.receiver.to_fixed_bytes());
    to_hash.extend_from_slice(&deposit_nonce.to_le_bytes());

    let kec = Keccak256::digest(to_hash);
    let tx_hash = kec
        .as_slice()
        .try_into()
        .map_err(|_| Error::InvalidConversion)?;

    Ok(Transaction {
        tx_hash,
        content: TransactionContent::Deposit(deposit),
    })
}

fn force_kernel_upgrade(host: &mut impl Runtime) -> anyhow::Result<()> {
    match upgrade::read_kernel_upgrade(host)? {
        Some(kernel_upgrade) => {
            let current_timestamp = read_last_info_per_level_timestamp(host)?.i64();
            let activation_timestamp = kernel_upgrade.activation_timestamp.i64();

            if current_timestamp >= (activation_timestamp + 86400i64) {
                // If the kernel upgrade still exist 1 day after it was supposed
                // to be activated. It is possible to force its execution.
                upgrade::upgrade(host, kernel_upgrade.preimage_hash)?
            };
            Ok(())
        }
        None => Ok(()),
    }
}

pub fn handle_input<Mode: Parsable + InputHandler>(
    host: &mut impl Runtime,
    input: Input<Mode>,
    inbox_content: &mut Mode::Inbox,
) -> anyhow::Result<()> {
    match input {
        Input::ModeSpecific(input) => Mode::handle_input(host, input, inbox_content)?,
        Input::Upgrade(kernel_upgrade) => store_kernel_upgrade(host, &kernel_upgrade)?,
        Input::SequencerUpgrade(sequencer_upgrade) => {
            store_sequencer_upgrade(host, sequencer_upgrade)?
        }
        Input::RemoveSequencer => remove_sequencer(host)?,
        Input::Info(info) => {
            // New inbox level detected, remove all previous events.
            clear_events(host)?;
            store_last_info_per_level_timestamp(host, info.info.predecessor_timestamp)?;
            store_l1_level(host, info.level)?
        }
        Input::Deposit(deposit) => Mode::handle_deposit(host, deposit, inbox_content)?,
        Input::ForceKernelUpgrade => force_kernel_upgrade(host)?,
    }
    Ok(())
}

enum ReadStatus {
    FinishedIgnore,
    FinishedRead,
    Ongoing,
}

fn read_and_dispatch_input<Host: Runtime, Mode: Parsable + InputHandler>(
    host: &mut Host,
    smart_rollup_address: [u8; 20],
    mavryk_contracts: &MavrykContracts,
    parsing_context: &mut Mode::Context,
    inbox_is_empty: &mut bool,
    res: &mut Mode::Inbox,
) -> anyhow::Result<ReadStatus> {
    let input: InputResult<Mode> = read_input(
        host,
        smart_rollup_address,
        mavryk_contracts,
        inbox_is_empty,
        parsing_context,
    )?;
    match input {
        InputResult::NoInput => {
            if *inbox_is_empty {
                // If `inbox_is_empty` is true, that means we haven't see
                // any input in the current call of `read_inbox`. Therefore,
                // the inbox of this level has already been consumed.
                Ok(ReadStatus::FinishedIgnore)
            } else {
                // If it's a `NoInput` and `inbox_is_empty` is false, we
                // have simply reached the end of the inbox.
                Ok(ReadStatus::FinishedRead)
            }
        }
        InputResult::Unparsable => Ok(ReadStatus::Ongoing),
        InputResult::Simulation => {
            // kernel enters in simulation mode, reading will be done by the
            // simulation and all the previous and next transactions are
            // discarded.
            simulation::start_simulation_mode(host)?;
            Ok(ReadStatus::FinishedIgnore)
        }
        InputResult::Input(input) => {
            handle_input(host, input, res)?;
            Ok(ReadStatus::Ongoing)
        }
    }
}

pub fn read_proxy_inbox<Host: Runtime>(
    host: &mut Host,
    smart_rollup_address: [u8; 20],
    mavryk_contracts: &MavrykContracts,
) -> Result<Option<ProxyInboxContent>, anyhow::Error> {
    let mut res = ProxyInboxContent {
        transactions: vec![],
    };
    // The mutable variable is used to retrieve the information of whether the
    // inbox was empty or not. As we consume all the inbox in one go, if the
    // variable remains true, that means that the inbox was already consumed
    // during this kernel run.
    let mut inbox_is_empty = true;
    loop {
        match read_and_dispatch_input::<Host, ProxyInput>(
            host,
            smart_rollup_address,
            mavryk_contracts,
            &mut (),
            &mut inbox_is_empty,
            &mut res,
        ) {
            Err(err) =>
            // If we failed to read or dispatch the input.
            // We allow ourselves to continue with the inbox consumption.
            // In order to make sure we can retrieve any kernel upgrade
            // present in the inbox.
            {
                log!(
                    host,
                    Fatal,
                    "An input made `read_and_dispatch_input` fail, we ignore it ({:?})",
                    err
                )
            }
            Ok(ReadStatus::Ongoing) => (),
            Ok(ReadStatus::FinishedRead) => return Ok(Some(res)),
            Ok(ReadStatus::FinishedIgnore) => return Ok(None),
        }
    }
}

/// The StageOne can yield with three possible states:
///
/// - Done: the inbox has been fully read during the current `kernel_run`
///
/// - Reboot: the inbox cannot been read further as there are not enough ticks
///   and needs a reboot before continuing. This is only supported in sequencer
///   mode as the inputs are stored directly in the process.
///
/// - Skipped: the inbox was empty during the current `kernel_run`, implying it
///   has been emptied during a previous `kernel_run` and the kernel is
///   currently processing blueprints. It prevents the automatic reboot after
///   completing the stage one to start the block production, and producing an
///   empty blueprint in proxy mode.
pub enum StageOneStatus {
    Done,
    Reboot,
    Skipped,
}

pub fn read_sequencer_inbox<Host: Runtime>(
    host: &mut Host,
    smart_rollup_address: [u8; 20],
    mavryk_contracts: &MavrykContracts,
    delayed_bridge: ContractKt1Hash,
    sequencer: PublicKey,
    delayed_inbox: &mut DelayedInbox,
) -> Result<StageOneStatus, anyhow::Error> {
    // The mutable variable is used to retrieve the information of whether the
    // inbox was empty or not. As we consume all the inbox in one go, if the
    // variable remains true, that means that the inbox was already consumed
    // during this kernel run.
    let mut inbox_is_empty = true;
    let mut parsing_context = SequencerParsingContext {
        sequencer,
        delayed_bridge,
        allocated_ticks: MAX_ALLOWED_TICKS.saturating_sub(TICKS_FOR_BLUEPRINT_INTERCEPT),
    };
    loop {
        // Checks there will be enough ticks to handle at least another chunk of
        // full size. If it is not the case, asks for reboot.
        if parsing_context.allocated_ticks < maximum_ticks_for_sequencer_chunk() {
            return Ok(StageOneStatus::Reboot);
        };
        match read_and_dispatch_input::<Host, SequencerInput>(
            host,
            smart_rollup_address,
            mavryk_contracts,
            &mut parsing_context,
            &mut inbox_is_empty,
            delayed_inbox,
        ) {
            Err(err) =>
            // If we failed to read or dispatch the input.
            // We allow ourselves to continue with the inbox consumption.
            // In order to make sure we can retrieve any kernel upgrade
            // present in the inbox.
            {
                log!(
                    host,
                    Fatal,
                    "An input made `read_and_dispatch_input` fail, we ignore it ({:?})",
                    err
                )
            }
            Ok(ReadStatus::Ongoing) => (),
            Ok(ReadStatus::FinishedRead) => return Ok(StageOneStatus::Done),
            Ok(ReadStatus::FinishedIgnore) => return Ok(StageOneStatus::Skipped),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::configuration::MavrykContracts;
    use crate::inbox::TransactionContent::Ethereum;
    use crate::parsing::RollupType;
    use crate::storage::*;
    use tezos_crypto_rs::hash::SmartRollupHash;
    use tezos_data_encoding::types::Bytes;
    use mavryk_ethereum::transaction::TRANSACTION_HASH_SIZE;
    use mavryk_smart_rollup_core::PREIMAGE_HASH_SIZE;
    use mavryk_smart_rollup_encoding::contract::Contract;
    use mavryk_smart_rollup_encoding::inbox::ExternalMessageFrame;
    use mavryk_smart_rollup_encoding::michelson::{MichelsonBytes, MichelsonOr};
    use mavryk_smart_rollup_encoding::public_key_hash::PublicKeyHash;
    use mavryk_smart_rollup_encoding::smart_rollup::SmartRollupAddress;
    use mavryk_smart_rollup_encoding::timestamp::Timestamp;
    use mavryk_smart_rollup_mock::{MockHost, TransferMetadata};

    const SMART_ROLLUP_ADDRESS: [u8; 20] = [
        20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1,
    ];

    const ZERO_TX_HASH: TransactionHash = [0; TRANSACTION_HASH_SIZE];

    fn smart_rollup_address() -> SmartRollupAddress {
        SmartRollupAddress::new(SmartRollupHash(SMART_ROLLUP_ADDRESS.into()))
    }

    fn input_to_bytes(
        smart_rollup_address: [u8; 20],
        input: Input<ProxyInput>,
    ) -> Vec<u8> {
        let mut buffer = Vec::new();
        // Targetted framing protocol
        buffer.push(0);
        buffer.extend_from_slice(&smart_rollup_address);
        match input {
            Input::ModeSpecific(ProxyInput::SimpleTransaction(tx)) => {
                // Simple transaction tag
                buffer.push(0);
                buffer.extend_from_slice(&tx.tx_hash);
                let mut tx_bytes = match tx.content {
                    Ethereum(tx) => tx.into(),
                    _ => panic!(
                        "Simple transaction can contain only ethereum transactions"
                    ),
                };

                buffer.append(&mut tx_bytes)
            }
            Input::ModeSpecific(ProxyInput::NewChunkedTransaction {
                tx_hash,
                num_chunks,
                chunk_hashes,
            }) => {
                // New chunked transaction tag
                buffer.push(1);
                buffer.extend_from_slice(&tx_hash);
                buffer.extend_from_slice(&u16::to_le_bytes(num_chunks));
                for chunk_hash in chunk_hashes.iter() {
                    buffer.extend_from_slice(chunk_hash)
                }
            }
            Input::ModeSpecific(ProxyInput::TransactionChunk {
                tx_hash,
                i,
                chunk_hash,
                data,
            }) => {
                // Transaction chunk tag
                buffer.push(2);
                buffer.extend_from_slice(&tx_hash);
                buffer.extend_from_slice(&u16::to_le_bytes(i));
                buffer.extend_from_slice(&chunk_hash);
                buffer.extend_from_slice(&data);
            }
            _ => (),
        };
        buffer
    }

    fn make_chunked_transactions(
        tx_hash: TransactionHash,
        data: Vec<u8>,
    ) -> Vec<Input<ProxyInput>> {
        let mut chunk_hashes = vec![];
        let mut chunks: Vec<Input<ProxyInput>> = data
            .chunks(MAX_SIZE_PER_CHUNK)
            .enumerate()
            .map(|(i, bytes)| {
                let data = bytes.to_vec();
                let chunk_hash = Keccak256::digest(&data).try_into().unwrap();
                chunk_hashes.push(chunk_hash);
                Input::ModeSpecific(ProxyInput::TransactionChunk {
                    tx_hash,
                    i: i as u16,
                    chunk_hash,
                    data,
                })
            })
            .collect();
        let number_of_chunks = chunks.len() as u16;

        let new_chunked_transaction =
            Input::ModeSpecific(ProxyInput::NewChunkedTransaction {
                tx_hash,
                num_chunks: number_of_chunks,
                chunk_hashes,
            });

        let mut buffer = Vec::new();
        buffer.push(new_chunked_transaction);
        buffer.append(&mut chunks);
        buffer
    }

    fn large_transaction() -> (Vec<u8>, EthereumTransactionCommon) {
        let data: Vec<u8> = hex::decode(["f917e180843b9aca0082520894b53dc01974176e5dff2298c5a94343c2585e3c548a021dfe1f5c5363780000b91770".to_string(), "a".repeat(12_000), "820a96a07fd9567a72223bbc8f70bd2b42011339b61044d16b5a2233534db8ca01f3e57aa03ea489c4bb2b2b52f3c1a18966881114767654c9ab61d46b1fbff78a498043c2".to_string()].join("")).unwrap();
        let tx = EthereumTransactionCommon::from_bytes(&data).unwrap();
        (data, tx)
    }

    #[test]
    fn parse_valid_simple_transaction() {
        let mut host = MockHost::default();

        let tx_bytes = &hex::decode("f86d80843b9aca00825208940b52d4d3be5d18a7ab5e4476a2f5382bbf2b38d888016345785d8a000080820a95a0d9ef1298c18c88604e3f08e14907a17dfa81b1dc6b37948abe189d8db5cb8a43a06fc7040a71d71d3cb74bd05ead7046b10668ad255da60391c017eea31555f156").unwrap();
        let tx = EthereumTransactionCommon::from_bytes(tx_bytes).unwrap();
        let tx_hash = Keccak256::digest(tx_bytes).into();
        let input =
            Input::ModeSpecific(ProxyInput::SimpleTransaction(Box::new(Transaction {
                tx_hash,
                content: Ethereum(tx.clone()),
            })));

        host.add_external(Bytes::from(input_to_bytes(SMART_ROLLUP_ADDRESS, input)));

        let inbox_content =
            read_proxy_inbox(&mut host, SMART_ROLLUP_ADDRESS, &MavrykContracts::default())
                .unwrap()
                .unwrap();
        let expected_transactions = vec![Transaction {
            tx_hash,
            content: Ethereum(tx),
        }];
        assert_eq!(inbox_content.transactions, expected_transactions);
    }

    #[test]
    fn parse_valid_chunked_transaction() {
        let address = smart_rollup_address();
        let mut host = MockHost::with_address(&address);

        let (data, tx) = large_transaction();
        let tx_hash: [u8; TRANSACTION_HASH_SIZE] = Keccak256::digest(data.clone()).into();

        let inputs = make_chunked_transactions(tx_hash, data);

        for input in inputs {
            host.add_external(Bytes::from(input_to_bytes(SMART_ROLLUP_ADDRESS, input)))
        }

        let inbox_content =
            read_proxy_inbox(&mut host, SMART_ROLLUP_ADDRESS, &MavrykContracts::default())
                .unwrap()
                .unwrap();
        let expected_transactions = vec![Transaction {
            tx_hash,
            content: Ethereum(tx),
        }];
        assert_eq!(inbox_content.transactions, expected_transactions);
    }

    #[test]
    fn parse_valid_kernel_upgrade() {
        let mut host = MockHost::default();

        // Prepare the upgrade's payload
        let preimage_hash: [u8; PREIMAGE_HASH_SIZE] = hex::decode(
            "004b28109df802cb1885ab29461bc1b410057a9f3a848d122ac7a742351a3a1f4e",
        )
        .unwrap()
        .try_into()
        .unwrap();
        let activation_timestamp = Timestamp::from(0i64);

        let kernel_upgrade = KernelUpgrade {
            preimage_hash,
            activation_timestamp,
        };
        let kernel_upgrade_payload = kernel_upgrade.rlp_bytes().to_vec();

        // Create a transfer from the bridge contract, that act as the
        // dictator (or administrator).
        let source =
            PublicKeyHash::from_b58check("tz1NiaviJwtMbpEcNqSP6neeoBYj8Brb3QPv").unwrap();
        let contract =
            Contract::from_b58check("KT1HJphVV3LUxqZnc7YSH6Zdfd3up1DjLqZv").unwrap();
        let sender = match contract {
            Contract::Originated(kt1) => kt1,
            _ => panic!("The contract must be a KT1"),
        };
        let payload: RollupType =
            MichelsonOr::Right(MichelsonBytes(kernel_upgrade_payload));

        let transfer_metadata = TransferMetadata::new(sender.clone(), source);
        host.add_transfer(payload, &transfer_metadata);
        let _inbox_content = read_proxy_inbox(
            &mut host,
            [0; 20],
            &MavrykContracts {
                ticketer: None,
                admin: Some(sender),
                sequencer_governance: None,
                kernel_governance: None,
                kernel_security_governance: None,
            },
        )
        .unwrap()
        .unwrap();
        let expected_upgrade = Some(KernelUpgrade {
            preimage_hash,
            activation_timestamp,
        });

        let stored_kernel_upgrade = crate::upgrade::read_kernel_upgrade(&host).unwrap();
        assert_eq!(stored_kernel_upgrade, expected_upgrade);
    }

    #[test]
    // Assert that trying to create a chunked transaction has no impact. Only
    // the first `NewChunkedTransaction` should be considered.
    fn recreate_chunked_transaction() {
        let mut host = MockHost::default();

        let chunk_hashes = vec![[1; TRANSACTION_HASH_SIZE], [2; TRANSACTION_HASH_SIZE]];
        let tx_hash = [0; TRANSACTION_HASH_SIZE];
        let new_chunk1 = Input::ModeSpecific(ProxyInput::NewChunkedTransaction {
            tx_hash,
            num_chunks: 2,
            chunk_hashes: chunk_hashes.clone(),
        });
        let new_chunk2 = Input::ModeSpecific(ProxyInput::NewChunkedTransaction {
            tx_hash,
            num_chunks: 42,
            chunk_hashes,
        });

        host.add_external(Bytes::from(input_to_bytes(
            SMART_ROLLUP_ADDRESS,
            new_chunk1,
        )));
        host.add_external(Bytes::from(input_to_bytes(
            SMART_ROLLUP_ADDRESS,
            new_chunk2,
        )));

        let _inbox_content =
            read_proxy_inbox(&mut host, SMART_ROLLUP_ADDRESS, &MavrykContracts::default())
                .unwrap();

        let num_chunks = chunked_transaction_num_chunks(&mut host, &tx_hash)
            .expect("The number of chunks should exist");
        // Only the first `NewChunkedTransaction` should be considered.
        assert_eq!(num_chunks, 2);
    }

    #[test]
    // Assert that an out of bound chunk is simply ignored and does
    // not make the kernel fail.
    fn out_of_bound_chunk_is_ignored() {
        let mut host = MockHost::default();

        let (data, _tx) = large_transaction();
        let tx_hash = ZERO_TX_HASH;

        let mut inputs = make_chunked_transactions(tx_hash, data);
        let new_chunk = inputs.remove(0);
        let chunk = inputs.remove(0);

        // Announce a chunked transaction.
        host.add_external(Bytes::from(input_to_bytes(SMART_ROLLUP_ADDRESS, new_chunk)));

        // Give a chunk with an invalid `i`.
        let out_of_bound_i = 42;
        let chunk = match chunk {
            Input::ModeSpecific(ProxyInput::TransactionChunk {
                tx_hash,
                i: _,
                chunk_hash,
                data,
            }) => Input::ModeSpecific(ProxyInput::TransactionChunk {
                tx_hash,
                i: out_of_bound_i,
                chunk_hash,
                data,
            }),
            _ => panic!("Expected a transaction chunk"),
        };
        host.add_external(Bytes::from(input_to_bytes(SMART_ROLLUP_ADDRESS, chunk)));

        let _inbox_content =
            read_proxy_inbox(&mut host, SMART_ROLLUP_ADDRESS, &MavrykContracts::default())
                .unwrap();

        // The out of bounds chunk should not exist.
        let chunked_transaction_path = chunked_transaction_path(&tx_hash).unwrap();
        let transaction_chunk_path =
            transaction_chunk_path(&chunked_transaction_path, out_of_bound_i).unwrap();
        if read_transaction_chunk_data(&mut host, &transaction_chunk_path).is_ok() {
            panic!("The chunk should not exist in the storage")
        }
    }

    #[test]
    // Assert that an unknown chunk is simply ignored and does
    // not make the kernel fail.
    fn unknown_chunk_is_ignored() {
        let mut host = MockHost::default();

        let (data, _tx) = large_transaction();
        let tx_hash = ZERO_TX_HASH;

        let mut inputs = make_chunked_transactions(tx_hash, data);
        let chunk = inputs.remove(1);

        // Extract the index of the non existing chunked transaction.
        let index = match chunk {
            Input::ModeSpecific(ProxyInput::TransactionChunk { i, .. }) => i,
            _ => panic!("Expected a transaction chunk"),
        };

        host.add_external(Bytes::from(input_to_bytes(SMART_ROLLUP_ADDRESS, chunk)));

        let _inbox_content =
            read_proxy_inbox(&mut host, SMART_ROLLUP_ADDRESS, &MavrykContracts::default())
                .unwrap();

        // The unknown chunk should not exist.
        let chunked_transaction_path = chunked_transaction_path(&tx_hash).unwrap();
        let transaction_chunk_path =
            transaction_chunk_path(&chunked_transaction_path, index).unwrap();
        if read_transaction_chunk_data(&mut host, &transaction_chunk_path).is_ok() {
            panic!("The chunk should not exist in the storage")
        }
    }

    #[test]
    // Assert that a transaction is marked as complete only when each chunk
    // is stored in the storage. That is, if a transaction chunk is sent twice,
    // it rewrites the chunk.
    //
    // This serves as a non-regression test, a previous optimization made unwanted
    // behavior for very little gain:
    //
    // Level 0:
    // - New chunk of size 2
    // - Chunk 0
    //
    // Level 1:
    // - New chunk of size 2 (ignored)
    // - Chunk 0
    // |--> Oh great! I have the two chunks for my transaction, it is then complete!
    // - Chunk 1
    // |--> Fails because the chunk is unknown
    fn transaction_is_complete_when_each_chunk_is_stored() {
        let mut host = MockHost::default();

        let (data, tx) = large_transaction();
        let tx_hash: [u8; TRANSACTION_HASH_SIZE] = Keccak256::digest(data.clone()).into();

        let inputs = make_chunked_transactions(tx_hash, data);
        // The test works if there are 3 inputs: new chunked of size 2, first and second
        // chunks.
        assert_eq!(inputs.len(), 3);

        let new_chunk = inputs[0].clone();
        let chunk0 = inputs[1].clone();

        host.add_external(Bytes::from(input_to_bytes(SMART_ROLLUP_ADDRESS, new_chunk)));

        host.add_external(Bytes::from(input_to_bytes(SMART_ROLLUP_ADDRESS, chunk0)));

        let inbox_content =
            read_proxy_inbox(&mut host, SMART_ROLLUP_ADDRESS, &MavrykContracts::default())
                .unwrap()
                .unwrap();
        assert_eq!(
            inbox_content,
            ProxyInboxContent {
                transactions: vec![],
            }
        );

        // On the next level, try to re-give the chunks, but this time in full:
        for input in inputs {
            host.add_external(Bytes::from(input_to_bytes(SMART_ROLLUP_ADDRESS, input)))
        }
        let inbox_content =
            read_proxy_inbox(&mut host, SMART_ROLLUP_ADDRESS, &MavrykContracts::default())
                .unwrap()
                .unwrap();

        let expected_transactions = vec![Transaction {
            tx_hash,
            content: Ethereum(tx),
        }];
        assert_eq!(inbox_content.transactions, expected_transactions);
    }

    #[test]
    fn parse_valid_simple_transaction_framed() {
        // Don't use zero-hash for rollup here - as the long string of zeros is still valid under the previous
        // parsing. This won't happen in practice, though
        let address = smart_rollup_address();

        let mut host = MockHost::with_address(&address);

        let tx_bytes = &hex::decode("f86d80843b9aca00825208940b52d4d3be5d18a7ab5\
        e4476a2f5382bbf2b38d888016345785d8a000080820a95a0d9ef1298c18c88604e3f08e14907a17dfa81b1dc6b37948abe189d8db5cb8a43a06\
        fc7040a71d71d3cb74bd05ead7046b10668ad255da60391c017eea31555f156").unwrap();
        let tx_hash = Keccak256::digest(tx_bytes).into();
        let tx = EthereumTransactionCommon::from_bytes(tx_bytes).unwrap();

        let input =
            Input::ModeSpecific(ProxyInput::SimpleTransaction(Box::new(Transaction {
                tx_hash,
                content: Ethereum(tx.clone()),
            })));

        let mut buffer = Vec::new();
        match input {
            Input::ModeSpecific(ProxyInput::SimpleTransaction(tx)) => {
                // Simple transaction tag
                buffer.push(0);
                buffer.extend_from_slice(&tx.tx_hash);
                let mut tx_bytes = match tx.content {
                    Ethereum(tx) => tx.into(),
                    _ => panic!(
                        "Simple transaction can contain only ethereum transactions"
                    ),
                };

                buffer.append(&mut tx_bytes)
            }
            _ => unreachable!("Not tested"),
        };

        let framed = ExternalMessageFrame::Targetted {
            address,
            contents: buffer,
        };

        host.add_external(framed);

        let inbox_content =
            read_proxy_inbox(&mut host, SMART_ROLLUP_ADDRESS, &MavrykContracts::default())
                .unwrap()
                .unwrap();
        let expected_transactions = vec![Transaction {
            tx_hash,
            content: Ethereum(tx),
        }];
        assert_eq!(inbox_content.transactions, expected_transactions);
    }

    #[test]
    fn empty_inbox_returns_none() {
        let mut host = MockHost::default();

        // Even reading the inbox with only the default elements returns
        // an empty inbox content. As we test in isolation there is nothing
        // in the inbox, we mock it by adding a single input.
        host.add_external(Bytes::from(vec![]));
        let inbox_content =
            read_proxy_inbox(&mut host, SMART_ROLLUP_ADDRESS, &MavrykContracts::default())
                .unwrap();
        assert!(inbox_content.is_some());

        // Reading again the inbox returns no inbox content at all.
        let inbox_content =
            read_proxy_inbox(&mut host, SMART_ROLLUP_ADDRESS, &MavrykContracts::default())
                .unwrap();
        assert!(inbox_content.is_none());
    }
}
