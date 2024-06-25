// SPDX-FileCopyrightText: 2022-2024 TriliTech <contact@trili.tech>
// SPDX-FileCopyrightText: 2023 Marigold <contact@marigold.dev>
// SPDX-FileCopyrightText: 2023 Nomadic Labs <contact@nomadic-labs.com>
// SPDX-FileCopyrightText: 2023 Functori <contact@functori.com>
//
// SPDX-License-Identifier: MIT

use crate::blueprint_storage::MAXIMUM_NUMBER_OF_CHUNKS;
use crate::configuration::MavrykContracts;
use crate::delayed_inbox::DelayedInbox;
use crate::tick_model::constants::{
    TICKS_FOR_BLUEPRINT_CHUNK_SIGNATURE, TICKS_FOR_DELAYED_MESSAGES,
    TICKS_PER_DEPOSIT_PARSING,
};
use crate::{
    inbox::{Deposit, Transaction, TransactionContent},
    sequencer_blueprint::{SequencerBlueprint, UnsignedSequencerBlueprint},
    upgrade::KernelUpgrade,
    upgrade::SequencerUpgrade,
};
use primitive_types::{H160, U256};
use rlp::Encodable;
use sha3::{Digest, Keccak256};
use mavryk_crypto_rs::{hash::ContractKt1Hash, PublicKeySignatureVerifier};
use mavryk_ethereum::{
    rlp_helpers::FromRlpBytes,
    transaction::{TransactionHash, TRANSACTION_HASH_SIZE},
    tx_common::EthereumTransactionCommon,
    wei::eth_from_mumav,
};
use mavryk_evm_logging::{log, Level::*};
use mavryk_smart_rollup_encoding::{
    contract::Contract,
    inbox::{
        ExternalMessageFrame, InboxMessage, InfoPerLevel, InternalInboxMessage, Transfer,
    },
    michelson::{ticket::FA2_1Ticket, MichelsonBytes, MichelsonOr, MichelsonPair},
    public_key::PublicKey,
};
use mavryk_smart_rollup_host::input::Message;
use mavryk_smart_rollup_host::runtime::Runtime;

/// On an option, either the value, or if `None`, interrupt and return the
/// default value of the return type instead.
#[macro_export]
macro_rules! parsable {
    ($expr : expr) => {
        match $expr {
            Some(x) => x,
            None => return Default::default(),
        }
    };
}

/// Divides one slice into two at an index.
///
/// The first will contain all indices from `[0, mid)` (excluding the index
/// `mid` itself) and the second will contain all indices from `[mid, len)`
/// (excluding the index `len` itself).
///
/// Will return None if `mid > len`.
pub fn split_at(bytes: &[u8], mid: usize) -> Option<(&[u8], &[u8])> {
    let left = bytes.get(0..mid)?;
    let right = bytes.get(mid..)?;
    Some((left, right))
}

pub const SIMULATION_TAG: u8 = u8::MAX;
const EVM_NODE_DELAYED_INPUT_TAG: u8 = u8::MAX - 1;

const SIMPLE_TRANSACTION_TAG: u8 = 0;

const NEW_CHUNKED_TRANSACTION_TAG: u8 = 1;

const TRANSACTION_CHUNK_TAG: u8 = 2;

const SEQUENCER_BLUEPRINT_TAG: u8 = 3;

const FORCE_KERNEL_UPGRADE_TAG: u8 = 0xff;

pub const MAX_SIZE_PER_CHUNK: usize = 4095 // Max input size minus external tag
            - 1 // ExternalMessageFrame tag
            - 20 // Smart rollup address size (ExternalMessageFrame::Targetted)
            - 1  // Transaction chunk tag
            - 2  // Number of chunks (u16)
            - 32 // Transaction hash size
            - 32; // Chunk hash size

#[derive(Debug, PartialEq, Clone)]
pub struct LevelWithInfo {
    pub level: u32,
    pub info: InfoPerLevel,
}

#[derive(Debug, PartialEq, Clone)]
pub enum ProxyInput {
    SimpleTransaction(Box<Transaction>),
    NewChunkedTransaction {
        tx_hash: TransactionHash,
        num_chunks: u16,
        chunk_hashes: Vec<TransactionHash>,
    },
    TransactionChunk {
        tx_hash: TransactionHash,
        i: u16,
        chunk_hash: TransactionHash,
        data: Vec<u8>,
    },
}

