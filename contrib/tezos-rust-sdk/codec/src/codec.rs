use std::env;

use num_bigint::BigInt;
use num_bigint::BigUint;
use tezos_core::internal::coder::AddressBytesCoder;
use tezos_core::internal::coder::Decoder;
use tezos_core::internal::coder::Encoder;
use tezos_core::internal::coder::IntegerBytesCoder;
use tezos_core::internal::coder::NaturalBytesCoder;
use tezos_core::internal::utils::*;
use tezos_core::types::encoded::Address;
use tezos_core::types::encoded::Encoded;
use tezos_core::types::hex_string::HexString;
use tezos_core::types::number::Int;
use tezos_core::types::number::Nat;
use tezos_core::Error;

fn is_case_contract(args: &Vec<String>) -> bool {
    return args.len() >= 5
        && (args[2] == "005-PsBabyM1.contract"
            || args[2] == "006-PsCARTHA.contract"
            || args[2] == "007-PsDELPH1.contract"
            || args[2] == "008-PtEdo2Zk.contract"
            || args[2] == "009-PsFLoren.contract"
            || args[2] == "010-PtGRANAD.contract"
            || args[2] == "011-PtHangz2.contract"
            || args[2] == "012-Psithaca.contract"
            || args[2] == "013-PtJakart.contract"
            || args[2] == "014-PtKathma.contract"
            || args[2] == "015-PtLimaPt.contract"
            || args[2] == "016-PtMumbai.contract"
            || args[2] == "017-PtNairob.contract"
            || args[2] == "alpha.contract"
            || args[2] == "contract")
        && args[3] == "from";
}

fn decode_contract(args: &Vec<String>) {
    for arg in &args[4..] {
        let hex: Result<HexString, _> = HexString::new(arg.to_string());
        match hex {
            Ok(hex) => {
                let bin_addr: Result<Address, _> =
                    <AddressBytesCoder as Decoder<Address, [u8], Error>>::decode(
                        hex.to_bytes().as_slice(),
                    );
                match bin_addr {
                    Ok(addr) => {
                        println!("\"{}\"", addr.value());
                    }
                    Err(error) => {
                        eprintln!("Error: {}", error);
                    }
                }
            }
            Err(error) => {
                eprintln!("Error: {}", error);
            }
        }
    }
}

fn encode_contract(args: &Vec<String>) {
    for arg in &args[4..] {
        if arg.starts_with('"') && arg.ends_with('"') {
            let addr: Result<Address, _> = Address::try_from((&arg[1..arg.len() - 1]).to_string());
            match addr {
                Ok(addr) => {
                    let hex_addr: Result<Vec<u8>, _> = <Address as Encoded>::to_bytes(&addr);
                    match hex_addr {
                        Ok(addr) => {
                            for byte in &addr {
                                print!("{:02x}", byte);
                            }
                            println!();
                        }
                        Err(error) => {
                            eprintln!("Error: {}", error);
                        }
                    }
                }
                Err(error) => {
                    eprintln!("Error: {}", error);
                }
            }
        } else {
            println!("Error: JSON.of_buffer illegal literal ({})", arg);
        }
    }
}

fn is_case_u16(args: &Vec<String>) -> bool {
    return args.len() >= 5 && args[2] == "ground.uint16" && args[3] == "from";
}
fn is_case_i32(args: &Vec<String>) -> bool {
    return args.len() >= 5 && args[2] == "ground.int32" && args[3] == "from";
}
fn is_case_i64(args: &Vec<String>) -> bool {
    return args.len() >= 5 && args[2] == "ground.int64" && args[3] == "from";
}
fn is_case_n(args: &Vec<String>) -> bool {
    return args.len() >= 5 && args[2] == "ground.N" && args[3] == "from";
}
fn is_case_z(args: &Vec<String>) -> bool {
    return args.len() >= 5 && args[2] == "ground.Z" && args[3] == "from";
}

// unsupported: ground.int31, ground.uint8, ground.int8, ground.i16

