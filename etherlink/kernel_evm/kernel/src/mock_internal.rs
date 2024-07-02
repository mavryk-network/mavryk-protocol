// SPDX-FileCopyrightText: 2023 Nomadic Labs <contact@nomadic-labs.com>
//
// SPDX-License-Identifier: MIT

use crate::internal_storage::InternalRuntime;
use mavryk_smart_rollup_host::path::Path;
use mavryk_smart_rollup_host::runtime::RuntimeError;
use sha3::{Digest, Keccak256};
pub struct MockInternal();
impl InternalRuntime for MockInternal {
    fn __internal_store_get_hash<T: Path>(
        &mut self,
        path: &T,
    ) -> Result<Vec<u8>, RuntimeError> {
        let hash: [u8; 32] = Keccak256::digest(path.as_bytes()).into();
        Ok(hash.into())
    }
}
