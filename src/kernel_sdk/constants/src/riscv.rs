// SPDX-FileCopyrightText: 2023 TriliTech <contact@trili.tech>
//
// SPDX-License-Identifier: MIT

/// Extension ID for `sbi_console_putchar`
pub const SBI_CONSOLE_PUTCHAR: u64 = 0x01;

/// Extension ID for `sbi_shutdown`
pub const SBI_SHUTDOWN: u64 = 0x08;

/// Extension ID for Mavryk-specific functions
// IDs from 0x0A000000 to 0x0AFFFFFF are "firmware-specific" extension IDs
pub const SBI_FIRMWARE_MAVRYK: u64 = 0x0A000000;

/// Function ID for `sbi_mavryk_inbox_next`
pub const SBI_MAVRYK_INBOX_NEXT: u64 = 0x01;

/// Function ID for `sbi_mavryk_meta_origination_level`
pub const SBI_MAVRYK_META_ORIGINATION_LEVEL: u64 = 0x03;

/// Function ID for `sbi_mavryk_meta_address`
pub const SBI_MAVRYK_META_ADDRESS: u64 = 0x04;

/// Function ID for `sbi_mavryk_ed25519_verify`
pub const SBI_MAVRYK_ED25519_VERIFY: u64 = 0x05;

/// Function ID for `sbi_mavryk_ed25519_sign`
pub const SBI_MAVRYK_ED25519_SIGN: u64 = 0x06;

/// Function ID for `sbi_mavryk_blake2b_hash256`
pub const SBI_MAVRYK_BLAKE2B_HASH256: u64 = 0x07;
