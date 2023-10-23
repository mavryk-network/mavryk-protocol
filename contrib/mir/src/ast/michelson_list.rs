/******************************************************************************/
/*                                                                            */
/* SPDX-License-Identifier: MIT                                               */
/* Copyright (c) [2023] Serokell <hi@serokell.io>                             */
/*                                                                            */
/******************************************************************************/

/// A representation of a Michelson list.
#[derive(Debug, Clone, Eq, PartialEq)]
pub struct MichelsonList<T>(Vec<T>);

impl<T> MichelsonList<T> {
    pub fn new() -> Self {
        MichelsonList(Vec::new())
    }

    pub fn cons(&mut self, x: T) {
        self.0.push(x)
    }

    pub fn uncons(&mut self) -> Option<T> {
        self.0.pop()
    }

    pub fn len(&self) -> usize {
        self.0.len()
    }
}

impl<T> Default for MichelsonList<T> {
    fn default() -> Self {
        Self::new()
    }
}

pub struct IntoIter<T>(std::iter::Rev<std::vec::IntoIter<T>>);

impl<T> Iterator for IntoIter<T> {
    type Item = T;
    fn next(&mut self) -> Option<Self::Item> {
        self.0.next()
    }
}

impl<T> IntoIterator for MichelsonList<T> {
    type IntoIter = IntoIter<T>;
    type Item = T;
    fn into_iter(self) -> Self::IntoIter {
        IntoIter(self.0.into_iter().rev())
    }
}

/// Construct a `MichelsonList<T>` from `Vec<T>`. O(n).
impl<T> From<Vec<T>> for MichelsonList<T> {
    fn from(mut value: Vec<T>) -> Self {
        value.reverse();
        MichelsonList(value)
    }
}

/// Extract a `Vec<T>` from `MichelsonList<T>`. O(n).
impl<T> From<MichelsonList<T>> for Vec<T> {
    fn from(MichelsonList(mut vec): MichelsonList<T>) -> Self {
        vec.reverse();
        vec
    }
}

/// Construct a `MichelsonList<T>` from an iterator. O(n).
impl<T> FromIterator<T> for MichelsonList<T> {
    fn from_iter<I: IntoIterator<Item = T>>(iter: I) -> Self {
        MichelsonList::from(Vec::from_iter(iter.into_iter()))
    }
}