#[derive(Debug, PartialEq, Clone)]
pub enum SequencerInput {
    DelayedInput(Box<Transaction>),
    SequencerBlueprint(SequencerBlueprint),
}

#[derive(Debug, PartialEq, Clone)]
pub enum Input<Mode> {
    ModeSpecific(Mode),
    Deposit(Deposit),
    Upgrade(KernelUpgrade),
    SequencerUpgrade(SequencerUpgrade),
    RemoveSequencer,
    Info(LevelWithInfo),
    ForceKernelUpgrade,
}

#[derive(Debug, PartialEq, Default)]
pub enum InputResult<Mode> {
    /// No further inputs
    NoInput,
    /// Some decoded input
    Input(Input<Mode>),
    /// Simulation mode starts after this input
    Simulation,
    #[default]
    /// Unparsable input, to be ignored
    Unparsable,
}

pub type RollupType = MichelsonOr<
    MichelsonOr<MichelsonPair<MichelsonBytes, FA2_1Ticket>, MichelsonBytes>,
    MichelsonBytes,
>;

/// Implements the trait for an input to be readable from the inbox, either
/// being an external input or an L1 smart contract input. It assumes all
/// verifications have already been done:
///
/// - The original inputs are prefixed by the frame protocol for the correct
/// rollup, and the prefix has been removed
///
/// - The internal message was addressed to the rollup, and `parse_internal`
/// expects the bytes from `Left (Right <bytes>)`
pub trait Parsable {
    type Context;

    fn parse_external(
        tag: &u8,
        input: &[u8],
        context: &mut Self::Context,
    ) -> InputResult<Self>
    where
        Self: std::marker::Sized;

    fn parse_internal_bytes(
        source: ContractKt1Hash,
        bytes: &[u8],
        context: &mut Self::Context,
    ) -> InputResult<Self>
    where
        Self: std::marker::Sized;

    fn on_deposit(context: &mut Self::Context);
}

impl ProxyInput {
    fn parse_simple_transaction(bytes: &[u8]) -> InputResult<Self> {
        // Next 32 bytes is the transaction hash.
        // Remaining bytes is the rlp encoded transaction.
        let (tx_hash, remaining) = parsable!(split_at(bytes, TRANSACTION_HASH_SIZE));
        let tx_hash: TransactionHash = parsable!(tx_hash.try_into().ok());
        let produced_hash: [u8; TRANSACTION_HASH_SIZE] =
            Keccak256::digest(remaining).into();
        if tx_hash != produced_hash {
            // The produced hash from the transaction data is not the same as the
            // one sent, the message is ignored.
            return InputResult::Unparsable;
        }
        let tx: EthereumTransactionCommon = parsable!(remaining.try_into().ok());
        InputResult::Input(Input::ModeSpecific(Self::SimpleTransaction(Box::new(
            Transaction {
                tx_hash,
                content: TransactionContent::Ethereum(tx),
            },
        ))))
    }

    fn parse_new_chunked_transaction(bytes: &[u8]) -> InputResult<Self> {
        // Next 32 bytes is the transaction hash.
        let (tx_hash, remaining) = parsable!(split_at(bytes, TRANSACTION_HASH_SIZE));
        let tx_hash: TransactionHash = parsable!(tx_hash.try_into().ok());
        // Next 2 bytes is the number of chunks.
        let (num_chunks, remaining) = parsable!(split_at(remaining, 2));
        let num_chunks = u16::from_le_bytes(num_chunks.try_into().unwrap());
        if remaining.len() != (TRANSACTION_HASH_SIZE * usize::from(num_chunks)) {
            return InputResult::Unparsable;
        }
        let mut chunk_hashes = vec![];
        let mut remaining = remaining;
        for _ in 0..num_chunks {
            let (chunk_hash, remaining_hashes) =
                parsable!(split_at(remaining, TRANSACTION_HASH_SIZE));
            let chunk_hash: TransactionHash = parsable!(chunk_hash.try_into().ok());
            remaining = remaining_hashes;
            chunk_hashes.push(chunk_hash)
        }
        InputResult::Input(Input::ModeSpecific(Self::NewChunkedTransaction {
            tx_hash,
            num_chunks,
            chunk_hashes,
        }))
    }

