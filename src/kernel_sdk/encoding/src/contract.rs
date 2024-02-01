// SPDX-FileCopyrightText: 2023 TriliTech <contact@trili.tech>
//
// SPDX-License-Identifier: MIT

//! Definitions relating to Layer-1 accounts, which the kernel may interact with.

use crypto::base58::{FromBase58Check, FromBase58CheckError};
use crypto::hash::{ContractKt1Hash, Hash, HashTrait, HashType};
use nom::branch::alt;
use nom::bytes::complete::tag;
use nom::combinator::map;
use nom::sequence::delimited;
use nom::sequence::preceded;
use tezos_data_encoding::enc::{self, BinResult, BinWriter};
use tezos_data_encoding::encoding::{Encoding, HasEncoding};
use tezos_data_encoding::has_encoding;
use tezos_data_encoding::nom::{NomReader, NomResult};

use super::public_key_hash::PublicKeyHash;

#[cfg(feature = "testing")]
pub mod testing;

/// Contract id - of either an implicit account or originated account.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Contract {
    /// User account
    Implicit(PublicKeyHash),
    /// Smart contract account
    Originated(ContractKt1Hash),
}

impl Contract {
    /// Converts from a *base58-encoded* string, checking for the prefix.
    pub fn from_b58check(data: &str) -> Result<Self, FromBase58CheckError> {
        let bytes = data.from_base58check()?;
        match bytes {
            _ if bytes.starts_with(HashType::ContractKt1Hash.base58check_prefix()) => {
                Ok(Self::Originated(ContractKt1Hash::from_b58check(data)?))
            }
            _ => Ok(Self::Implicit(PublicKeyHash::from_b58check(data)?)),
        }
    }

    /// Converts to a *base58-encoded* string, including the prefix.
    pub fn to_b58check(&self) -> String {
        match self {
            Self::Implicit(pkh) => pkh.to_b58check(),
            Self::Originated(kt1) => kt1.to_b58check(),
        }
    }
}

impl From<Contract> for Hash {
    fn from(c: Contract) -> Self {
        match c {
            Contract::Implicit(pkh) => pkh.into(),
            Contract::Originated(ckt1) => ckt1.into(),
        }
    }
}

impl TryFrom<String> for Contract {
    type Error = FromBase58CheckError;

    fn try_from(value: String) -> Result<Self, Self::Error> {
        Contract::from_b58check(value.as_str())
    }
}

#[allow(clippy::from_over_into)]
impl Into<String> for Contract {
    fn into(self) -> String {
        self.to_b58check()
    }
}

has_encoding!(Contract, CONTRACT_ENCODING, { Encoding::Custom });

impl NomReader for Contract {
    fn nom_read(input: &[u8]) -> NomResult<Self> {
        alt((
            map(
                preceded(tag([0]), PublicKeyHash::nom_read),
                Contract::Implicit,
            ),
            map(
                delimited(tag([1]), ContractKt1Hash::nom_read, tag([0])),
                Contract::Originated,
            ),
        ))(input)
    }
}

impl BinWriter for Contract {
    fn bin_write(&self, output: &mut Vec<u8>) -> BinResult {
        match self {
            Self::Implicit(implicit) => {
                enc::put_byte(&0, output);
                BinWriter::bin_write(implicit, output)
            }
            Self::Originated(originated) => {
                enc::put_byte(&1, output);
                let mut bytes: Hash = originated.as_ref().to_vec();
                // Originated is padded
                bytes.push(0);
                enc::bytes(&mut bytes, output)?;
                Ok(())
            }
        }
    }
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn mv1_b58check() {
        let mv1 = "mv1E7Ms4p1e3jV2WMehLB3FBFwbV56GiRQfe";

        let pkh = Contract::from_b58check(mv1);

        assert!(matches!(
            pkh,
            Ok(Contract::Implicit(PublicKeyHash::Ed25519(_)))
        ));

        let mv1_from_pkh = pkh.unwrap().to_b58check();

        assert_eq!(mv1, &mv1_from_pkh);
    }

    #[test]
    fn mv2_b58check() {
        let mv2 = "mv2RKxcrsHm8FsDSZdu8aYrNxgBewfvQudq1";

        let pkh = Contract::from_b58check(mv2);

        assert!(matches!(
            pkh,
            Ok(Contract::Implicit(PublicKeyHash::Secp256k1(_)))
        ));

        let mv2_from_pkh = pkh.unwrap().to_b58check();

        assert_eq!(mv2, &mv2_from_pkh);
    }