fn decode_u16(args: &Vec<String>) {
    for arg in &args[4..] {
        let hex: Result<HexString, _> = HexString::new(arg.to_string());
        match hex {
            Ok(hex) => {
                let bytes: Vec<u8> = hex.to_bytes();
                let i = decode_consuming_u16(
                    &mut tezos_core::internal::consumable_list::ConsumableBytes::new(&bytes),
                );
                match i {
                    Ok(i) => {
                        println!("{}", i);
                    }
                    Err(error) => {
                        eprintln!("Error (cannot decode): {}", error);
                    }
                }
            }
            Err(error) => {
                eprintln!("Error (wrong format): {}", error);
            }
        }
    }
}

fn decode_z(args: &Vec<String>) {
    for arg in &args[4..] {
        let hex: Result<HexString, _> = HexString::new(arg.to_string());
        match hex {
            Ok(hex) => {
                let bytes: Vec<u8> = hex.to_bytes();
                let i: Result<Int, _> = IntegerBytesCoder::decode(&bytes);
                match i {
                    Ok(i) => {
                        println!("\"{}\"", i.to_str());
                    }
                    Err(error) => {
                        eprintln!("Error (cannot decode): {}", error);
                    }
                }
            }
            Err(error) => {
                eprintln!("Error (wrong format): {}", error);
            }
        }
    }
}

fn decode_n(args: &Vec<String>) {
    for arg in &args[4..] {
        let hex: Result<HexString, _> = HexString::new(arg.to_string());
        match hex {
            Ok(hex) => {
                let bytes: Vec<u8> = hex.to_bytes();
                let i: Result<Nat, _> = NaturalBytesCoder::decode(&bytes);
                match i {
                    Ok(i) => {
                        println!("\"{}\"", i.to_str());
                    }
                    Err(error) => {
                        eprintln!("Error (cannot decode): {}", error);
                    }
                }
            }
            Err(error) => {
                eprintln!("Error (wrong format): {}", error);
            }
        }
    }
}

fn decode_i32(args: &Vec<String>) {
    for arg in &args[4..] {
        let hex: Result<HexString, _> = HexString::new(arg.to_string());
        match hex {
            Ok(hex) => {
                let bytes: Vec<u8> = hex.to_bytes();
                let i = decode_consuming_i32(
                    &mut tezos_core::internal::consumable_list::ConsumableBytes::new(&bytes),
                );
                match i {
                    Ok(i) => {
                        println!("{}", i);
                    }
                    Err(error) => {
                        eprintln!("Error (cannot decode): {}", error);
                    }
                }
            }
            Err(error) => {
                eprintln!("Error (wrong format): {}", error);
            }
        }
    }
}

fn decode_i64(args: &Vec<String>) {
    for arg in &args[4..] {
        let hex: Result<HexString, _> = HexString::new(arg.to_string());
        match hex {
            Ok(hex) => {
                let bytes: Vec<u8> = hex.to_bytes();
                let i = decode_consuming_i64(
                    &mut tezos_core::internal::consumable_list::ConsumableBytes::new(&bytes),
                );
                match i {
                    Ok(i) => {
                        println!("\"{}\"", i);
                    }
                    Err(error) => {
                        eprintln!("Error (cannot decode): {}", error);
                    }
                }
            }
            Err(error) => {
                eprintln!("Error (wrong format): {}", error);
            }
        }
    }
}

fn encode_z(args: &Vec<String>) {
    for arg in &args[4..] {
        if arg.len() >= 3 && arg.starts_with('"') && arg.ends_with('"') {
            let arg: String = (&arg[1..arg.len() - 1]).to_string();
            let b: Result<BigInt, _> = arg.parse::<BigInt>();
            match b {
                Ok(i) => {
                    let i: Result<Int, _> = Int::from_string(i.to_string());
                    match i {
                        Ok(i) => {
                            let bytes = IntegerBytesCoder::encode(&i);
                            match bytes {
                                Ok(bytes) => {
                                    let hex_string: String = bytes
                                        .iter()
                                        .map(|byte| format!("{:02x}", byte))
                                        .collect::<String>();
                                    println!("{}", hex_string);
                                }
                                Err(error) => {
                                    eprintln!("Error: {}", error);
                                }
                            }
                        }
                        Err(error) => {
                            eprintln!("Error: {}", error);
                        }
                    }
                }
                Err(error) => {
                    eprintln!("Error: {}", error);
                }
            }
        } else {
            eprintln!("Error: wrong format");
        }
    }
}

