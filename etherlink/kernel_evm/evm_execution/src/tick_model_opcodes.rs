// SPDX-FileCopyrightText: 2023 Marigold <contact@marigold.dev>
// SPDX-FileCopyrightText: 2023 Nomadic Labs <contact@nomadic-labs.com>
// SPDX-FileCopyrightText: 2022-2023 TriliTech <contact@trili.tech>
//
// SPDX-License-Identifier: MIT

//! Ticks per gas per Opcode model for the EVM Kernel

// The values from this file have been autogenerated by a benchmark script. If
// it needs to be updated, please have a look at the script
// `etherlink/kernel_evm/benchmarks/scripts/analysis/opcodes.js`.

use evm::Opcode;

// Default ticks per gas value
const DEFAULT_TICKS_PER_GAS: u64 = 10000;

const ARITHMETIC_TICKS_PER_GAS: u64 = 4000;

// Average: 6098; Standard deviation: 0
const MODEL_0X00: u64 = 6098;

// Average: 4226; Standard deviation: 0
const MODEL_0X01: u64 = 4226;

// Average: 3159; Standard deviation: 1
const MODEL_0X02: u64 = 3161;

// Average: 4233; Standard deviation: 20
const MODEL_0X03: u64 = 4273;

// Average: 2915; Standard deviation: 350
const MODEL_0X04: u64 = 3615;

// No data
const MODEL_0X05: u64 = ARITHMETIC_TICKS_PER_GAS;

// Average: 3641; Standard deviation: 238
const MODEL_0X06: u64 = 4117;

// No data
const MODEL_0X07: u64 = ARITHMETIC_TICKS_PER_GAS;

// No data
const MODEL_0X08: u64 = ARITHMETIC_TICKS_PER_GAS;

// No data
const MODEL_0X09: u64 = ARITHMETIC_TICKS_PER_GAS;

// Average: 4749; Standard deviation: 1
const MODEL_0X0A: u64 = 4751;

// No data
const MODEL_0X0B: u64 = ARITHMETIC_TICKS_PER_GAS;

// Average: 3935; Standard deviation: 1
const MODEL_0X10: u64 = 3937;

// Average: 3936; Standard deviation: 8
const MODEL_0X11: u64 = 3952;

// Average: 7941; Standard deviation: 8
const MODEL_0X12: u64 = 7957;

// Average: 7938; Standard deviation: 0
const MODEL_0X13: u64 = 7938;

// Average: 5398; Standard deviation: 752
const MODEL_0X14: u64 = 6902;

// Average: 4435; Standard deviation: 677
const MODEL_0X15: u64 = 5789;

// Average: 4166; Standard deviation: 1
const MODEL_0X16: u64 = 4168;

// Average: 4167; Standard deviation: 1
const MODEL_0X17: u64 = 4169;

// Average: 4168; Standard deviation: 0
const MODEL_0X18: u64 = 4168;

// Average: 3075; Standard deviation: 0
const MODEL_0X19: u64 = 3075;

// Average: 25166; Standard deviation: 0
const MODEL_0X1A: u64 = 25166;

// Average: 12163; Standard deviation: 30
const MODEL_0X1B: u64 = 12223;

// Average: 11925; Standard deviation: 565
const MODEL_0X1C: u64 = 13055;

// No data, approximated from SHL (0x1B) and SHR (0x1C)
const MODEL_0X1D: u64 = 13000;

fn model_0x20(gas: u64) -> u64 {
    82325 + 2317 * gas
}

// Average: 2922; Standard deviation: 0
const MODEL_0X30: u64 = 2922;

// Average: 1303; Standard deviation: 0
const MODEL_0X31: u64 = 1303;

// Average: 2919; Standard deviation: 0
const MODEL_0X32: u64 = 2919;

// Average: 2927; Standard deviation: 0
const MODEL_0X33: u64 = 2927;

// Average: 3263; Standard deviation: 0
const MODEL_0X34: u64 = 3263;

// Average: 27210; Standard deviation: 42
const MODEL_0X35: u64 = 27294;

// Curated from graphs
const MODEL_0X36: u64 = 10000;

fn model_0x37(gas: u64) -> u64 {
    77142 + 234 * gas
}
// Average: 2495; Standard deviation: 0
const MODEL_0X38: u64 = 2495;

fn model_0x39(gas: u64) -> u64 {
    112156 + 198 * gas
}

