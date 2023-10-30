// SPDX-FileCopyrightText: 2023 TriliTech <contact@trili.tech>
//
// SPDX-License-Identifier: MIT

/// Elements that may be stored using the Backend
pub trait Elem: Copy + 'static {}

impl<T: Copy + 'static> Elem for T {}

/// Dedicated region in the Backend
pub trait Region<E> {
    const LEN: usize;

    fn read(&self, index: usize) -> E;

    fn read_all(&self) -> Vec<E>;

    fn read_some(&self, index: usize, buffer: &mut [E]);

    fn write(&mut self, index: usize, value: E);

    fn write_all(&mut self, value: &[E]) {
        self.write_some(0, value)
    }

    fn write_some(&mut self, index: usize, buffer: &[E]);
}

/// Region of size 1
pub struct Cell<E: Elem, B: Backend + ?Sized> {
    block: B::Region<E, 1>,
}

impl<E: Elem, B: Backend + ?Sized> Cell<E, B> {
    pub fn read(&self) -> E {
        self.block.read(0)
    }

    pub fn write(&mut self, value: E) {
        self.block.write(0, value)
    }
}

/// State backend
pub trait Backend {
    type Region<E: Elem, const SIZE: usize>: Region<E>;

    /// Allocate a Region of the given size
    fn allocate_region<E: Elem, const SIZE: usize>(&mut self) -> Self::Region<E, SIZE>;

    fn allocate_cell<E: Elem>(&mut self) -> Cell<E, Self> {
        Cell {
            block: self.allocate_region(),
        }
    }
}
