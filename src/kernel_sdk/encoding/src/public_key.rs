// SPDX-FileCopyrightText: 2023 Marigold <contact@marigold.dev>
//
// SPDX-License-Identifier: MIT

//! Public Key of Layer1.

use mavryk_crypto_rs::hash::{
    PublicKeyEd25519, PublicKeyP256, PublicKeySecp256k1, Signature,
};
use mavryk_crypto_rs::{CryptoError, PublicKeySignatureVerifier};
use mavryk_data_encoding::enc::BinWriter;
use mavryk_data_encoding::encoding::HasEncoding;
use mavryk_data_encoding::nom::NomReader;
use std::fmt::Display;

use crypto::base58::{FromBase58Check, FromBase58CheckError};
use crypto::hash::{Hash, HashTrait, HashType};

/// Public Key of Layer1.
#[derive(Debug, Clone, PartialEq, Eq, HasEncoding, BinWriter, NomReader)]
pub enum PublicKey {
    /// Mv1 - public key
    Ed25519(PublicKeyEd25519),
    /// Mv2 - public key
    Secp256k1(PublicKeySecp256k1),
    /// Mv3 - public key
    P256(PublicKeyP256),
}

impl Display for PublicKey {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Ed25519(mv1) => write!(f, "{}", mv1),
            Self::Secp256k1(mv2) => write!(f, "{}", mv2),
            Self::P256(mv3) => write!(f, "{}", mv3),
        }
    }
}

impl PublicKey {
    /// Conversion from base58-encoding string (with prefix).
    pub fn from_b58check(data: &str) -> Result<Self, FromBase58CheckError> {
        let bytes = data.from_base58check()?;
        let public_key = if bytes
            .starts_with(HashType::PublicKeyEd25519.base58check_prefix())
        {
            PublicKey::Ed25519(PublicKeyEd25519::from_b58check(data)?)
        } else if bytes.starts_with(HashType::PublicKeySecp256k1.base58check_prefix()) {
            PublicKey::Secp256k1(PublicKeySecp256k1::from_b58check(data)?)
        } else if bytes.starts_with(HashType::PublicKeyP256.base58check_prefix()) {
            PublicKey::P256(PublicKeyP256::from_b58check(data)?)
        } else {
            return Err(FromBase58CheckError::InvalidBase58);
        };
        Ok(public_key)
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

impl From<PublicKey> for Hash {
    fn from(pkh: PublicKey) -> Self {
        match pkh {
            PublicKey::Ed25519(mv1) => mv1.into(),
            PublicKey::Secp256k1(mv2) => mv2.into(),
            PublicKey::P256(mv3) => mv3.into(),
        }
    }
}

impl TryFrom<&str> for PublicKey {
    type Error = FromBase58CheckError;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        Self::from_b58check(value)
    }
}

impl PublicKeySignatureVerifier for PublicKey {
    type Signature = Signature;
    type Error = CryptoError;

    fn verify_signature(
        &self,
        signature: &Self::Signature,
        msg: &[u8],
    ) -> Result<bool, Self::Error> {
        match self {
            PublicKey::Ed25519(ed25519) => ed25519.verify_signature(signature, msg),
            PublicKey::Secp256k1(secp256k1) => secp256k1.verify_signature(signature, msg),
            PublicKey::P256(p256) => p256.verify_signature(signature, msg),
        }
    }
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn mv1_b58check() {
        let mv1 = "edpkuDMUm7Y53wp4gxeLBXuiAhXZrLn8XB1R83ksvvesH8Lp8bmCfK";

        let pkh = PublicKey::from_b58check(mv1);

        assert!(matches!(pkh, Ok(PublicKey::Ed25519(_))));

        let mv1_from_pkh = pkh.unwrap().to_b58check();

        assert_eq!(mv1, &mv1_from_pkh);
    }

    #[test]
    fn mv2_b58check() {
        let mv2 = "sppk7Zik17H7AxECMggqD1FyXUQdrGRFtz9X7aR8W2BhaJoWwSnPEGA";

        let public_key = PublicKey::from_b58check(mv2);

        assert!(matches!(public_key, Ok(PublicKey::Secp256k1(_))));

        let mv2_from_pk = public_key.unwrap().to_b58check();

        assert_eq!(mv2, &mv2_from_pk);
    }

