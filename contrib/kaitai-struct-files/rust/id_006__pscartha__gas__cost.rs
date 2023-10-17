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
pub struct Id006PscarthaGasCost {
    pub allocations: Box<Id006PscarthaGasCost__Z>,
    pub steps: Box<Id006PscarthaGasCost__Z>,
    pub reads: Box<Id006PscarthaGasCost__Z>,
    pub writes: Box<Id006PscarthaGasCost__Z>,
    pub bytesRead: Box<Id006PscarthaGasCost__Z>,
    pub bytesWritten: Box<Id006PscarthaGasCost__Z>,
}

impl KaitaiStruct for Id006PscarthaGasCost {
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
        self.allocations = Box::new(Id006PscarthaGasCost__Z::new(self.stream, self, _root)?);
        self.steps = Box::new(Id006PscarthaGasCost__Z::new(self.stream, self, _root)?);
        self.reads = Box::new(Id006PscarthaGasCost__Z::new(self.stream, self, _root)?);
        self.writes = Box::new(Id006PscarthaGasCost__Z::new(self.stream, self, _root)?);
        self.bytesRead = Box::new(Id006PscarthaGasCost__Z::new(self.stream, self, _root)?);
        self.bytesWritten = Box::new(Id006PscarthaGasCost__Z::new(self.stream, self, _root)?);
    }
}

impl Id006PscarthaGasCost {
}
#[derive(Default)]
pub struct Id006PscarthaGasCost__Z {
    pub hasTail: bool,
    pub sign: bool,
    pub payload: u64,
    pub tail: Vec<Box<Id006PscarthaGasCost__NChunk>>,
}

impl KaitaiStruct for Id006PscarthaGasCost__Z {
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
        self.hasTail = self.stream.read_bits_int(1)? != 0;
        self.sign = self.stream.read_bits_int(1)? != 0;
        self.payload = self.stream.read_bits_int(6)?;
        self.stream.alignToByte();
        if self.has_tail {
            self.tail = vec!();
            while {
                let tmpa = Box::new(Id006PscarthaGasCost__NChunk::new(self.stream, self, _root)?);
                self.tail.append(tmpa);
                !(!(tmpa.has_more))
            } { }
        }
    }
}

impl Id006PscarthaGasCost__Z {
}
#[derive(Default)]
pub struct Id006PscarthaGasCost__NChunk {
    pub hasMore: bool,
    pub payload: u64,
}

impl KaitaiStruct for Id006PscarthaGasCost__NChunk {
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
        self.hasMore = self.stream.read_bits_int(1)? != 0;
        self.payload = self.stream.read_bits_int(7)?;
    }
}

impl Id006PscarthaGasCost__NChunk {
}
