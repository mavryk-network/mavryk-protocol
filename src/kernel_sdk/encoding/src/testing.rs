// SPDX-FileCopyrightText: 2022 TriliTech <contact@trili.tech>
//
// SPDX-License-Identifier: MIT

//! Helper functions for setting up DAC testing environment

#![cfg(feature = "testing")]

use mavryk_data_encoding::types::Zarith;
use num_bigint::BigInt;
use num_traits::FromPrimitive;

/// Converts bitset (as usize) into Zarith.
pub fn make_witnesses(bitset: usize) -> Zarith {
    Zarith(BigInt::from_usize(bitset).unwrap())
}
