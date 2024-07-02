// SPDX-FileCopyrightText: 2022 TriliTech <contact@trili.tech>
// SPDX-FileCopyrightText: 2022 Nomadic Labs <contact@nomadic-labs.com>
// SPDX-FileCopyrightText: 2023 Marigold <contact@marigold.dev>
//
// SPDX-License-Identifier: MIT

//! Defines mavryk-encoding compatible structures.
//!
//! # Encoding overview
//! Encodings are implemented using [mavryk_data_encoding] crate from [tezedge], of which the
//! most relevant traits are:
//!
//! ## [HasEncoding]
//! Defines a type's encoding schema - which can be used to derive impls for [NomReader]
//! and [BinWriter].
//!
//! Where encoding's are non-derivable, you may need to use:
//!
//! ```rust
//! use mavryk_data_encoding::has_encoding;
//! use mavryk_data_encoding::encoding::{Encoding, HasEncoding};
//!
//! struct Example(String);
//!
//! has_encoding!(Example, EXAMPLE_ENCODING, { Encoding::Custom });
//! ```
//! and provide manual implementations of [NomReader] & [BinWRiter].
//!
//! ## [NomReader]
//! Defines deserialization for a given type.  Built on [nom], which is a
//! parser-combinator library for rust.  Useful combinators for dealing with
//! mavryk-encodings are available in the [mavryk_data_encoding::nom] module.
//!
//! See [nom] for a useful overview of how it's structured.
//!
//! ## [BinWriter]
//! Defines *serialization* for a given type.  The [mavryk_data_encoding::enc] module defines
//! useful combinators for mavryk-encoding compatible serialization.
//!
//! [tezedge]: <https://github.com/tezedge/tezedge>
//! [HasEncoding]: mavryk_data_encoding::encoding::HasEncoding
//! [NomReader]: mavryk_data_encoding::nom::NomReader
//! [BinWriter]: mavryk_data_encoding::enc::BinWriter

pub mod contract;
pub mod entrypoint;
pub mod micheline;
pub mod michelson;
pub mod public_key;
pub mod public_key_hash;
pub mod smart_rollup;
pub mod ticket;