    fn parse_transaction_chunk(bytes: &[u8]) -> InputResult<Self> {
        // Next 32 bytes is the transaction hash.
        let (tx_hash, remaining) = parsable!(split_at(bytes, TRANSACTION_HASH_SIZE));
        let tx_hash: TransactionHash = parsable!(tx_hash.try_into().ok());
        // Next 2 bytes is the index.
        let (i, remaining) = parsable!(split_at(remaining, 2));
        let i = u16::from_le_bytes(i.try_into().unwrap());
        // Next 32 bytes is the chunk hash.
        let (chunk_hash, remaining) =
            parsable!(split_at(remaining, TRANSACTION_HASH_SIZE));
        let chunk_hash: TransactionHash = parsable!(chunk_hash.try_into().ok());
        let data_hash: [u8; TRANSACTION_HASH_SIZE] = Keccak256::digest(remaining).into();
        // Check if the produced hash from the data is the same as the chunk hash.
        if chunk_hash != data_hash {
            return InputResult::Unparsable;
        }
        InputResult::Input(Input::ModeSpecific(Self::TransactionChunk {
            tx_hash,
            i,
            chunk_hash,
            data: remaining.to_vec(),
        }))
    }
}

impl Parsable for ProxyInput {
    type Context = ();

    fn parse_external(tag: &u8, input: &[u8], _: &mut ()) -> InputResult<Self> {
        // External transactions are only allowed in proxy mode
        match *tag {
            SIMPLE_TRANSACTION_TAG => Self::parse_simple_transaction(input),
            NEW_CHUNKED_TRANSACTION_TAG => Self::parse_new_chunked_transaction(input),
            TRANSACTION_CHUNK_TAG => Self::parse_transaction_chunk(input),
            _ => InputResult::Unparsable,
        }
    }

    fn parse_internal_bytes(
        _: ContractKt1Hash,
        _: &[u8],
        _: &mut (),
    ) -> InputResult<Self> {
        InputResult::Unparsable
    }

    fn on_deposit(_: &mut Self::Context) {}
}

pub struct SequencerParsingContext {
    pub sequencer: PublicKey,
    pub delayed_bridge: ContractKt1Hash,
    pub allocated_ticks: u64,
}

impl SequencerInput {
    fn parse_sequencer_blueprint_input(
        bytes: &[u8],
        context: &mut SequencerParsingContext,
    ) -> InputResult<Self> {
        // Inputs are 4096 bytes longs at most, and even in the future they
        // should be limited by the size of native words of the VM which is
        // 32bits.
        context.allocated_ticks = context
            .allocated_ticks
            .saturating_sub(TICKS_FOR_BLUEPRINT_CHUNK_SIGNATURE);

        // Parse the sequencer blueprint
        let seq_blueprint: SequencerBlueprint =
            parsable!(FromRlpBytes::from_rlp_bytes(bytes).ok());

        // Creates and encodes the unsigned blueprint:
        let unsigned_seq_blueprint: UnsignedSequencerBlueprint = (&seq_blueprint).into();
        if MAXIMUM_NUMBER_OF_CHUNKS < unsigned_seq_blueprint.nb_chunks {
            return InputResult::Unparsable;
        }
        let bytes = unsigned_seq_blueprint.rlp_bytes().to_vec();
        // The sequencer signs the hash of the blueprint.
        let msg = mavryk_crypto_rs::blake2b::digest_256(&bytes).unwrap();

        let correctly_signed = context
            .sequencer
            .verify_signature(&seq_blueprint.signature, &msg)
            .unwrap_or(false);

        if correctly_signed {
            InputResult::Input(Input::ModeSpecific(Self::SequencerBlueprint(
                seq_blueprint,
            )))
        } else {
            InputResult::Unparsable
        }
    }
}

impl Parsable for SequencerInput {
    type Context = SequencerParsingContext;

    fn parse_external(
        tag: &u8,
        input: &[u8],
        context: &mut Self::Context,
    ) -> InputResult<Self> {
        // External transactions are only allowed in proxy mode
        match *tag {
            SEQUENCER_BLUEPRINT_TAG => {
                Self::parse_sequencer_blueprint_input(input, context)
            }
            _ => InputResult::Unparsable,
        }
    }

