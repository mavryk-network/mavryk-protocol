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
pub struct SignerMessagesDeterministicNonceHashResponse {
    pub deterministicNonceHash: Box<SignerMessagesDeterministicNonceHashResponse__DeterministicNonceHash>,
}

impl KaitaiStruct for SignerMessagesDeterministicNonceHashResponse {
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
        self.deterministicNonceHash = Box::new(SignerMessagesDeterministicNonceHashResponse__DeterministicNonceHash::new(self.stream, self, _root)?);
    }
}

impl SignerMessagesDeterministicNonceHashResponse {
}
#[derive(Default)]
pub struct SignerMessagesDeterministicNonceHashResponse__DeterministicNonceHash {
    pub lenDeterministicNonceHash: i32,
    pub deterministicNonceHash: Vec<u8>,
}

impl KaitaiStruct for SignerMessagesDeterministicNonceHashResponse__DeterministicNonceHash {
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
        self.lenDeterministicNonceHash = self.stream.read_s4be()?;
        self.deterministicNonceHash = self.stream.read_bytes(self.len_deterministic_nonce_hash)?;
    }
}

impl SignerMessagesDeterministicNonceHashResponse__DeterministicNonceHash {
}
