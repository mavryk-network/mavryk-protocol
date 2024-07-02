// SPDX-FileCopyrightText: 2023 Nomadic Labs <contact@nomadic-labs.com>
// SPDX-FileCopyrightText: 2023-2024 TriliTech <contact@trili.tech>
// SPDX-FileCopyrightText: 2023 Functori <contact@functori.com>
// SPDX-FileCopyrightText: 2023 Marigold <contact@marigold.dev>
//
// SPDX-License-Identifier: MIT

use crate::configuration::{fetch_configuration, Configuration};
use crate::error::Error;
use crate::error::UpgradeProcessError::Fallback;
use crate::migration::storage_migration;
use crate::stage_one::fetch;
use crate::storage::read_sequencer_pool_address;
use anyhow::Context;
use delayed_inbox::DelayedInbox;
use evm_execution::Config;
use fallback_upgrade::fallback_backup_kernel;
use inbox::StageOneStatus;
use mavryk_crypto_rs::hash::ContractKt1Hash;
use mavryk_ethereum::block::BlockFees;
use mavryk_evm_logging::{log, Level::*};
use mavryk_smart_rollup_encoding::public_key::PublicKey;
use mavryk_smart_rollup_encoding::timestamp::Timestamp;
use mavryk_smart_rollup_entrypoint::kernel_entry;
use mavryk_smart_rollup_host::runtime::Runtime;
use migration::MigrationStatus;
use primitive_types::U256;
use reveal_storage::{is_revealed_storage, reveal_storage};
use safe_storage::WORLD_STATE_PATH;
use storage::{
    read_base_fee_per_gas, read_chain_id, read_da_fee, read_kernel_version,
    read_last_info_per_level_timestamp, read_last_info_per_level_timestamp_stats,
    read_minimum_base_fee_per_gas, store_base_fee_per_gas, store_chain_id, store_da_fee,
    store_kernel_version, store_storage_version, STORAGE_VERSION, STORAGE_VERSION_PATH,
};

mod apply;
mod block;
mod block_in_progress;
mod blueprint;
mod blueprint_storage;
mod configuration;
mod delayed_inbox;
mod error;
mod event;
mod fallback_upgrade;
mod fees;
mod gas_price;
mod inbox;
mod indexable_storage;
mod internal_storage;
mod linked_list;
mod migration;
mod mock_internal;
mod parsing;
mod reveal_storage;
mod safe_storage;
mod sequencer_blueprint;
mod simulation;
mod stage_one;
mod storage;
mod tick_model;
mod upgrade;

extern crate alloc;

/// The chain id will need to be unique when the EVM rollup is deployed in
/// production.
pub const CHAIN_ID: u32 = 1337;

/// The configuration for the EVM execution.
pub const CONFIG: Config = Config::shanghai();

const KERNEL_VERSION: &str = env!("GIT_HASH");

pub fn stage_zero<Host: Runtime>(host: &mut Host) -> Result<MigrationStatus, Error> {
    log!(host, Debug, "Entering stage zero.");
    init_storage_versioning(host)?;
    storage_migration(host)
}

/// Returns the current timestamp for the execution. Based on the last
/// info per level read (or default timestamp if it was not set), plus the
/// artifical average block time.
pub fn current_timestamp<Host: Runtime>(host: &mut Host) -> Timestamp {
    let timestamp =
        read_last_info_per_level_timestamp(host).unwrap_or_else(|_| Timestamp::from(0));
    let (numbers, total) =
        read_last_info_per_level_timestamp_stats(host).unwrap_or((1i64, 0i64));
    let average_block_time = total / numbers;
    let seconds = timestamp.i64() + average_block_time;

    Timestamp::from(seconds)
}

// DO NOT RENAME: function name is used during benchmark
// Never inlined when the kernel is compiled for benchmarks, to ensure the
// function is visible in the profiling results.
#[cfg_attr(feature = "benchmark", inline(never))]
pub fn stage_one<Host: Runtime>(
    host: &mut Host,
    smart_rollup_address: [u8; 20],
    configuration: &mut Configuration,
) -> Result<StageOneStatus, anyhow::Error> {
    log!(host, Debug, "Entering stage one.");
    log!(host, Debug, "Configuration: {}", configuration);

    fetch(host, smart_rollup_address, configuration)
}