    /// Parses transactions that come from the delayed inbox.
    fn parse_internal_bytes(
        source: ContractKt1Hash,
        bytes: &[u8],
        context: &mut Self::Context,
    ) -> InputResult<Self> {
        context.allocated_ticks = context
            .allocated_ticks
            .saturating_sub(TICKS_FOR_DELAYED_MESSAGES);

        if context.delayed_bridge.as_ref() != source.as_ref() {
            return InputResult::Unparsable;
        };
        let tx = parsable!(EthereumTransactionCommon::from_bytes(bytes).ok());
        let tx_hash: TransactionHash = Keccak256::digest(bytes).into();

        InputResult::Input(Input::ModeSpecific(Self::DelayedInput(Box::new(
            Transaction {
                tx_hash,
                content: TransactionContent::EthereumDelayed(tx),
            },
        ))))
    }

    fn on_deposit(context: &mut Self::Context) {
        context.allocated_ticks = context
            .allocated_ticks
            .saturating_sub(TICKS_PER_DEPOSIT_PARSING);
    }
}

impl<Mode: Parsable> InputResult<Mode> {
    fn parse_kernel_upgrade(bytes: &[u8]) -> Self {
        let kernel_upgrade = parsable!(KernelUpgrade::from_rlp_bytes(bytes).ok());
        Self::Input(Input::Upgrade(kernel_upgrade))
    }

    fn parse_sequencer_update(bytes: &[u8]) -> Self {
        if bytes.is_empty() {
            Self::Input(Input::RemoveSequencer)
        } else {
            let sequencer_upgrade =
                parsable!(SequencerUpgrade::from_rlp_bytes(bytes).ok());
            Self::Input(Input::SequencerUpgrade(sequencer_upgrade))
        }
    }

    /// Parses an external message
    ///
    // External message structure :
    // FRAMING_PROTOCOL_TARGETTED 21B / MESSAGE_TAG 1B / DATA
    fn parse_external(
        input: &[u8],
        smart_rollup_address: &[u8],
        context: &mut Mode::Context,
    ) -> Self {
        // Compatibility with framing protocol for external messages
        let remaining = match ExternalMessageFrame::parse(input) {
            Ok(ExternalMessageFrame::Targetted { address, contents })
                if address.hash().as_ref() == smart_rollup_address =>
            {
                contents
            }
            _ => return InputResult::Unparsable,
        };

        let (transaction_tag, remaining) = parsable!(remaining.split_first());
        // External transactions are only allowed in proxy mode
        match *transaction_tag {
            FORCE_KERNEL_UPGRADE_TAG => Self::Input(Input::ForceKernelUpgrade),
            _ => Mode::parse_external(transaction_tag, remaining, context),
        }
    }

    fn parse_simulation(input: &[u8]) -> Self {
        if input.is_empty() {
            InputResult::Simulation
        } else {
            InputResult::Unparsable
        }
    }

    fn parse_deposit<Host: Runtime>(
        host: &mut Host,
        ticket: FA2_1Ticket,
        receiver: MichelsonBytes,
        ticketer: &Option<ContractKt1Hash>,
        context: &mut Mode::Context,
    ) -> Self {
        // Account for tick at the beginning of the deposit, in case it fails
        // directly. We prefer to overapproximate rather than under approximate.
        Mode::on_deposit(context);
        match &ticket.creator().0 {
            Contract::Originated(kt1) if Some(kt1) == ticketer.as_ref() => (),
            _ => {
                log!(host, Info, "Deposit ignored because of different ticketer");
                return InputResult::Unparsable;
            }
        };

        // Amount
        let (_sign, amount_bytes) = ticket.amount().to_bytes_le();
        // We use the `U256::from_little_endian` as it takes arbitrary long
        // bytes. Afterward it's transform to `u64` to use `eth_from_mumav`, it's
        // obviously safe as we deposit CTEZ and the amount is limited by
        // the XTZ quantity.
        let amount: u64 = U256::from_little_endian(&amount_bytes).as_u64();
        let amount: U256 = eth_from_mumav(amount);

        // EVM address
        let receiver_bytes = receiver.0;
        if receiver_bytes.len() != std::mem::size_of::<H160>() {
            log!(
                host,
                Info,
                "Deposit ignored because of invalid receiver address"
            );
            return InputResult::Unparsable;
        }
        let receiver = H160::from_slice(&receiver_bytes);

        let content = Deposit { amount, receiver };
        log!(host, Info, "Deposit of {} to {}.", amount, receiver);
        Self::Input(Input::Deposit(content))
    }

