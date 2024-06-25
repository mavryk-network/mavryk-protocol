// SPDX-FileCopyrightText: 2024 Functori <contact@functori.com>
// SPDX-FileCopyrightText: 2023 draganrakita
//
// SPDX-License-Identifier: MIT

use core::cmp::min;

use alloc::vec::Vec;
use primitive_types::{H160, H256};
use sha2::Digest;
use sha3::Keccak256;

/// Get an array from the data, if data does not contain `start` to `len` bytes, add right padding with
/// zeroes
#[inline(always)]
pub fn get_right_padded<const S: usize>(data: &[u8], offset: usize) -> [u8; S] {
    let mut padded = [0; S];
    let start = min(offset, data.len());
    let end = min(start.saturating_add(S), data.len());
    padded[..end - start].copy_from_slice(&data[start..end]);
    padded
}

/// Get a vector of the data, if data does not contain the slice of `start` to `len`, right pad missing
/// part with zeroes
#[inline(always)]
pub fn get_right_padded_vec(data: &[u8], offset: usize, len: usize) -> Vec<u8> {
    let mut padded = vec![0; len];
    let start = min(offset, data.len());
    let end = min(start.saturating_add(len), data.len());
    padded[..end - start].copy_from_slice(&data[start..end]);
    padded
}

/// Left padding until `len`. If data is more then len, truncate the right most bytes.
#[inline(always)]
pub fn left_padding<const S: usize>(data: &[u8]) -> [u8; S] {
    let mut padded = [0; S];
    let end = min(S, data.len());
    padded[S - end..].copy_from_slice(&data[..end]);
    padded
}

/// Left padding until `len`. If data is more then len, truncate the right most bytes.
#[inline(always)]
pub fn left_padding_vec(data: &[u8], len: usize) -> Vec<u8> {
    let mut padded = vec![0; len];
    let end = min(len, data.len());
    padded[len - end..].copy_from_slice(&data[..end]);
    padded
}

pub fn create_address_legacy(caller: &H160, nonce: &u64) -> H160 {
    let mut stream = rlp::RlpStream::new_list(2);
    stream.append(caller);
    stream.append(nonce);
    H256::from_slice(Keccak256::digest(&stream.out()).as_slice()).into()
}
