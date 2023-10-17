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
 * A version number for the network protocol (includes distributed DB version and p2p version)
 */
#[derive(Default)]
pub struct NetworkVersion {
    pub chainName: Box<NetworkVersion__DistributedDbVersionName>,
    pub distributedDbVersion: u16,
    pub p2pVersion: u16,
}

impl KaitaiStruct for NetworkVersion {
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
        self.chainName = Box::new(NetworkVersion__DistributedDbVersionName::new(self.stream, self, _root)?);
        self.distributedDbVersion = self.stream.read_u2be()?;
        self.p2pVersion = self.stream.read_u2be()?;
    }
}

impl NetworkVersion {

    /*
     * A version number for the distributed DB protocol
     */

    /*
     * A version number for the p2p layer.
     */
}

/*
 * A name for the distributed DB protocol
 */
#[derive(Default)]
pub struct NetworkVersion__DistributedDbVersionName {
    pub lenDistributedDbVersionName: i32,
    pub distributedDbVersionName: Vec<u8>,
}

impl KaitaiStruct for NetworkVersion__DistributedDbVersionName {
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

impl NetworkVersion__DistributedDbVersionName {
}