    #[test]
    fn mv3_b58check() {
        let mv3 = "p2pk67VpBjWwoPULwXCpayec6rFxaAKv8VjJ8cVMHmLDCYARu31zx5Z";

        let public_key = PublicKey::from_b58check(mv3);

        assert!(matches!(public_key, Ok(PublicKey::P256(_))));

        let mv3_from_pk = public_key.unwrap().to_b58check();

        assert_eq!(mv3, &mv3_from_pk);
    }

    #[test]
    fn mv1_encoding() {
        let mv1 = "edpkuDMUm7Y53wp4gxeLBXuiAhXZrLn8XB1R83ksvvesH8Lp8bmCfK";

        let public_key = PublicKey::from_b58check(mv1).expect("expected valid mv1 hash");

        let mut bin = Vec::new();
        public_key
            .bin_write(&mut bin)
            .expect("serialization should work");

        let deserde_pk = NomReader::nom_read(bin.as_slice())
            .expect("deserialization should work")
            .1;

        // Check tag encoding
        assert_eq!(0_u8, bin[0]);
        assert_eq!(public_key, deserde_pk);
    }

    #[test]
    fn mv2_encoding() {
        let mv2 = "sppk7Zik17H7AxECMggqD1FyXUQdrGRFtz9X7aR8W2BhaJoWwSnPEGA";

        let public_key = PublicKey::from_b58check(mv2).expect("expected valid mv2 hash");

        let mut bin = Vec::new();
        public_key
            .bin_write(&mut bin)
            .expect("serialization should work");

        let deserde_pk = NomReader::nom_read(bin.as_slice())
            .expect("deserialization should work")
            .1;

        // Check tag encoding
        assert_eq!(1_u8, bin[0]);
        assert_eq!(public_key, deserde_pk);
    }

    #[test]
    fn mv3_encoding() {
        let mv3 = "p2pk67VpBjWwoPULwXCpayec6rFxaAKv8VjJ8cVMHmLDCYARu31zx5Z";

        let public_key = PublicKey::from_b58check(mv3).expect("expected valid mv3 hash");

        let mut bin = Vec::new();
        public_key
            .bin_write(&mut bin)
            .expect("serialization should work");

        let deserde_pk = NomReader::nom_read(bin.as_slice())
            .expect("deserialization should work")
            .1;

        // Check tag encoding
        assert_eq!(2_u8, bin[0]);
        assert_eq!(public_key, deserde_pk);
    }

    #[test]
    fn mv1_signature_signature_verification_succeeds() {
        let mv1 = PublicKey::from_b58check(
            "edpkvWR5truf7AMF3PZVCXx7ieQLCW4MpNDzM3VwPfmFWVbBZwswBw",
        )
        .expect("public key decoding should work");
        let sig: Signature = Signature::from_base58_check(
            "sigdGBG68q2vskMuac4AzyNb1xCJTfuU8MiMbQtmZLUCYydYrtTd5Lessn1EFLTDJzjXoYxRasZxXbx6tHnirbEJtikcMHt3"
        ).expect("signature decoding should work");
        let msg = hex::decode(
            "bcbb7b77cb0712e4cd02160308cfd53e8dde8a7980c4ff28b62deb12304913c2",
        )
        .expect("payload decoding should work");

        let result = mv1
            .verify_signature(&sig, &msg)
            .expect("signature should be correct");
        assert!(result);
    }

    #[test]
    fn mv1_signature_signature_verification_fails() {
        let mv1 = PublicKey::from_b58check(
            "edpkuDMUm7Y53wp4gxeLBXuiAhXZrLn8XB1R83ksvvesH8Lp8bmCfK",
        )
        .expect("public key decoding should work");
        let sig = Signature::from_base58_check(
            "sigdGBG68q2vskMuac4AzyNb1xCJTfuU8MiMbQtmZLUCYydYrtTd5Lessn1EFLTDJzjXoYxRasZxXbx6tHnirbEJtikcMHt3"
        ).expect("signature decoding should work");
        let msg = hex::decode(
            "bcbb7b77cb0712e4cd02160308cfd53e8dde8a7980c4ff28b62deb12304913c2",
        )
        .expect("payload decoding should work");

        let result = mv1.verify_signature(&sig, &msg);
        assert!(result.is_err());
    }

