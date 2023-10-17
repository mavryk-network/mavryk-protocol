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
pub struct SignerMessagesDeterministicNonceResponse {
    pub deterministicNonce: Box<SignerMessagesDeterministicNonceResponse__DeterministicNonce>,
}

impl KaitaiStruct for SignerMessagesDeterministicNonceResponse {
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
        self.deterministicNonce = Box::new(SignerMessagesDeterministicNonceResponse__DeterministicNonce::new(self.stream, self, _root)?);
    }
}

impl SignerMessagesDeterministicNonceResponse {
}
#[derive(Default)]
pub struct SignerMessagesDeterministicNonceResponse__DeterministicNonce {
    pub lenDeterministicNonce: i32,
    pub deterministicNonce: Vec<u8>,
}

impl KaitaiStruct for SignerMessagesDeterministicNonceResponse__DeterministicNonce {
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
        self.lenDeterministicNonce = self.stream.read_s4be()?;
        self.deterministicNonce = self.stream.read_bytes(self.len_deterministic_nonce)?;
    }
}

impl SignerMessagesDeterministicNonceResponse__DeterministicNonce {
}
