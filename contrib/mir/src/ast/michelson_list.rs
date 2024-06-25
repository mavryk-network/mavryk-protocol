/******************************************************************************/
/*                                                                            */
/* SPDX-License-Identifier: MIT                                               */
/* Copyright (c) [2023] Serokell <hi@serokell.io>                             */
/*                                                                            */
/******************************************************************************/

//! Representation for typed Michelson `list 'a` values.

/// A representation of a Michelson list.
#[derive(Debug, Clone, Eq, PartialEq)]
pub struct MichelsonList<T>(Vec<T>);

impl<T> MichelsonList<T> {
    /// Construct a new empty list.
    pub fn new() -> Self {
        MichelsonList(Vec::new())
    }

    /// Add an element to the start of the list.
    pub fn cons(&mut self, x: T) {
        self.0.push(x)
    }

    /// Remove an element from the start of the list.
    pub fn uncons(&mut self) -> Option<T> {
        self.0.pop()
    }

    /// Get the list length, i.e. the number of elements.
    #[allow(clippy::len_without_is_empty)]
    pub fn len(&self) -> usize {
        self.0.len()
    }

    /// Construct an iterator over references to the list elements.
    pub fn iter(&self) -> Iter<'_, T> {
        // delegate to `impl IntoIterator for &MichelsonList`
        self.into_iter()
    }

    /// Construct an iterator over mutable references to the list elements.
    pub fn iter_mut(&mut self) -> impl Iterator<Item = &mut T> {
        self.0.iter_mut().rev()
    }
}

impl<T> Default for MichelsonList<T> {
    fn default() -> Self {
        Self::new()
    }
}

/// Owning iterator for [MichelsonList].
pub struct IntoIter<T>(std::iter::Rev<std::vec::IntoIter<T>>);

impl<T> Iterator for IntoIter<T> {
    type Item = T;

    fn next(&mut self) -> Option<Self::Item> {
        self.0.next()
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        self.0.size_hint()
    }
}

impl<T> ExactSizeIterator for IntoIter<T> {}

/// Non-owning iterator for [MichelsonList].
pub struct Iter<'a, T>(std::iter::Rev<core::slice::Iter<'a, T>>);

impl<'a, T> Iterator for Iter<'a, T> {
    type Item = &'a T;

    fn next(&mut self) -> Option<Self::Item> {
        self.0.next()
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        self.0.size_hint()
    }
}

impl<'a, T> ExactSizeIterator for Iter<'a, T> {}

impl<T> IntoIterator for MichelsonList<T> {
    type IntoIter = IntoIter<T>;
    type Item = T;
    fn into_iter(self) -> Self::IntoIter {
        IntoIter(self.0.into_iter().rev())
    }
}

impl<'a, T> IntoIterator for &'a MichelsonList<T> {
    type IntoIter = Iter<'a, T>;
    type Item = &'a T;
    fn into_iter(self) -> Self::IntoIter {
        Iter(self.0.iter().rev())
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
        MichelsonList::from(Vec::from_iter(iter))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cons() {
        let mut lst = MichelsonList::new();
        let expected = vec![1, 2, 3].into();
        lst.cons(3);
        lst.cons(2);
        lst.cons(1);
        assert_eq!(lst, expected);
    }

    #[test]
    fn len() {
        assert_eq!(MichelsonList::from_iter(1..=42).len(), 42);
    }

    #[test]
    fn uncons() {
        let mut lst = MichelsonList::from(vec![1, 2, 3]);
        assert_eq!(lst.uncons(), Some(1));
        assert_eq!(lst.uncons(), Some(2));
        assert_eq!(lst.uncons(), Some(3));
        assert_eq!(lst.uncons(), None);
    }

    #[test]
    fn into_iter() {
        let lst = MichelsonList::from(vec![1, 2, 3]);
        assert_eq!(lst.into_iter().collect::<Vec<_>>(), vec![1, 2, 3]);
    }

    #[test]
    fn from_iter() {
        assert_eq!(MichelsonList::from_iter(1..=3), vec![1, 2, 3].into());
    }

    #[test]
    fn to_vec() {
        assert_eq!(Vec::from(MichelsonList::from(vec![1, 2, 3])), vec![1, 2, 3]);
    }

    #[test]
    fn default() {
        assert_eq!(MichelsonList::default(), MichelsonList::<()>::new());
    }
}