    fn parse_internal_transfer<Host: Runtime>(
        host: &mut Host,
        transfer: Transfer<RollupType>,
        smart_rollup_address: &[u8],
        mavryk_contracts: &MavrykContracts,
        context: &mut Mode::Context,
    ) -> Self {
        if transfer.destination.hash().0 != smart_rollup_address {
            log!(
                host,
                Info,
                "Deposit ignored because of different smart rollup address"
            );
            return InputResult::Unparsable;
        }

        let source = transfer.sender;

        match transfer.payload {
            MichelsonOr::Left(left) => match left {
                MichelsonOr::Left(MichelsonPair(receiver, ticket)) => {
                    Self::parse_deposit(
                        host,
                        ticket,
                        receiver,
                        &mavryk_contracts.ticketer,
                        context,
                    )
                }
                MichelsonOr::Right(MichelsonBytes(bytes)) => {
                    Mode::parse_internal_bytes(source, &bytes, context)
                }
            },
            MichelsonOr::Right(MichelsonBytes(bytes)) => {
                if mavryk_contracts.is_admin(&source)
                    || mavryk_contracts.is_kernel_governance(&source)
                    || mavryk_contracts.is_kernel_security_governance(&source)
                {
                    Self::parse_kernel_upgrade(&bytes)
                } else if mavryk_contracts.is_sequencer_governance(&source) {
                    Self::parse_sequencer_update(&bytes)
                } else {
                    Self::Unparsable
                }
            }
        }
    }

    fn parse_internal<Host: Runtime>(
        host: &mut Host,
        message: InternalInboxMessage<RollupType>,
        smart_rollup_address: &[u8],
        mavryk_contracts: &MavrykContracts,
        context: &mut Mode::Context,
        level: u32,
    ) -> Self {
        match message {
            InternalInboxMessage::InfoPerLevel(info) => {
                InputResult::Input(Input::Info(LevelWithInfo { level, info }))
            }
            InternalInboxMessage::Transfer(transfer) => Self::parse_internal_transfer(
                host,
                transfer,
                smart_rollup_address,
                mavryk_contracts,
                context,
            ),
            _ => InputResult::Unparsable,
        }
    }

    pub fn parse<Host: Runtime>(
        host: &mut Host,
        input: Message,
        smart_rollup_address: [u8; 20],
        mavryk_contracts: &MavrykContracts,
        context: &mut Mode::Context,
    ) -> Self {
        let bytes = Message::as_ref(&input);
        let (input_tag, remaining) = parsable!(bytes.split_first());
        if *input_tag == SIMULATION_TAG {
            return Self::parse_simulation(remaining);
        };
        if *input_tag == EVM_NODE_DELAYED_INPUT_TAG {
            let mut delayed_inbox = DelayedInbox::new(host).unwrap();
            if let Ok(transaction) = Transaction::from_rlp_bytes(remaining) {
                delayed_inbox
                    .save_transaction(host, transaction, 0.into(), 0u32)
                    .unwrap();
            }
            return InputResult::Unparsable;
        };

        match InboxMessage::<RollupType>::parse(bytes) {
            Ok((_remaing, message)) => match message {
                InboxMessage::External(message) => {
                    Self::parse_external(message, &smart_rollup_address, context)
                }
                InboxMessage::Internal(message) => Self::parse_internal(
                    host,
                    message,
                    &smart_rollup_address,
                    mavryk_contracts,
                    context,
                    input.level,
                ),
            },
            Err(_) => InputResult::Unparsable,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use mavryk_smart_rollup_host::input::Message;
    use mavryk_smart_rollup_mock::MockHost;

    const ZERO_SMART_ROLLUP_ADDRESS: [u8; 20] = [0; 20];

    #[test]
    fn parse_unparsable_transaction() {
        let mut host = MockHost::default();

        let message = Message::new(0, 0, vec![1, 9, 32, 58, 59, 30]);
        assert_eq!(
            InputResult::<ProxyInput>::parse(
                &mut host,
                message,
                ZERO_SMART_ROLLUP_ADDRESS,
                &MavrykContracts {
                    ticketer: None,
                    admin: None,
                    sequencer_governance: None,
                    kernel_governance: None,
                    kernel_security_governance: None,
                },
                &mut (),
            ),
            InputResult::Unparsable
        )
    }
}