// Average: 3272; Standard deviation: 0
const MODEL_0X3A: u64 = 3272;

// Average: 985; Standard deviation: 98
const MODEL_0X3B: u64 = 1181;

// Average: 909; Standard deviation: 0
const MODEL_0X3C: u64 = 909;

// Average: 13698; Standard deviation: 1456
const MODEL_0X3D: u64 = 16610;

fn model_0x3e(gas: u64) -> u64 {
    83270 + 430 * gas
}

// No data
const MODEL_0X3F: u64 = DEFAULT_TICKS_PER_GAS;

// No data
const MODEL_0X40: u64 = DEFAULT_TICKS_PER_GAS;

// Average: 2951; Standard deviation: 0
const MODEL_0X41: u64 = 2951;

// Average: 3290; Standard deviation: 0
const MODEL_0X42: u64 = 3290;

// Average: 3274; Standard deviation: 0
const MODEL_0X43: u64 = 3274;

// No data
const MODEL_0X44: u64 = DEFAULT_TICKS_PER_GAS;

// Average: 3407; Standard deviation: 0
const MODEL_0X45: u64 = 3407;

// Average: 13597; Standard deviation: 0
const MODEL_0X46: u64 = 13597;

// Average: 25634; Standard deviation: 295
const MODEL_0X47: u64 = 26224;

// Average: 13600; Standard deviation: 0
const MODEL_0X48: u64 = 13600;

// Average: 2294; Standard deviation: 0
const MODEL_0X50: u64 = 2294;

// Average: 16406; Standard deviation: 4
const MODEL_0X51: u64 = 16414;

fn model_0x52(_: u64) -> u64 {
    70_000
}

fn model_0x53(_: u64) -> u64 {
    70_000
}

// Average: 2180; Standard deviation: 57
const MODEL_0X54: u64 = 2294;

// Manually patched, the model is
// constant in ticks: 567242 in average, 59454 as standard deviation
const MODEL_0X55: u64 = 620_000;

// Average: 1100; Standard deviation: 0
const MODEL_0X56: u64 = 1100;

// Average: 1400; Standard deviation: 36
const MODEL_0X57: u64 = 1472;

// No data
const MODEL_0X58: u64 = DEFAULT_TICKS_PER_GAS;

// Average: 2984; Standard deviation: 0
const MODEL_0X59: u64 = 2984;

// Average: 3564; Standard deviation: 0
const MODEL_0X5A: u64 = 3564;

// Average: 4538; Standard deviation: 0
const MODEL_0X5B: u64 = 4538;

// No data
const MODEL_0X5F: u64 = PUSH_DEFAULT;

// Average: 1871; Standard deviation: 95
const MODEL_0X60: u64 = 2061;

// Average: 1905; Standard deviation: 303
const MODEL_0X61: u64 = 2511;

// Average: 1966; Standard deviation: 521
const MODEL_0X62: u64 = 3008;

// Average: 1974; Standard deviation: 1
const MODEL_0X63: u64 = 1976;

/// PUSH instruction are from 5F to 7F. For those we have no data for,
/// we take the maximum value for the PUSH instruction we have.
const PUSH_DEFAULT: u64 = 2680;

// No data
const MODEL_0X64: u64 = PUSH_DEFAULT;

// No data
const MODEL_0X65: u64 = PUSH_DEFAULT;

// No data
const MODEL_0X66: u64 = PUSH_DEFAULT;

// Average: 1698; Standard deviation: 491
const MODEL_0X67: u64 = 2680;

// No data
const MODEL_0X68: u64 = PUSH_DEFAULT;

// No data
const MODEL_0X69: u64 = PUSH_DEFAULT;

// No data
const MODEL_0X6A: u64 = PUSH_DEFAULT;

// No data
const MODEL_0X6B: u64 = PUSH_DEFAULT;

// No data
const MODEL_0X6C: u64 = PUSH_DEFAULT;

// No data
const MODEL_0X6D: u64 = PUSH_DEFAULT;

// No data
const MODEL_0X6E: u64 = PUSH_DEFAULT;

// No data
const MODEL_0X6F: u64 = PUSH_DEFAULT;

// No data
const MODEL_0X70: u64 = PUSH_DEFAULT;

// No data
const MODEL_0X71: u64 = PUSH_DEFAULT;

