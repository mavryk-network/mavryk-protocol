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
pub struct SaplingTransactionCiphertext {
    pub cv: Vec<u8>,
    pub epk: Vec<u8>,
    pub payloadEnc: Box<SaplingTransactionCiphertext__PayloadEnc>,
    pub nonceEnc: Vec<u8>,
    pub payloadOut: Vec<u8>,
    pub nonceOut: Vec<u8>,
}

impl KaitaiStruct for SaplingTransactionCiphertext {
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
        self.epk = self.stream.read_bytes(32)?;
        self.payloadEnc = Box::new(SaplingTransactionCiphertext__PayloadEnc::new(self.stream, self, _root)?);
        self.nonceEnc = self.stream.read_bytes(24)?;
        self.payloadOut = self.stream.read_bytes(80)?;
        self.nonceOut = self.stream.read_bytes(24)?;
    }
}

impl SaplingTransactionCiphertext {
}
#[derive(Default)]
pub struct SaplingTransactionCiphertext__PayloadEnc {
    pub lenPayloadEnc: i32,
    pub payloadEnc: Vec<u8>,
}

impl KaitaiStruct for SaplingTransactionCiphertext__PayloadEnc {
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
        self.lenPayloadEnc = self.stream.read_s4be()?;
        self.payloadEnc = self.stream.read_bytes(self.len_payload_enc)?;
    }
}

impl SaplingTransactionCiphertext__PayloadEnc {
}
