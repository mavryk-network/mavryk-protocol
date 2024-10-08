// SPDX-FileCopyrightText: 2023 Nomadic Labs <contact@nomadic-labs.com>
//
// SPDX-License-Identifier: MIT

use primitive_types::U256;

pub type Wei = U256;

pub const ETH_AS_WEI: u64 = 1_000_000_000_000_000_000;

pub fn from_eth(eth: u64) -> Wei {
    Wei::from(eth) * Wei::from(ETH_AS_WEI)
}

pub fn eth_from_mumav(mumav: u64) -> Wei {
    // Mumav is 10^6, Wei is 10^18
    U256::from(mumav) * U256::exp10(12)
}