fn set_kernel_version<Host: Runtime>(host: &mut Host) -> Result<(), Error> {
    match read_kernel_version(host) {
        Ok(kernel_version) => {
            if kernel_version != KERNEL_VERSION {
                store_kernel_version(host, KERNEL_VERSION)?
            };
            Ok(())
        }
        Err(_) => store_kernel_version(host, KERNEL_VERSION),
    }
}

fn init_storage_versioning<Host: Runtime>(host: &mut Host) -> Result<(), Error> {
    match host.store_read(&STORAGE_VERSION_PATH, 0, 0) {
        Ok(_) => Ok(()),
        Err(_) => store_storage_version(host, STORAGE_VERSION),
    }
}

fn retrieve_chain_id<Host: Runtime>(host: &mut Host) -> Result<U256, Error> {
    match read_chain_id(host) {
        Ok(chain_id) => Ok(chain_id),
        Err(_) => {
            let chain_id = U256::from(CHAIN_ID);
            store_chain_id(host, chain_id)?;
            Ok(chain_id)
        }
    }
}
fn retrieve_block_fees<Host: Runtime>(host: &mut Host) -> Result<BlockFees, Error> {
    let minimum_base_fee_per_gas = read_minimum_base_fee_per_gas(host)
        .unwrap_or_else(|_| crate::fees::MINIMUM_BASE_FEE_PER_GAS.into());

    let base_fee_per_gas = match read_base_fee_per_gas(host) {
        Ok(base_fee_per_gas) if base_fee_per_gas > minimum_base_fee_per_gas => {
            base_fee_per_gas
        }
        _ => {
            store_base_fee_per_gas(host, minimum_base_fee_per_gas)?;
            minimum_base_fee_per_gas
        }
    };

    let da_fee = match read_da_fee(host) {
        Ok(da_fee) => da_fee,
        Err(_) => {
            let da_fee = U256::from(fees::DA_FEE_PER_BYTE);
            store_da_fee(host, da_fee)?;
            da_fee
        }
    };

    let block_fees = BlockFees::new(minimum_base_fee_per_gas, base_fee_per_gas, da_fee);

    Ok(block_fees)
}

pub fn main<Host: Runtime>(host: &mut Host) -> Result<(), anyhow::Error> {
    let chain_id = retrieve_chain_id(host).context("Failed to retrieve chain id")?;

    // We always start by doing the migration if needed.
    match stage_zero(host) {
        Ok(MigrationStatus::None) => {
            // No migration in progress. However as we want to have the kernel
            // version written in the storage, we check for its existence
            // at every kernel run.
            // The alternative is to enforce every new kernels use the
            // installer configuration to initialize this value.
            set_kernel_version(host)?;
        }
        // If the migration is still in progress or was finished, we abort the
        // current kernel run.
        Ok(MigrationStatus::InProgress) => {
            host.mark_for_reboot()?;
            return Ok(());
        }
        Ok(MigrationStatus::Done) => {
            // If a migrtion was finished, we update the kernel version
            // in the storage.
            set_kernel_version(host)?;
            host.mark_for_reboot()?;
            let configuration = fetch_configuration(host);
            log!(
                host,
                Info,
                "Configuration after migration: {}",
                configuration
            );
            return Ok(());
        }
        Err(Error::UpgradeError(Fallback)) => {
            // If the migration failed we backup to the previous kernel
            // and force a reboot to reload the kernel.
            fallback_backup_kernel(host)?;
            host.mark_for_reboot()?;
            return Ok(());
        }
        Err(err) => return Err(err.into()),
    };

    // In the very worst case, we want to be able to upgrade the kernel at
    // any time. The kernel upgrades are retrieved from the inbox, therefore
    // we need be able to to always reach the inbox and the kernel upgrade
    // message.
    //
    // Therefore, the code between here and block production is allowed to
    // fail. It should already not be the case, but we do not want to
    // take the risk.

    // Fetch kernel metadata:

    // 1. Fetch the smart rollup address via the host function, it cannot fail.
    let smart_rollup_address = Runtime::reveal_metadata(host).raw_rollup_address;
    // 2. Fetch the per mode configuration of the kernel. Returns the default
    //    configuration if it fails.
    let mut configuration = fetch_configuration(host);
    let sequencer_pool_address = read_sequencer_pool_address(host);

    // Run the stage one, this is a no-op if the inbox was already consumed
    // by another kernel run. This ensures that if the migration does not
    // consume all reboots. At least one reboot will be used to consume the
    // inbox.
    if let StageOneStatus::Reboot =
        stage_one(host, smart_rollup_address, &mut configuration)
            .context("Failed during stage 1")?
    {
        host.mark_for_reboot()?;
        return Ok(());
    };

    let block_fees = retrieve_block_fees(host)?;
    // Start processing blueprints
    #[cfg(not(feature = "benchmark-bypass-stage2"))]
    {
        log!(host, Debug, "Entering stage two.");
        if let block::ComputationResult::RebootNeeded = block::produce(
            host,
            chain_id,
            block_fees,
            &mut configuration,
            sequencer_pool_address,
        )
        .context("Failed during stage 2")?
        {
            host.mark_for_reboot()?;
        }
    }

    #[cfg(feature = "benchmark-bypass-stage2")]
    {
        log!(host, Benchmarking, "Shortcircuiting computation");
        return Ok(());
    }
    Ok(())
}

