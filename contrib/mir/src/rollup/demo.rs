/******************************************************************************/
/*                                                                            */
/* SPDX-License-Identifier: MIT                                               */
/* Copyright (c) [2023] Serokell <hi@serokell.io>                             */
/*                                                                            */
/******************************************************************************/

//!  This is a logic for demo rollup that eventually should be thrown away.

use std::mem::size_of;
use tezos_smart_rollup::{
    inbox::Transfer,
    prelude::{debug_msg, Runtime},
    storage::path::RefPath,
};
use tezos_smart_rollup_encoding::michelson::MichelsonInt;

use super::types::IncomingTransferParam;

pub type Error = String;

const STORAGE_PATH: &RefPath = &RefPath::assert_from(b"/storage");

pub fn process_external_message(host: &mut impl Runtime, payload: &[u8]) -> Result<(), Error> {
    let param = free_form_bytes_to_number(payload);
    call_fibonacci(host, param)
}

pub fn process_internal_message(
    host: &mut impl Runtime,
    transfer: &Transfer<IncomingTransferParam>,
) -> Result<(), Error> {
    let payload: &MichelsonInt = &transfer.payload;
    let param = (payload.0 .0)
        .clone()
        .try_into()
        .map_err(|_| String::from("Too large input"))?;
    call_fibonacci(host, param)
}

pub fn call_fibonacci(host: &mut impl Runtime, param: usize) -> Result<(), Error> {
    let is_storage_empty = host
        .store_has(STORAGE_PATH)
        .map_err(|err| err.to_string())?
        .is_none();
    let storage = if is_storage_empty {
        0
    } else {
        free_form_bytes_to_number(
            host.store_read_all(STORAGE_PATH)
                .map_err(|err| err.to_string())?
                .as_ref(),
        )
    };
    // ↑ That's pretty painful, MR with a higher-level API is on the way

    let new_storage = run_fibonacci(param, storage)?;

    host.store_write_all(STORAGE_PATH, &new_storage.to_le_bytes())
        .map_err(|err| err.to_string())?;
    debug_msg!(host, "Computation successful, result: {new_storage}\n");
    Ok(())
}

fn run_fibonacci(param: usize, _storage: usize) -> Result<usize, Error> {
    // TODO: replace with contract interpretation
    let answers: Vec<usize> = vec![
        0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987, 1597, 2584, 4181,
    ];
    answers
        .get(param)
        .copied()
        .ok_or(String::from("Cannot answer for such large number :shrug:"))
}

/// Accepts both undersized and oversized byte arrays to convert to number.
fn free_form_bytes_to_number(bs: &[u8]) -> usize {
    let mut bs_sized = [0; size_of::<usize>()];
    let bs_len = std::cmp::min(bs_sized.len(), bs.len());
    bs_sized[..bs_len].copy_from_slice(&bs[..bs_len]);
    usize::from_le_bytes(bs_sized)
}

#[cfg(test)]
mod test_message_processing {
    use num_bigint::BigInt;
    use tezos_crypto_rs::hash::ContractKt1Hash;
    use tezos_smart_rollup_encoding::{
        public_key_hash::PublicKeyHash, smart_rollup::SmartRollupAddress,
    };
    use tezos_smart_rollup_mock::MockHost;

    use super::*;

    fn test_on_sample(param: &[u8], expected_res: &[u8]) {
        let mut host = MockHost::default();
        process_external_message(&mut host, param).unwrap();
        assert_eq!(host.store_read_all(STORAGE_PATH).unwrap(), expected_res);
    }

    #[test]
    fn test_external_message_processing_on_samples() {
        // 0th value of the Fibonacci sequence is 0.
        test_on_sample(b"\x00", b"\0\0\0\0\0\0\0\0");
        // 1st value of the Fibonacci sequence is 1.
        test_on_sample(b"\x01", b"\x01\0\0\0\0\0\0\0");
        // 10th value of the Fibonacci sequence is 55.
        test_on_sample(&[10], &[55, 0, 0, 0, 0, 0, 0, 0]);
        // 15th value of the Fibonacci sequence is 610 = 98 + 2*256.
        test_on_sample(&[15], &[98, 2, 0, 0, 0, 0, 0, 0]);
    }

    #[test]
    fn test_internal_message_processing_on_samples() {
        let mut host = MockHost::default();
        let payload = MichelsonInt(BigInt::from(10).into());
        let transfer = Transfer {
            payload,
            sender: ContractKt1Hash::from_base58_check("KT1ThEdxfUcWUwqsdergy3QnbCWGHSUHeHJq")
                .unwrap(),
            source: PublicKeyHash::from_b58check("tz1RjtZUVeLhADFHDL8UwDZA6vjWWhojpu5w").unwrap(),
            destination: SmartRollupAddress::new(host.reveal_metadata().address()),
        };
        process_internal_message(&mut host, &transfer).unwrap();
        assert_eq!(
            host.store_read_all(STORAGE_PATH).unwrap(),
            &[55, 0, 0, 0, 0, 0, 0, 0]
        );
    }
}
