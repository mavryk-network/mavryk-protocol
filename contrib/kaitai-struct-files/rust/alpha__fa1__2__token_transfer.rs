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
pub struct AlphaFa12TokenTransfer {
    pub tokenContract: Box<AlphaFa12TokenTransfer__TokenContract>,
    pub destination: Box<AlphaFa12TokenTransfer__Destination>,
    pub amount: Box<AlphaFa12TokenTransfer__Z>,
    pub tezAmountTag: Box<AlphaFa12TokenTransfer__Bool>,
    pub tezAmount: Box<AlphaFa12TokenTransfer__TezAmount>,
    pub feeTag: Box<AlphaFa12TokenTransfer__Bool>,
    pub fee: Box<AlphaFa12TokenTransfer__Fee>,
    pub gasLimitTag: Box<AlphaFa12TokenTransfer__Bool>,
    pub gasLimit: Box<AlphaFa12TokenTransfer__N>,
    pub storageLimitTag: Box<AlphaFa12TokenTransfer__Bool>,
    pub storageLimit: Box<AlphaFa12TokenTransfer__Z>,
}

impl KaitaiStruct for AlphaFa12TokenTransfer {
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
        self.tokenContract = Box::new(AlphaFa12TokenTransfer__TokenContract::new(self.stream, self, _root)?);
        self.destination = Box::new(AlphaFa12TokenTransfer__Destination::new(self.stream, self, _root)?);
        self.amount = Box::new(AlphaFa12TokenTransfer__Z::new(self.stream, self, _root)?);
        self.tezAmountTag = self.stream.read_u1()?;
        if self.tez__amount_tag == AlphaFa12TokenTransfer__Bool::TRUE {
            self.tezAmount = Box::new(AlphaFa12TokenTransfer__TezAmount::new(self.stream, self, _root)?);
        }
        self.feeTag = self.stream.read_u1()?;
        if self.fee_tag == AlphaFa12TokenTransfer__Bool::TRUE {
            self.fee = Box::new(AlphaFa12TokenTransfer__Fee::new(self.stream, self, _root)?);
        }
        self.gasLimitTag = self.stream.read_u1()?;
        if self.gas__limit_tag == AlphaFa12TokenTransfer__Bool::TRUE {
            self.gasLimit = Box::new(AlphaFa12TokenTransfer__N::new(self.stream, self, _root)?);
        }
        self.storageLimitTag = self.stream.read_u1()?;
        if self.storage__limit_tag == AlphaFa12TokenTransfer__Bool::TRUE {
            self.storageLimit = Box::new(AlphaFa12TokenTransfer__Z::new(self.stream, self, _root)?);
        }
    }
}

impl AlphaFa12TokenTransfer {
}
enum AlphaFa12TokenTransfer__Bool {
    FALSE,
    TRUE,
}
#[derive(Default)]
pub struct AlphaFa12TokenTransfer__N {
    pub n: Vec<Box<AlphaFa12TokenTransfer__NChunk>>,
}

impl KaitaiStruct for AlphaFa12TokenTransfer__N {
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
        self.n = vec!();
        while {
            let tmpa = Box::new(AlphaFa12TokenTransfer__NChunk::new(self.stream, self, _root)?);
            self.n.append(tmpa);
            !(!(tmpa.has_more))
        } { }
    }
}

impl AlphaFa12TokenTransfer__N {
}
#[derive(Default)]
pub struct AlphaFa12TokenTransfer__TokenContract {
    pub lenTokenContract: i32,
    pub tokenContract: Vec<u8>,
}

impl KaitaiStruct for AlphaFa12TokenTransfer__TokenContract {
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
        self.lenTokenContract = self.stream.read_s4be()?;
        self.tokenContract = self.stream.read_bytes(self.len_token_contract)?;
    }
}

impl AlphaFa12TokenTransfer__TokenContract {
}
#[derive(Default)]
pub struct AlphaFa12TokenTransfer__TezAmount {
    pub lenTezAmount: i32,
    pub tezAmount: Vec<u8>,
}

impl KaitaiStruct for AlphaFa12TokenTransfer__TezAmount {
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
        self.lenTezAmount = self.stream.read_s4be()?;
        self.tezAmount = self.stream.read_bytes(self.len_tez__amount)?;
    }
}

impl AlphaFa12TokenTransfer__TezAmount {
}
#[derive(Default)]
pub struct AlphaFa12TokenTransfer__NChunk {
    pub hasMore: bool,
    pub payload: u64,
}

impl KaitaiStruct for AlphaFa12TokenTransfer__NChunk {
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

impl AlphaFa12TokenTransfer__NChunk {
}
#[derive(Default)]
pub struct AlphaFa12TokenTransfer__Destination {
    pub lenDestination: i32,
    pub destination: Vec<u8>,
}

impl KaitaiStruct for AlphaFa12TokenTransfer__Destination {
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
        self.lenDestination = self.stream.read_s4be()?;
        self.destination = self.stream.read_bytes(self.len_destination)?;
    }
}

impl AlphaFa12TokenTransfer__Destination {
}
#[derive(Default)]
pub struct AlphaFa12TokenTransfer__Z {
    pub hasTail: bool,
    pub sign: bool,
    pub payload: u64,
    pub tail: Vec<Box<AlphaFa12TokenTransfer__NChunk>>,
}

impl KaitaiStruct for AlphaFa12TokenTransfer__Z {
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
                let tmpa = Box::new(AlphaFa12TokenTransfer__NChunk::new(self.stream, self, _root)?);
                self.tail.append(tmpa);
                !(!(tmpa.has_more))
            } { }
        }
    }
}

impl AlphaFa12TokenTransfer__Z {
}
#[derive(Default)]
pub struct AlphaFa12TokenTransfer__Fee {
    pub lenFee: i32,
    pub fee: Vec<u8>,
}

impl KaitaiStruct for AlphaFa12TokenTransfer__Fee {
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
        self.lenFee = self.stream.read_s4be()?;
        self.fee = self.stream.read_bytes(self.len_fee)?;
    }
}

impl AlphaFa12TokenTransfer__Fee {
}
