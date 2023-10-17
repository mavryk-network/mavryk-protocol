// This is a generated file! Please edit source .ksy file and use kaitai-struct-compiler to rebuild

use std::option::Option;
use std::boxed::Box;
use std::io::Result;
use std::io::Cursor;
use std::vec::Vec;
use std::default::Default;
use kaitai_struct::KaitaiStream;
use kaitai_struct::KaitaiStruct;

#[derive(Default)]
pub struct SaplingTransactionPlaintext {
    pub diversifier: Vec<u8>,
    pub amount: i64,
    pub rcm: Vec<u8>,
    pub memo: Box<SaplingTransactionPlaintext__Memo>,
}

impl KaitaiStruct for SaplingTransactionPlaintext {
    fn new<S: KaitaiStream>(stream: &mut S,
                            _parent: &Option<Box<KaitaiStruct>>,
                            _root: &Option<Box<KaitaiStruct>>)
                            -> Result<Self>
        where Self: Sized {
        let mut s: Self = Default::default();

        s.stream = stream;
        s.read(stream, _parent, _root)?;

        Ok(s)
    }


    fn read<S: KaitaiStream>(&mut self,
                             stream: &mut S,
                             _parent: &Option<Box<KaitaiStruct>>,
                             _root: &Option<Box<KaitaiStruct>>)
                             -> Result<()>
        where Self: Sized {
        self.diversifier = self.stream.read_bytes(11)?;
        self.amount = self.stream.read_s8be()?;
        self.rcm = self.stream.read_bytes(32)?;
        self.memo = Box::new(SaplingTransactionPlaintext__Memo::new(self.stream, self, _root)?);
    }
}

impl SaplingTransactionPlaintext {
}
#[derive(Default)]
pub struct SaplingTransactionPlaintext__Memo {
    pub lenMemo: i32,
    pub memo: Vec<u8>,
}

impl KaitaiStruct for SaplingTransactionPlaintext__Memo {
    fn new<S: KaitaiStream>(stream: &mut S,
                            _parent: &Option<Box<KaitaiStruct>>,
                            _root: &Option<Box<KaitaiStruct>>)
                            -> Result<Self>
        where Self: Sized {
        let mut s: Self = Default::default();

        s.stream = stream;
        s.read(stream, _parent, _root)?;

        Ok(s)
    }


    fn read<S: KaitaiStream>(&mut self,
                             stream: &mut S,
                             _parent: &Option<Box<KaitaiStruct>>,
                             _root: &Option<Box<KaitaiStruct>>)
                             -> Result<()>
        where Self: Sized {
        self.lenMemo = self.stream.read_s4be()?;
        self.memo = self.stream.read_bytes(self.len_memo)?;
    }
}

impl SaplingTransactionPlaintext__Memo {
}
