// SPDX-FileCopyrightText: 2023 TriliTech <contact@trili.tech>
//
// SPDX-License-Identifier: MIT

mod backend;
mod memory_backend;

use self::backend::{Backend, Region};

#[repr(usize)]
#[derive(PartialEq, Eq, PartialOrd, Ord)]
pub enum XRegister {
    X0 = 0,
    X1,
    X2,
    X3,
    X4,
    X5,
    X6,
    X7,
    X8,
    X9,
    X10,
    X11,
    X12,
    X13,
    X14,
    X15,
    X16,
    X17,
    X18,
    X19,
    X20,
    X21,
    X22,
    X23,
    X24,
    X25,
    X26,
    X27,
    X28,
    X29,
    X30,
    X31,
}

pub struct XRegisters<BackendImpl: Backend> {
    pub registers: BackendImpl::Region<u64, 32>,
}

impl<BackendImpl: Backend> XRegisters<BackendImpl> {
    pub fn new(backend: &mut BackendImpl) -> Self {
        let registers = backend.allocate_region();
        Self { registers }
    }

    pub fn read(&self, reg: XRegister) -> u64 {
        if let XRegister::X0 = reg {
            0
        } else {
            self.registers.read(reg as usize)
        }
    }
}

pub struct Hart<BackendImpl: Backend> {
    pub xregisters: XRegisters<BackendImpl>,
}

impl<BackendImpl: Backend> Hart<BackendImpl> {}

#[cfg(test)]
mod tests {
    use super::backend::{Backend, Region};
    use super::memory_backend::MemoryBackend;

    fn test_overlap<B: Backend>(backend: &mut B) {
        const LEN: usize = 64;

        // Allocate two consecutive arrays
        let mut array1 = backend.allocate_region::<u64, LEN>();
        let mut array1_mirror = [0; LEN];
        let mut array2 = backend.allocate_region::<u64, LEN>();

        for i in 0..LEN {
            // Ensure the array is zero-initialised.
            assert_eq!(array1.read(i), 0);

            // Then write something random in it.
            let value = rand::random();
            array1.write(i, value);
            assert_eq!(array1.read(i), value);

            // Retain the value for later.
            array1_mirror[i] = value;
        }

        let array1_vec = array1.read_all();
        assert_eq!(array1_vec, array1_mirror);

        for i in 0..LEN {
            // Check the array is zero-initialised and that the first array
            // did not mess with the second array.
            assert_eq!(array2.read(i), 0);

            // Write a random value to it.
            let value = rand::random();
            array2.write(i, value);
            assert_eq!(array2.read(i), value);
        }

        for i in 0..LEN {
            // Ensure that writing to the second array didn't mess with the
            // first array.
            assert_eq!(array1_mirror[i], array1.read(i));
        }
    }

    fn test_backend<B: Backend>(backend: &mut B) {
        test_overlap(backend);
    }

    #[test]
    fn test_all_backend() {
        const LEN: usize = 10000;
        let mut backing_storage = vec![0u8; LEN];
        let mut backend =
            MemoryBackend::new(unsafe { &mut *(backing_storage.as_mut_ptr() as *mut [u8; LEN]) });
        test_backend(&mut backend);
    }
}
