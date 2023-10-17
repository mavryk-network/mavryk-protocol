// This is a generated file! Please edit source .ksy file and use kaitai-struct-compiler to rebuild

use std::option::Option;
use std::boxed::Box;
use std::io::Result;
use std::io::Cursor;
use std::vec::Vec;
use std::default::Default;
use kaitai_struct::KaitaiStream;
use kaitai_struct::KaitaiStruct;


/*
 * Input of a transaction
 */
#[derive(Default)]
pub struct SaplingTransactionInput {
    pub cv: Vec<u8>,
    pub nf: Vec<u8>,
    pub rk: Vec<u8>,
    pub proofI: Vec<u8>,
    pub signature: Vec<u8>,
}

impl KaitaiStruct for SaplingTransactionInput {
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
        self.cv = self.stream.read_bytes(32)?;
        self.nf = self.stream.read_bytes(32)?;
        self.rk = self.stream.read_bytes(32)?;
        self.proofI = self.stream.read_bytes(192)?;
        self.signature = self.stream.read_bytes(64)?;
    }
}

impl SaplingTransactionInput {
}