// No data
const MODEL_0X72: u64 = PUSH_DEFAULT;

// Average: 1841; Standard deviation: 538
const MODEL_0X73: u64 = 2917;

// No data
const MODEL_0X74: u64 = PUSH_DEFAULT;

// No data
const MODEL_0X75: u64 = PUSH_DEFAULT;

// No data
const MODEL_0X76: u64 = PUSH_DEFAULT;

// No data
const MODEL_0X77: u64 = PUSH_DEFAULT;

// No data
const MODEL_0X78: u64 = PUSH_DEFAULT;

// No data
const MODEL_0X79: u64 = PUSH_DEFAULT;

// No data
const MODEL_0X7A: u64 = PUSH_DEFAULT;

// Average: 1875; Standard deviation: 66
const MODEL_0X7B: u64 = 2007;

// No data
const MODEL_0X7C: u64 = PUSH_DEFAULT;

// No data
const MODEL_0X7D: u64 = PUSH_DEFAULT;

// No data
const MODEL_0X7E: u64 = PUSH_DEFAULT;

// Average: 2391; Standard deviation: 15
const MODEL_0X7F: u64 = 2421;

/// DUP are opcodes 80 to 8f. We use the maximum we have as default value.
const DUP_DEFAULT: u64 = 1500;

// Average: 1871; Standard deviation: 172
const MODEL_0X80: u64 = 2215;

// Average: 1874; Standard deviation: 119
const MODEL_0X81: u64 = 2112;

// Average: 1875; Standard deviation: 85
const MODEL_0X82: u64 = 2045;

// Average: 1876; Standard deviation: 421
const MODEL_0X83: u64 = 2718;

// Average: 1877; Standard deviation: 212
const MODEL_0X84: u64 = 2301;

// Average: 1878; Standard deviation: 51
const MODEL_0X85: u64 = 1980;

// Average: 1879; Standard deviation: 30
const MODEL_0X86: u64 = 1939;

// Average: 1880; Standard deviation: 1
const MODEL_0X87: u64 = 1882;

// Average: 1881; Standard deviation: 1
const MODEL_0X88: u64 = 1883;

// Average: 1882; Standard deviation: 1
const MODEL_0X89: u64 = 1884;

// Average: 1883; Standard deviation: 1
const MODEL_0X8A: u64 = 1885;

// Average: 1884; Standard deviation: 1
const MODEL_0X8B: u64 = 1886;

// Average: 1885; Standard deviation: 1
const MODEL_0X8C: u64 = 1887;

// No data
const MODEL_0X8D: u64 = DUP_DEFAULT;

// No data
const MODEL_0X8E: u64 = DUP_DEFAULT;

// No data
const MODEL_0X8F: u64 = DUP_DEFAULT;

/// SWAP opcodes are 90 to 9f. We use maximum as default value.
const SWAP_DEFAULT: u64 = 1874;

// Average: 1870; Standard deviation: 1
const MODEL_0X90: u64 = 1872;

// Average: 1871; Standard deviation: 1
const MODEL_0X91: u64 = 1873;

// Average: 1872; Standard deviation: 1
const MODEL_0X92: u64 = 1874;

// Average: 1873; Standard deviation: 1
const MODEL_0X93: u64 = 1875;

// Average: 1874; Standard deviation: 1
const MODEL_0X94: u64 = 1876;

// Average: 1875; Standard deviation: 1
const MODEL_0X95: u64 = 1877;

// Average: 1876; Standard deviation: 1
const MODEL_0X96: u64 = 1878;

// Average: 1877; Standard deviation: 1
const MODEL_0X97: u64 = 1879;

// Average: 1878; Standard deviation: 1
const MODEL_0X98: u64 = 1880;

// No data
const MODEL_0X99: u64 = SWAP_DEFAULT;

// No data
const MODEL_0X9A: u64 = SWAP_DEFAULT;

// No data
const MODEL_0X9B: u64 = SWAP_DEFAULT;

// No data
const MODEL_0X9C: u64 = SWAP_DEFAULT;

// No data
const MODEL_0X9D: u64 = SWAP_DEFAULT;

// No data
const MODEL_0X9E: u64 = SWAP_DEFAULT;

// No data
const MODEL_0X9F: u64 = SWAP_DEFAULT;

// No data, approximated from the other logs (a0 to a4)
const MODEL_0XA0: u64 = 200;