pub fn kernel_loop<Host: Runtime>(host: &mut Host) {
    // In order to setup the temporary directory, we need to move something
    // from /evm to /tmp, so /evm must be non empty, this only happen
    // at the first run.

    let reboot_counter = host
        .reboot_left()
        .expect("The kernel failed to get the number of reboot left");
    if reboot_counter == 1000 {
        mavryk_smart_rollup_debug::debug_msg!(
            host,
            "------------------ Kernel Invocation ------------------\n"
        )
    }

    let world_state_subkeys = host
        .store_count_subkeys(&WORLD_STATE_PATH)
        .expect("The kernel failed to read the number of /evm/world_state subkeys");

    if world_state_subkeys == 0 {
        host.store_write(&WORLD_STATE_PATH, "Un festival de GADT".as_bytes(), 0)
            .unwrap();
    }

    if is_revealed_storage(host) {
        reveal_storage(
            host,
            option_env!("EVM_SEQUENCER").map(|s| {
                PublicKey::from_b58check(s).expect("Failed parsing EVM_SEQUENCER")
            }),
            option_env!("EVM_ADMIN").map(|s| {
                ContractKt1Hash::from_base58_check(s).expect("Failed parsing EVM_ADMIN")
            }),
        );
    }

    match main(host) {
        Ok(()) => (),
        Err(err) => {
            log!(host, Fatal, "The kernel produced an error: {:?}", err);
        }
    }
}

kernel_entry!(kernel_loop);

#[cfg(test)]
mod tests {
    use std::str::FromStr;

    use crate::blueprint_storage::store_inbox_blueprint_by_number;
    use crate::configuration::Configuration;
    use crate::fees;
    use crate::{
        blueprint::Blueprint,
        inbox::{Transaction, TransactionContent},
        storage,
        upgrade::KernelUpgrade,
    };
    use evm_execution::account_storage::{self, EthereumAccountStorage};
    use mavryk_ethereum::block::BlockFees;
    use mavryk_ethereum::{
        transaction::{TransactionHash, TransactionType},
        tx_common::EthereumTransactionCommon,
    };
    use mavryk_smart_rollup_core::PREIMAGE_HASH_SIZE;
    use mavryk_smart_rollup_debug::Runtime;
    use mavryk_smart_rollup_encoding::timestamp::Timestamp;
    use mavryk_smart_rollup_host::path::RefPath;
    use mavryk_smart_rollup_mock::MockHost;
    use primitive_types::{H160, U256};

    const DUMMY_CHAIN_ID: U256 = U256::one();
    const DUMMY_BASE_FEE_PER_GAS: u64 = 12345u64;
    const DUMMY_DA_FEE: u64 = 2_000_000_000_000u64;