    #[test]
    fn mv3_b58check() {
        let mv3 = "mv3JVYv3uSuDmxcsfj1fqkusda7qgpcHc1AH";

        let pkh = Contract::from_b58check(mv3);

        assert!(matches!(
            pkh,
            Ok(Contract::Implicit(PublicKeyHash::P256(_)))
        ));

        let mv3_from_pkh = pkh.unwrap().to_b58check();

        assert_eq!(mv3, &mv3_from_pkh);
    }

    #[test]
    fn kt1_b58check() {
        let kt1 = "KT1BuEZtb68c1Q4yjtckcNjGELqWt56Xyesc";

        let pkh = Contract::from_b58check(kt1);

        assert!(matches!(pkh, Ok(Contract::Originated(ContractKt1Hash(_)))));

        let kt1_from_pkh = pkh.unwrap().to_b58check();

        assert_eq!(kt1, &kt1_from_pkh);
    }

    #[test]
    fn mv1_encoding() {
        let mv1 = "mv18Cw7psUrAAPBpXYd9CtCpHg9EgjHP9KTe";

        let contract = Contract::from_b58check(mv1).expect("expected valid mv1 hash");

        let mut bin = Vec::new();
        contract
            .bin_write(&mut bin)
            .expect("serialization should work");

        let deserde_contract = NomReader::nom_read(bin.as_slice())
            .expect("deserialization should work")
            .1;

        check_implicit_serialized(&bin, mv1);

        assert_eq!(contract, deserde_contract);
    }

    #[test]
    fn mv2_encoding() {
        let mv2 = "mv2RH63Aybkv7Gfr87tkZDJRGhvsH3jCmfHP";

        let contract = Contract::from_b58check(mv2).expect("expected valid mv2 hash");

        let mut bin = Vec::new();
        contract
            .bin_write(&mut bin)
            .expect("serialization should work");

        let deserde_contract = NomReader::nom_read(bin.as_slice())
            .expect("deserialization should work")
            .1;

        check_implicit_serialized(&bin, mv2);

        assert_eq!(contract, deserde_contract);
    }

    #[test]
    fn mv3_encoding() {
        let mv3 = "mv3VXV2rMKcSadCBKhp2kAqwfxQXEvFZvg5Z";

        let contract = Contract::from_b58check(mv3).expect("expected valid mv3 hash");

        let mut bin = Vec::new();
        contract
            .bin_write(&mut bin)
            .expect("serialization should work");

        let deserde_contract = NomReader::nom_read(bin.as_slice())
            .expect("deserialization should work")
            .1;

        check_implicit_serialized(&bin, mv3);

        assert_eq!(contract, deserde_contract);
    }

    // Check encoding of originated contracts (aka smart-contract addresses)
    #[test]
    fn contract_encode_originated() {
        let test = "KT1BuEZtb68c1Q4yjtckcNjGELqWt56Xyesc";
        let mut expected = vec![1];
        let mut bytes = Contract::from_b58check(test).unwrap().into();
        expected.append(&mut bytes);
        expected.push(0); // padding

        let contract = Contract::from_b58check(test).unwrap();

        let mut bin = Vec::new();
        contract.bin_write(&mut bin).unwrap();

        assert_eq!(expected, bin);
    }

    // Check decoding of originated contracts (aka smart-contract addresses)
    #[test]
    fn contract_decode_originated() {
        let expected = "KT1BuEZtb68c1Q4yjtckcNjGELqWt56Xyesc";
        let mut test = vec![1];
        let mut bytes = Contract::from_b58check(expected).unwrap().into();
        test.append(&mut bytes);
        test.push(0); // padding

        let expected_contract = Contract::from_b58check(expected).unwrap();

        let (remaining_input, contract) = Contract::nom_read(test.as_slice()).unwrap();

        assert!(remaining_input.is_empty());
        assert_eq!(expected_contract, contract);
    }

    // Check that serialization of implicit PublicKeyHash is binary compatible
    // with protocol encoding of implicit contract ids.
    fn check_implicit_serialized(contract_bytes: &[u8], address: &str) {
        let mut bin_pkh = Vec::new();
        PublicKeyHash::from_b58check(address)
            .expect("expected valid implicit contract")
            .bin_write(&mut bin_pkh)
            .expect("serialization should work");

        assert!(matches!(
            contract_bytes,
            [0_u8, rest @ ..] if rest == bin_pkh));
    }
}
