use serde::{Deserialize, Serialize};
use tezos_crypto_rs::{
    hash::{PublicKeyEd25519, PublicKeyP256, PublicKeySecp256k1, Signature},
    CryptoError, PublicKeySignatureVerifier,
};

#[derive(PartialEq, Debug, Clone, Deserialize, Serialize)]
pub enum PublicKey {
    Ed25519(PublicKeyEd25519),
    P256(PublicKeyP256),
    Secp256k1(PublicKeySecp256k1),
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
            PublicKey::P256(p256) => p256.verify_signature(signature, msg),
            PublicKey::Secp256k1(secp256k1) => secp256k1.verify_signature(signature, msg),
        }
    }
}