    fn dummy_block_fees() -> BlockFees {
        BlockFees::new(
            DUMMY_BASE_FEE_PER_GAS.into(),
            U256::from(DUMMY_BASE_FEE_PER_GAS),
            DUMMY_DA_FEE.into(),
        )
    }

    fn set_balance<Host: Runtime>(
        host: &mut Host,
        evm_account_storage: &mut EthereumAccountStorage,
        address: &H160,
        balance: U256,
    ) {
        let mut account = evm_account_storage
            .get_or_create(host, &account_storage::account_path(address).unwrap())
            .unwrap();
        let current_balance = account.balance(host).unwrap();
        if current_balance > balance {
            account
                .balance_remove(host, current_balance - balance)
                .unwrap();
        } else {
            account
                .balance_add(host, balance - current_balance)
                .unwrap();
        }
    }

    fn hash_from_nonce(nonce: u64) -> TransactionHash {
        let nonce = u64::to_le_bytes(nonce);
        let mut hash = [0; 32];
        hash[..8].copy_from_slice(&nonce);
        hash
    }

    fn wrap_transaction(nonce: u64, tx: EthereumTransactionCommon) -> Transaction {
        Transaction {
            tx_hash: hash_from_nonce(nonce),
            content: TransactionContent::Ethereum(tx),
        }
    }

    fn blueprint(transactions: Vec<Transaction>) -> Blueprint {
        Blueprint {
            transactions,
            timestamp: Timestamp::from(0i64),
        }
    }

    const CREATE_LOOP_DATA: &str = "608060405234801561001057600080fd5b506101d0806100206000396000f3fe608060405234801561001057600080fd5b506004361061002b5760003560e01c80630b7d796e14610030575b600080fd5b61004a600480360381019061004591906100c2565b61004c565b005b60005b81811015610083576001600080828254610069919061011e565b92505081905550808061007b90610152565b91505061004f565b5050565b600080fd5b6000819050919050565b61009f8161008c565b81146100aa57600080fd5b50565b6000813590506100bc81610096565b92915050565b6000602082840312156100d8576100d7610087565b5b60006100e6848285016100ad565b91505092915050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b60006101298261008c565b91506101348361008c565b925082820190508082111561014c5761014b6100ef565b5b92915050565b600061015d8261008c565b91507fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff820361018f5761018e6100ef565b5b60018201905091905056fea26469706673582212200cd6584173dbec22eba4ce6cc7cc4e702e00e018d340f84fc0ff197faf980ad264736f6c63430008150033";

    const LOOP_1300: &str =
        "0b7d796e0000000000000000000000000000000000000000000000000000000000000514";

    const LOOP_4600: &str =
        "0b7d796e00000000000000000000000000000000000000000000000000000000000011f8";

    const TEST_SK: &str =
        "84e147b8bc36d99cc6b1676318a0635d8febc9f02897b0563ad27358589ee502";

    const TEST_ADDR: &str = "f0affc80a5f69f4a9a3ee01a640873b6ba53e539";

    fn create_and_sign_transaction(
        data: &str,
        nonce: u64,
        gas_limit: u64,
        to: Option<H160>,
        secret_key: &str,
    ) -> EthereumTransactionCommon {
        let data = hex::decode(data).unwrap();

        let gas_price = U256::from(DUMMY_BASE_FEE_PER_GAS);
        let gas_for_fees =
            crate::fees::gas_for_fees(DUMMY_DA_FEE.into(), gas_price, &data, &[])
                .unwrap();

        let unsigned_tx = EthereumTransactionCommon::new(
            TransactionType::Eip1559,
            Some(DUMMY_CHAIN_ID),
            nonce,
            gas_price,
            gas_price,
            gas_limit + gas_for_fees,
            to,
            U256::zero(),
            data,
            vec![],
            None,
        );
        unsigned_tx
            .sign_transaction(String::from(secret_key))
            .unwrap()
    }

