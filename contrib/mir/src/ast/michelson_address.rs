/******************************************************************************/
/*                                                                            */
/* SPDX-License-Identifier: MIT                                               */
/* Copyright (c) [2023] Serokell <hi@serokell.io>                             */
/*                                                                            */
/******************************************************************************/

use std::str::Utf8Error;

use tezos_crypto_rs::base58::FromBase58CheckError;
use tezos_crypto_rs::hash::{
    ContractKt1Hash, ContractTz1Hash, ContractTz2Hash, ContractTz3Hash, ContractTz4Hash,
    FromBytesError, HashTrait, SmartRollupHash,
};

#[derive(Debug, PartialEq, Eq, thiserror::Error)]
pub enum AddressError {
    #[error("unknown address prefix: {0}")]
    UnknownStrPrefix(String),
    #[error("unknown address prefix: {0:?}")]
    UnknownBytesPrefix(Vec<u8>),
    #[error("too short to be an address with length {0}")]
    TooShort(usize),
    #[error(transparent)]
    FromBase58CheckError(#[from] FromBase58CheckErrorEq),
    #[error(transparent)]
    FromBytesError(#[from] FromBytesErrorEq),
    #[error(transparent)]
    FromUtf8Error(#[from] Utf8Error),
    #[error("invalid separator byte: {0}")]
    InvalidSeparatorByte(u8),
}

macro_rules! derive_eq_hack {
    ($old:ident, $new:ident) => {
        /// A hack to define `Eq` impl
        #[derive(Debug, thiserror::Error)]
        #[error(transparent)]
        pub struct $new(#[from] pub $old);

        impl PartialEq for $new {
            fn eq(&self, other: &Self) -> bool {
                // this is silly, but PartialEq isn't implemented for tezos_crypto_rs
                // errors for some reason, and coherence rules forbid us from
                // implementing those here. to avoid a terrifyingly long and brittle
                // match expression, especially considering some errors are entirely
                // opaque, we're comparing stringified representations.
                self.to_string() == other.to_string()
            }
        }

        impl Eq for $new {}

        impl From<$old> for AddressError {
            fn from(value: $old) -> Self {
                $new(value).into()
            }
        }
    };
}

derive_eq_hack!(FromBase58CheckError, FromBase58CheckErrorEq);
derive_eq_hack!(FromBytesError, FromBytesErrorEq);

macro_rules! address_hash_type_and_impls {
    ($($con:ident($ty:ident)),* $(,)*) => {
        #[derive(Debug, Clone, Eq, PartialOrd, Ord, PartialEq)]
        pub enum AddressHash {
            $($con($ty)),*
        }

        $(impl From<$ty> for AddressHash {
            fn from(value: $ty) -> Self {
                AddressHash::$con(value)
            }
        })*

        impl AsRef<[u8]> for AddressHash {
            fn as_ref(&self) -> &[u8] {
                match self {
                    $(AddressHash::$con($ty(h)))|* => h,
                }
            }
        }

        impl From<AddressHash> for Vec<u8> {
            fn from(value: AddressHash) -> Self {
                match value {
                    $(AddressHash::$con($ty(h)))|* => h,
                }
            }
        }

        impl TryFrom<&[u8]> for AddressHash {
            type Error = AddressError;
            fn try_from(value: &[u8]) -> Result<Self, Self::Error>{
                Self::from_bytes(value)
            }
        }

        impl TryFrom<&str> for AddressHash {
            type Error = AddressError;
            fn try_from(value: &str) -> Result<Self, Self::Error>{
                Self::from_base58_check(value)
            }
        }

        impl AddressHash {
            pub fn to_base58_check(&self) -> String {
                match self {
                    $(AddressHash::$con(h) => h.to_base58_check()),*
                }
            }
        }
    };
}

address_hash_type_and_impls! {
    Tz1(ContractTz1Hash),
    Tz2(ContractTz2Hash),
    Tz3(ContractTz3Hash),
    Tz4(ContractTz4Hash),
    Kt1(ContractKt1Hash),
    Sr1(SmartRollupHash),
}

impl AddressHash {
    pub fn from_base58_check(data: &str) -> Result<Self, AddressError> {
        use AddressHash::*;
        if data.len() < 3 {
            return Err(AddressError::TooShort(data.len()));
        }
        Ok(match &data[0..3] {
            "KT1" => Kt1(HashTrait::from_b58check(data)?),
            "sr1" => Sr1(HashTrait::from_b58check(data)?),
            "tz1" => Tz1(HashTrait::from_b58check(data)?),
            "tz2" => Tz2(HashTrait::from_b58check(data)?),
            "tz3" => Tz3(HashTrait::from_b58check(data)?),
            "tz4" => Tz4(HashTrait::from_b58check(data)?),
            s => return Err(AddressError::UnknownStrPrefix(s.to_owned())),
        })
    }

    pub fn from_bytes(bytes: &[u8]) -> Result<Self, AddressError> {
        use AddressHash::*;
        let too_short_err = || AddressError::TooShort(bytes.len());
        let validate_separator_byte = || {
            match bytes.last() {
                Some(0) => Ok(()),
                Some(b) => Err(AddressError::InvalidSeparatorByte(*b)),
                // should be impossible to hit
                None => Err(AddressError::TooShort(0)),
            }
        };
        Ok(match bytes.first().ok_or_else(too_short_err)? {
            // implicit addresses
            0 => match bytes.get(1).ok_or_else(too_short_err)? {
                0 => Tz1(HashTrait::try_from_bytes(&bytes[2..])?),
                1 => Tz2(HashTrait::try_from_bytes(&bytes[2..])?),
                2 => Tz3(HashTrait::try_from_bytes(&bytes[2..])?),
                3 => Tz4(HashTrait::try_from_bytes(&bytes[2..])?),
                _ => return Err(AddressError::UnknownBytesPrefix(bytes[..2].to_vec())),
            },
            1 => {
                validate_separator_byte()?;
                Kt1(HashTrait::try_from_bytes(&bytes[1..bytes.len() - 1])?)
            }
            // 2 is txr1 addresses, which are deprecated
            3 => {
                validate_separator_byte()?;
                Sr1(HashTrait::try_from_bytes(&bytes[1..bytes.len() - 1])?)
            }
            _ => return Err(AddressError::UnknownBytesPrefix(bytes[..1].to_vec())),
        })
    }
}

#[derive(Debug, Clone, Eq, PartialOrd, Ord, PartialEq)]
pub struct Address {
    pub hash: AddressHash,
    pub entrypoint: String,
}

impl Address {
    pub fn from_base58_check(data: &str) -> Result<Self, AddressError> {
        let (hash, ep) = if let Some(ep_sep_pos) = data.find('%') {
            (&data[..ep_sep_pos], Some(&data[ep_sep_pos + 1..]))
        } else {
            (data, None)
        };
        Ok(Address {
            hash: AddressHash::from_base58_check(hash)?,
            entrypoint: ep.unwrap_or("default").to_owned(),
        })
    }

    pub fn from_bytes(bytes: &[u8]) -> Result<Self, AddressError> {
        // all address hashes are 20 bytes in length
        const HASH_SIZE: usize = 20;
        // +2 for tags: implicit addresses use 2-byte, and KT1/sr1 add a
        // zero-byte separator to the end
        const EP_START: usize = HASH_SIZE + 2;

        if bytes.len() < EP_START {
            return Err(AddressError::TooShort(bytes.len()));
        }

        let (hash, ep) = bytes.split_at(EP_START);
        let ep = if ep.is_empty() {
            "default"
        } else {
            std::str::from_utf8(ep)?
        };
        Ok(Address {
            hash: AddressHash::from_bytes(hash)?,
            entrypoint: ep.to_owned(),
        })
    }
}

impl TryFrom<&[u8]> for Address {
    type Error = AddressError;
    fn try_from(value: &[u8]) -> Result<Self, Self::Error> {
        Self::from_bytes(value)
    }
}

impl TryFrom<&str> for Address {
    type Error = AddressError;
    fn try_from(value: &str) -> Result<Self, Self::Error> {
        Self::from_base58_check(value)
    }
}
