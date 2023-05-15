use serde::{Deserialize, Serialize};
use tezos_crypto_rs::hash::{PublicKeyEd25519, PublicKeyP256, PublicKeySecp256k1};

#[derive(PartialEq, Debug, Clone, Deserialize, Serialize)]
pub enum PublicKey {
    Ed25519(PublicKeyEd25519),
    P256(PublicKeyP256),
    Secp256k1(PublicKeySecp256k1),
}
