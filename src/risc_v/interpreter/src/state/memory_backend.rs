// SPDX-FileCopyrightText: 2023 TriliTech <contact@trili.tech>
//
// SPDX-License-Identifier: MIT

use super::backend;
use std::{
    mem,
    ops::{Index, IndexMut},
};

#[repr(transparent)]
pub struct MemoryBackendArray<'backend, Elem, const SIZE: usize> {
    backing_storage: &'backend mut [Elem; SIZE],
}

impl<'backend, Elem, const SIZE: usize> Index<usize> for MemoryBackendArray<'backend, Elem, SIZE> {
    type Output = Elem;

    fn index(&self, index: usize) -> &Self::Output {
        self.backing_storage.index(index)
    }
}

impl<'backend, Elem, const SIZE: usize> IndexMut<usize>
    for MemoryBackendArray<'backend, Elem, SIZE>
{
    fn index_mut(&mut self, index: usize) -> &mut Self::Output {
        self.backing_storage.index_mut(index)
    }
}

impl<'backend, Elem: backend::Elem, const SIZE: usize> backend::Region<Elem>
    for MemoryBackendArray<'backend, Elem, SIZE>
{
    const LEN: usize = SIZE;

    fn read(&self, index: usize) -> Elem {
        debug_assert!(index < SIZE);
        self.backing_storage[index]
    }

    fn read_all(&self) -> Vec<Elem> {
        self.backing_storage.to_vec()
    }

    fn read_some(&self, index: usize, buffer: &mut [Elem]) {
        let length = buffer.len();
        debug_assert!(index <= SIZE.saturating_sub(length));
        buffer.copy_from_slice(&self.backing_storage[index..index + length]);
    }

    fn write(&mut self, index: usize, value: Elem) {
        debug_assert!(index < SIZE);
        self.backing_storage[index] = value;
    }

    fn write_all(&mut self, value: &[Elem]) {
        self.backing_storage.copy_from_slice(value)
    }

    fn write_some(&mut self, index: usize, buffer: &[Elem]) {
        let length = buffer.len();
        debug_assert!(index <= SIZE.saturating_sub(length));
        self.backing_storage[index..index + length].copy_from_slice(buffer)
    }
}

pub struct MemoryBackend<'backend, const SIZE: usize> {
    // This reference only exists to keep the lifetimes in order.
    backing_storage: &'backend [u8; SIZE],
    offset: *mut u8,
}

impl<'backend, const SIZE: usize> MemoryBackend<'backend, SIZE> {
    pub fn new(backing_storage: &'backend mut [u8; SIZE]) -> Self {
        let offset = backing_storage.as_mut_ptr();
        Self {
            backing_storage,
            offset,
        }
    }
}

impl<'backend, const TOTAL_SIZE: usize> backend::Backend for MemoryBackend<'backend, TOTAL_SIZE> {
    type Region<Elem: backend::Elem, const SIZE: usize> = MemoryBackendArray<'backend, Elem, SIZE>;

    fn allocate_region<Elem: backend::Elem, const SIZE: usize>(
        &mut self,
    ) -> Self::Region<Elem, SIZE> {
        let size = mem::size_of::<[Elem; SIZE]>();
        let align = mem::align_of::<[Elem; SIZE]>();

        let backing_storage = unsafe {
            let ptr = self.offset.offset(size as isize);
            let add = ptr.align_offset(align);
            let ptr = if add > 0 && add < usize::MAX {
                ptr.offset(add as isize)
            } else if add == usize::MAX {
                panic!("Unable to align pointer to backend storage")
            } else {
                ptr
            };

            if ptr.offset_from(self.backing_storage.as_ptr()) as usize > TOTAL_SIZE {
                panic!("Exhausted memory allocation");
            }

            self.offset = ptr.offset(size as isize);

            &mut *(ptr as *mut [Elem; SIZE])
        };

        MemoryBackendArray { backing_storage }
    }
}