fn encode_n(args: &Vec<String>) {
    for arg in &args[4..] {
        if arg.len() >= 3 && arg.starts_with('"') && arg.ends_with('"') {
            let arg: String = (&arg[1..arg.len() - 1]).to_string();
            let b: Result<BigUint, _> = arg.parse::<BigUint>();
            match b {
                Ok(i) => {
                    let i: Result<Nat, _> = Nat::from_string(i.to_string());
                    match i {
                        Ok(i) => {
                            let bytes = NaturalBytesCoder::encode(&i);
                            match bytes {
                                Ok(bytes) => {
                                    let hex_string: String = bytes
                                        .iter()
                                        .map(|byte| format!("{:02x}", byte))
                                        .collect::<String>();
                                    println!("{}", hex_string);
                                }
                                Err(error) => {
                                    eprintln!("Error: {}", error);
                                }
                            }
                        }
                        Err(error) => {
                            eprintln!("Error: {}", error);
                        }
                    }
                }
                Err(error) => {
                    eprintln!("Error: {}", error);
                }
            }
        } else {
            eprintln!("Error: wrong format");
        }
    }
}

fn encode_int32(args: &Vec<String>) {
    for arg in &args[4..] {
        match arg.parse::<i32>() {
            Ok(i) => {
                let bytes = encode_i32(i);
                let hex_string: String = bytes
                    .iter()
                    .map(|byte| format!("{:02x}", byte))
                    .collect::<String>();
                println!("{}", hex_string);
            }
            Err(error) => {
                eprintln!("Error: {}", error);
            }
        }
    }
}

fn encode_int64(args: &Vec<String>) {
    for arg in &args[4..] {
        if arg.len() >= 3 && arg.starts_with('"') && arg.ends_with('"') {
            let arg: String = (&arg[1..arg.len() - 1]).to_string();
            match arg.parse::<i64>() {
                Ok(i) => {
                    let bytes = encode_i64(i);
                    let hex_string: String = bytes
                        .iter()
                        .map(|byte| format!("{:02x}", byte))
                        .collect::<String>();
                    println!("{}", hex_string);
                }
                Err(error) => {
                    eprintln!("Error: {}", error);
                }
            }
        } else {
            println!("Error: not a parsable number");
        }
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();

    // let case_list_encodings : bool = args.len() > 2 && args[1] == "list" && args[2] == "encodings";
    let case_encode = args.len() >= 5 && args[1] == "encode";
    let case_decode = args.len() >= 5 && args[1] == "decode";
    let case_u16 = args.len() >= 5 && is_case_u16(&args);
    let case_i32 = args.len() >= 5 && is_case_i32(&args);
    let case_i64 = args.len() >= 5 && is_case_i64(&args);
    let case_n = args.len() >= 5 && is_case_n(&args);
    let case_z = args.len() >= 5 && is_case_z(&args);
    let case_contract = is_case_contract(&args);

    if case_decode {
        if case_contract {
            decode_contract(&args);
        }
        if case_u16 {
            decode_u16(&args);
        }
        if case_i32 {
            decode_i32(&args);
        }
        if case_i64 {
            decode_i64(&args);
        }
        if case_z {
            decode_z(&args);
        }
        if case_n {
            decode_n(&args);
        }
    }

    if case_encode {
        if case_contract {
            encode_contract(&args);
        }
        if case_i32 {
            encode_int32(&args);
        }
        if case_i64 {
            encode_int64(&args);
        }
        if case_z {
            encode_z(&args);
        }
        if case_n {
            encode_n(&args);
        }
    }
}
