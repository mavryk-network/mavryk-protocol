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
 * A name for the distributed DB protocol
 */
#[derive(Default)]
pub struct DistributedDbVersionName {
    pub lenDistributedDbVersionName: i32,
    pub distributedDbVersionName: Vec<u8>,
}

impl KaitaiStruct for DistributedDbVersionName {
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
        self.lenDistributedDbVersionName = self.stream.read_s4be()?;
        self.distributedDbVersionName = self.stream.read_bytes(self.len_distributed_db_version__name)?;
    }
}

impl DistributedDbVersionName {
}