fn model_0xa1(gas: u64) -> u64 {
    64879 + 17 * gas
}

fn model_0xa2(gas: u64) -> u64 {
    53681 + 22 * gas
}

fn model_0xa3(gas: u64) -> u64 {
    63497 + 12 * gas
}

fn model_0xa4(gas: u64) -> u64 {
    31313 + 27 * gas
}

fn model_0xf0(gas: u64) -> u64 {
    39 * gas
}

// Average: 214; Standard deviation: 2285
const MODEL_0XF1: u64 = 4784;

// No data, approximated from CALL
const MODEL_0XF2: u64 = 4784;

// Average: 47326; Standard deviation: 545
const MODEL_0XF3: u64 = 48416;

fn model_0xf4(gas: u64) -> u64 {
    1892717 + 43 * gas
}

// Average: 123; Standard deviation: 0
const MODEL_0XF5: u64 = 123;

// Average: 3285; Standard deviation: 2365
const MODEL_0XFA: u64 = 8015;

// Average: 52342; Standard deviation: 0
const MODEL_0XFD: u64 = 52342;

// No data
const MODEL_0XFE: u64 = DEFAULT_TICKS_PER_GAS;

// Average: 93; Standard deviation: 0
const MODEL_0XFF: u64 = 93;

pub fn ticks(opcode: &Opcode, gas: u64) -> u64 {
    match opcode.as_u8() {
        0x0 => MODEL_0X00, // constant, no gas accounted
        0x1 => MODEL_0X01 * gas,
        0x2 => MODEL_0X02 * gas,
        0x3 => MODEL_0X03 * gas,
        0x4 => MODEL_0X04 * gas,
        0x5 => MODEL_0X05 * gas,
        0x6 => MODEL_0X06 * gas,
        0x7 => MODEL_0X07 * gas,
        0x8 => MODEL_0X08 * gas,
        0x9 => MODEL_0X09 * gas,
        0xa => MODEL_0X0A * gas,
        0xb => MODEL_0X0B * gas,
        0x10 => MODEL_0X10 * gas,
        0x11 => MODEL_0X11 * gas,
        0x12 => MODEL_0X12 * gas,
        0x13 => MODEL_0X13 * gas,
        0x14 => MODEL_0X14 * gas,
        0x15 => MODEL_0X15 * gas,
        0x16 => MODEL_0X16 * gas,
        0x17 => MODEL_0X17 * gas,
        0x18 => MODEL_0X18 * gas,
        0x19 => MODEL_0X19 * gas,
        0x1a => MODEL_0X1A * gas,
        0x1b => MODEL_0X1B * gas,
        0x1c => MODEL_0X1C * gas,
        0x1d => MODEL_0X1D * gas,
        0x20 => model_0x20(gas),
        0x30 => MODEL_0X30 * gas,
        0x31 => MODEL_0X31 * gas,
        0x32 => MODEL_0X32 * gas,
        0x33 => MODEL_0X33 * gas,
        0x34 => MODEL_0X34 * gas,
        0x35 => MODEL_0X35 * gas,
        0x36 => MODEL_0X36 * gas,
        0x37 => model_0x37(gas),
        0x38 => MODEL_0X38 * gas,
        0x39 => model_0x39(gas),
        0x3a => MODEL_0X3A * gas,
        0x3b => MODEL_0X3B * gas,
        0x3c => MODEL_0X3C * gas,
        0x3d => MODEL_0X3D * gas,
        0x3e => model_0x3e(gas),
        0x3f => MODEL_0X3F * gas,
        0x40 => MODEL_0X40 * gas,
        0x41 => MODEL_0X41 * gas,
        0x42 => MODEL_0X42 * gas,
        0x43 => MODEL_0X43 * gas,
        0x44 => MODEL_0X44 * gas,
        0x45 => MODEL_0X45 * gas,
        0x46 => MODEL_0X46 * gas,
        0x47 => MODEL_0X47 * gas,
        0x48 => MODEL_0X48 * gas,
        0x50 => MODEL_0X50 * gas,
        0x51 => MODEL_0X51 * gas,
        0x52 => model_0x52(gas),
        0x53 => model_0x53(gas),
        0x54 => MODEL_0X54 * gas,
        0x55 => MODEL_0X55, // Manually patched: the model is constant in ticks
        0x56 => MODEL_0X56 * gas,
        0x57 => MODEL_0X57 * gas,
        0x58 => MODEL_0X58 * gas,
        0x59 => MODEL_0X59 * gas,
        0x5a => MODEL_0X5A * gas,
        0x5b => MODEL_0X5B * gas,
        0x5f => MODEL_0X5F * gas,
        0x60 => MODEL_0X60 * gas,
        0x61 => MODEL_0X61 * gas,
        0x62 => MODEL_0X62 * gas,
        0x63 => MODEL_0X63 * gas,
        0x64 => MODEL_0X64 * gas,
        0x65 => MODEL_0X65 * gas,
        0x66 => MODEL_0X66 * gas,
        0x67 => MODEL_0X67 * gas,
        0x68 => MODEL_0X68 * gas,
        0x69 => MODEL_0X69 * gas,
        0x6a => MODEL_0X6A * gas,
        0x6b => MODEL_0X6B * gas,
        0x6c => MODEL_0X6C * gas,
        0x6d => MODEL_0X6D * gas,
        0x6e => MODEL_0X6E * gas,
        0x6f => MODEL_0X6F * gas,
        0x70 => MODEL_0X70 * gas,
        0x71 => MODEL_0X71 * gas,
        0x72 => MODEL_0X72 * gas,
        0x73 => MODEL_0X73 * gas,
        0x74 => MODEL_0X74 * gas,
        0x75 => MODEL_0X75 * gas,
        0x76 => MODEL_0X76 * gas,
        0x77 => MODEL_0X77 * gas,
        0x78 => MODEL_0X78 * gas,
        0x79 => MODEL_0X79 * gas,
        0x7a => MODEL_0X7A * gas,
        0x7b => MODEL_0X7B * gas,
        0x7c => MODEL_0X7C * gas,
        0x7d => MODEL_0X7D * gas,
        0x7e => MODEL_0X7E * gas,
        0x7f => MODEL_0X7F * gas,
        0x80 => MODEL_0X80 * gas,
        0x81 => MODEL_0X81 * gas,
        0x82 => MODEL_0X82 * gas,
        0x83 => MODEL_0X83 * gas,
        0x84 => MODEL_0X84 * gas,
        0x85 => MODEL_0X85 * gas,
        0x86 => MODEL_0X86 * gas,
        0x87 => MODEL_0X87 * gas,
        0x88 => MODEL_0X88 * gas,
        0x89 => MODEL_0X89 * gas,
        0x8a => MODEL_0X8A * gas,
        0x8b => MODEL_0X8B * gas,
        0x8c => MODEL_0X8C * gas,
        0x8d => MODEL_0X8D * gas,
        0x8e => MODEL_0X8E * gas,
        0x8f => MODEL_0X8F * gas,
        0x90 => MODEL_0X90 * gas,
        0x91 => MODEL_0X91 * gas,
        0x92 => MODEL_0X92 * gas,
        0x93 => MODEL_0X93 * gas,
        0x94 => MODEL_0X94 * gas,
        0x95 => MODEL_0X95 * gas,
        0x96 => MODEL_0X96 * gas,
        0x97 => MODEL_0X97 * gas,
        0x98 => MODEL_0X98 * gas,
        0x99 => MODEL_0X99 * gas,
        0x9a => MODEL_0X9A * gas,
        0x9b => MODEL_0X9B * gas,
        0x9c => MODEL_0X9C * gas,
        0x9d => MODEL_0X9D * gas,
        0x9e => MODEL_0X9E * gas,
        0x9f => MODEL_0X9F * gas,
        0xa0 => MODEL_0XA0 * gas,
        0xa1 => model_0xa1(gas),
        0xa2 => model_0xa2(gas),
        0xa3 => model_0xa3(gas),
        0xa4 => model_0xa4(gas),
        0xf0 => model_0xf0(gas),
        0xf1 => MODEL_0XF1 * gas,
        0xf2 => MODEL_0XF2 * gas,
        0xf3 => MODEL_0XF3, // constant, no gas accounted
        0xf4 => model_0xf4(gas),
        0xf5 => MODEL_0XF5 * gas,
        0xfa => MODEL_0XFA * gas,
        0xfd => MODEL_0XFD, // constant, no gas accounted
        0xfe => MODEL_0XFE * gas,
        0xff => MODEL_0XFF * gas,
        _ => DEFAULT_TICKS_PER_GAS * gas,
    }
}
