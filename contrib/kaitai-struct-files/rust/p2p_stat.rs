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
 * Statistics about the p2p network.
 */
#[derive(Default)]
pub struct P2pStat {
    pub totalSent: i64,
    pub totalRecv: i64,
    pub currentInflow: i32,
    pub currentOutflow: i32,
}

impl KaitaiStruct for P2pStat {
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
        self.totalSent = self.stream.read_s8be()?;
        self.totalRecv = self.stream.read_s8be()?;
        self.currentInflow = self.stream.read_s4be()?;
        self.currentOutflow = self.stream.read_s4be()?;
    }
}

impl P2pStat {
}