    #[test]
    fn test_reboot_during_block_production() {
        // init host
        let mut host = MockHost::default();

        crate::storage::store_minimum_base_fee_per_gas(
            &mut host,
            DUMMY_BASE_FEE_PER_GAS.into(),
        )
        .unwrap();

        // sanity check: no current block
        assert!(
            storage::read_current_block_number(&host).is_err(),
            "Should not have found current block number"
        );

        //provision sender account
        let sender = H160::from_str(TEST_ADDR).unwrap();
        let sender_initial_balance = U256::from(10000000000000000000u64);
        let mut evm_account_storage = account_storage::init_account_storage().unwrap();
        set_balance(
            &mut host,
            &mut evm_account_storage,
            &sender,
            sender_initial_balance,
        );

        // These transactions are generated with the loop.sol contract, which are:
        // - create the contract
        // - call `loop(1200)`
        // - call `loop(4600)`
        let create_transaction =
            create_and_sign_transaction(CREATE_LOOP_DATA, 0, 3_000_000, None, TEST_SK);
        let loop_addr: H160 =
            evm_execution::utilities::create_address_legacy(&sender, &0);
        let loop_1200_tx =
            create_and_sign_transaction(LOOP_1300, 1, 900_000, Some(loop_addr), TEST_SK);
        let loop_4600_tx = create_and_sign_transaction(
            LOOP_4600,
            2,
            2_600_000,
            Some(loop_addr),
            TEST_SK,
        );

        let proposals = vec![
            blueprint(vec![wrap_transaction(0, create_transaction)]),
            blueprint(vec![
                wrap_transaction(1, loop_1200_tx),
                wrap_transaction(2, loop_4600_tx),
            ]),
        ];
        // Store blueprints
        for (i, blueprint) in proposals.into_iter().enumerate() {
            store_inbox_blueprint_by_number(&mut host, blueprint, U256::from(i))
                .expect("Should have stored blueprint");
        }
        // the upgrade mechanism should not start otherwise it will fail
        let broken_kernel_upgrade = KernelUpgrade {
            preimage_hash: [0u8; PREIMAGE_HASH_SIZE],
            activation_timestamp: Timestamp::from(1_000_000i64),
        };
        crate::upgrade::store_kernel_upgrade(&mut host, &broken_kernel_upgrade)
            .expect("Should be able to store kernel upgrade");

        let block_fees = dummy_block_fees();

        // If the upgrade is started, it should raise an error
        let computation_result = crate::block::produce(
            &mut host,
            DUMMY_CHAIN_ID,
            block_fees,
            &mut Configuration::default(),
            None,
        )
        .expect("Should have produced");

        // test there is a new block
        assert_eq!(
            storage::read_current_block_number(&host)
                .expect("should have found a block number"),
            U256::zero(),
            "There should have been a block registered"
        );

        // test reboot is set
        matches!(
            computation_result,
            crate::block::ComputationResult::RebootNeeded
        );
    }

    #[test]
    fn load_block_fees_new() {
        // Arrange
        let mut host = MockHost::default();

        // Act
        let result = crate::retrieve_block_fees(&mut host);

        // Assert
        let expected = BlockFees::new(
            fees::MINIMUM_BASE_FEE_PER_GAS.into(),
            fees::MINIMUM_BASE_FEE_PER_GAS.into(),
            fees::DA_FEE_PER_BYTE.into(),
        );

        assert!(result.is_ok());
        assert_eq!(expected, result.unwrap());
    }

    #[test]
    fn load_block_fees_with_minimum() {
        let min_path =
            RefPath::assert_from(b"/evm/world_state/fees/minimum_base_fee_per_gas")
                .into();

        // Arrange
        let mut host = MockHost::default();

        let min_base_fee = U256::from(17);
        let curr_base_fee = U256::from(20);
        storage::store_base_fee_per_gas(&mut host, curr_base_fee).unwrap();
        storage::write_u256(&mut host, &min_path, min_base_fee).unwrap();

        // Act
        let result = crate::retrieve_block_fees(&mut host);
        let base_fee = storage::read_base_fee_per_gas(&mut host);

        // Assert
        let expected =
            BlockFees::new(min_base_fee, curr_base_fee, fees::DA_FEE_PER_BYTE.into());

        assert!(result.is_ok());
        assert_eq!(expected, result.unwrap());

        assert!(base_fee.is_ok());
        assert_eq!(curr_base_fee, base_fee.unwrap());
    }
}