    #[test]
    fn mv2_signature_signature_verification_succeeds() {
        let mv2 = PublicKey::from_b58check(
            "sppk7cwkTzCPptCSxSTvGNg4uqVcuTbyWooLnJp4yxJNH5DReUGxYvs",
        )
        .expect("public key decoding should work");
        let sig = Signature::from_base58_check("sigrJ2jqanLupARzKGvzWgL1Lv6NGUqDovHKQg9MX4PtNtHXgcvG6131MRVzujJEXfvgbuRtfdGbXTFaYJJjuUVLNNZTf5q1").expect("signature decoding should work");
        let msg = hex::decode(
            "5538e2cc90c9b053a12e2d2f3a985aff1809eac59501db4d644e4bb381b06b4b",
        )
        .expect("payload decoding should work");

        let result = mv2.verify_signature(&sig, &msg).unwrap();
        assert!(result);
    }

    #[test]
    fn mv2_signature_signature_verification_fails() {
        let mv2 = "sppk7Zik17H7AxECMggqD1FyXUQdrGRFtz9X7aR8W2BhaJoWwSnPEGA";
        let mv2 = PublicKey::from_b58check(mv2).expect("parsing should world");
        let sig = Signature::from_base58_check("sigrJ2jqanLupARzKGvzWgL1Lv6NGUqDovHKQg9MX4PtNtHXgcvG6131MRVzujJEXfvgbuRtfdGbXTFaYJJjuUVLNNZTf5q1").expect("signature decoding should work");
        let msg = hex::decode(
            "5538e2cc90c9b053a12e2d2f3a985aff1809eac59501db4d644e4bb381b06b4b",
        )
        .expect("payload decoding should work");

        let result = mv2.verify_signature(&sig, &msg).unwrap();
        assert!(!result);
    }

    #[test]
    fn mv3_signature_signature_verification_succeeds() {
        let mv3 = PublicKey::from_b58check(
            "p2pk67Cwb5Ke6oSmqeUbJxURXMe3coVnH9tqPiB2xD84CYhHbBKs4oM",
        )
        .expect("decoding public key should work");
        let sig = Signature::from_base58_check(
            "sigNCaj9CnmD94eZH9C7aPPqBbVCJF72fYmCFAXqEbWfqE633WNFWYQJFnDUFgRUQXR8fQ5tKSfJeTe6UAi75eTzzQf7AEc1"
        ).expect("signature decoding should work");
        let msg = hex::decode(
            "5538e2cc90c9b053a12e2d2f3a985aff1809eac59501db4d644e4bb381b06b4b",
        )
        .expect("payload decoding should work");

        let result = mv3.verify_signature(&sig, &msg).unwrap();
        assert!(result);
    }

    #[test]
    fn mv3_signature_signature_verification_fails() {
        let mv3 = PublicKey::from_b58check(
            "p2pk67VpBjWwoPULwXCpayec6rFxaAKv8VjJ8cVMHmLDCYARu31zx5Z",
        )
        .expect("decoding public key should work");
        let sig = Signature::from_base58_check(
            "sigNCaj9CnmD94eZH9C7aPPqBbVCJF72fYmCFAXqEbWfqE633WNFWYQJFnDUFgRUQXR8fQ5tKSfJeTe6UAi75eTzzQf7AEc1"
        ).expect("signature decoding should work");
        let msg = hex::decode(
            "5538e2cc90c9b053a12e2d2f3a985aff1809eac59501db4d644e4bb381b06b4b",
        )
        .expect("payload decoding should work");

        let result = mv3.verify_signature(&sig, &msg).unwrap();
        assert!(!result);
    }
}
