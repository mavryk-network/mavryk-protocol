// SPDX-FileCopyrightText: 2022-2023 TriliTech <contact@trili.tech>
//
// SPDX-License-Identifier: MIT

//! Hash of Layer1 contract ids.

use std::fmt::Display;
use tezos_data_encoding::enc::BinWriter;
use tezos_data_encoding::encoding::HasEncoding;
use tezos_data_encoding::nom::NomReader;

use crypto::base58::{FromBase58Check, FromBase58CheckError};
use crypto::hash::{
    ContractTz1Hash, ContractTz2Hash, ContractTz3Hash, Hash, HashTrait, HashType,
};

/// Hash of Layer1 contract ids.
#[derive(
    Debug, Clone, PartialEq, Eq, PartialOrd, Ord, HasEncoding, BinWriter, NomReader,
)]
pub enum PublicKeyHash {
    /// Tz1-contract
    Ed25519(ContractTz1Hash),
    /// Tz2-contract
    Secp256k1(ContractTz2Hash),
    /// Tz3-contract
    P256(ContractTz3Hash),
}

impl Display for PublicKeyHash {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Ed25519(mv1) => write!(f, "{}", mv1),
            Self::Secp256k1(mv2) => write!(f, "{}", mv2),
            Self::P256(mv3) => write!(f, "{}", mv3),
        }
    }
}

impl PublicKeyHash {
    /// Conversion from base58-encoding string (with prefix).
    pub fn from_b58check(data: &str) -> Result<Self, FromBase58CheckError> {
        let bytes = data.from_base58check()?;
        match bytes {
            _ if bytes.starts_with(HashType::ContractTz1Hash.base58check_prefix()) => Ok(
                PublicKeyHash::Ed25519(ContractTz1Hash::from_b58check(data)?),
            ),
            _ if bytes.starts_with(HashType::ContractTz2Hash.base58check_prefix()) => Ok(
                PublicKeyHash::Secp256k1(ContractTz2Hash::from_b58check(data)?),
            ),
            _ if bytes.starts_with(HashType::ContractTz3Hash.base58check_prefix()) => {
                Ok(PublicKeyHash::P256(ContractTz3Hash::from_b58check(data)?))
            }
            _ => Err(FromBase58CheckError::InvalidBase58),
        }
    }

    /// Conversion to base58-encoding string (with prefix).
    pub fn to_b58check(&self) -> String {
        match self {
            Self::Ed25519(mv1) => mv1.to_b58check(),
            Self::Secp256k1(mv2) => mv2.to_b58check(),
            Self::P256(mv3) => mv3.to_b58check(),
        }
    }
}

impl From<PublicKeyHash> for Hash {
    fn from(pkh: PublicKeyHash) -> Self {
        match pkh {
            PublicKeyHash::Ed25519(mv1) => mv1.into(),
            PublicKeyHash::Secp256k1(mv2) => mv2.into(),
            PublicKeyHash::P256(mv3) => mv3.into(),
        }
    }
}

impl TryFrom<&str> for PublicKeyHash {
    type Error = FromBase58CheckError;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        Self::from_b58check(value)
    }
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn mv1_b58check() {
        let mv1 = "mv1E7Ms4p1e3jV2WMehLB3FBFwbV56GiRQfe";

        let pkh = PublicKeyHash::from_b58check(mv1);

        assert!(matches!(pkh, Ok(PublicKeyHash::Ed25519(_))));

        let mv1_from_pkh = pkh.unwrap().to_b58check();

        assert_eq!(mv1, &mv1_from_pkh);
    }

    #[test]
    fn mv2_b58check() {
        let mv2 = "mv2RKxcrsHm8FsDSZdu8aYrNxgBewfvQudq1";

        let pkh = PublicKeyHash::from_b58check(mv2);

        assert!(matches!(pkh, Ok(PublicKeyHash::Secp256k1(_))));

        let mv2_from_pkh = pkh.unwrap().to_b58check();

        assert_eq!(mv2, &mv2_from_pkh);
    }

    #[test]
    fn mv3_b58check() {
        let mv3 = "mv3JVYv3uSuDmxcsfj1fqkusda7qgpcHc1AH";

        let pkh = PublicKeyHash::from_b58check(mv3);

        assert!(matches!(pkh, Ok(PublicKeyHash::P256(_))));

        let mv3_from_pkh = pkh.unwrap().to_b58check();

        assert_eq!(mv3, &mv3_from_pkh);
    }

    #[test]
    fn mv1_encoding() {
        let mv1 = "mv18Cw7psUrAAPBpXYd9CtCpHg9EgjHP9KTe";

        let pkh = PublicKeyHash::from_b58check(mv1).expect("expected valid mv1 hash");

        let mut bin = Vec::new();
        pkh.bin_write(&mut bin).expect("serialization should work");

        let deserde_pkh = NomReader::nom_read(bin.as_slice())
            .expect("deserialization should work")
            .1;

        // Check tag encoding
        assert_eq!(0_u8, bin[0]);
        assert_eq!(pkh, deserde_pkh);
    }

    #[test]
    fn mv2_encoding() {
        let mv2 = "mv2MTWSzQoL2ucdFANV8XCBZAFAehYNc4DW1";

        let pkh = PublicKeyHash::from_b58check(mv2).expect("expected valid mv2 hash");

        let mut bin = Vec::new();
        pkh.bin_write(&mut bin).expect("serialization should work");

        let deserde_pkh = NomReader::nom_read(bin.as_slice())
            .expect("deserialization should work")
            .1;

        // Check tag encoding
        assert_eq!(1_u8, bin[0]);
        assert_eq!(pkh, deserde_pkh);
    }

    #[test]
    fn mv3_encoding() {
        let mv3 = "mv3Frb3YzAR5bzFNCwaPY4Np42dYwiRZu5iH";

        let pkh = PublicKeyHash::from_b58check(mv3).expect("expected valid mv3 hash");

        let mut bin = Vec::new();
        pkh.bin_write(&mut bin).expect("serialization should work");

        let deserde_pkh = NomReader::nom_read(bin.as_slice())
            .expect("deserialization should work")
            .1;

        // Check tag encoding
        assert_eq!(2_u8, bin[0]);
        assert_eq!(pkh, deserde_pkh);
    }
}
