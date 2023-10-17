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
pub struct Id017PtnairobLevel {
    pub level: i32,
    pub levelPosition: i32,
    pub cycle: i32,
    pub cyclePosition: i32,
    pub expectedCommitment: Box<Id017PtnairobLevel__Bool>,
}

impl KaitaiStruct for Id017PtnairobLevel {
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
        self.level = self.stream.read_s4be()?;
        self.levelPosition = self.stream.read_s4be()?;
        self.cycle = self.stream.read_s4be()?;
        self.cyclePosition = self.stream.read_s4be()?;
        self.expectedCommitment = self.stream.read_u1()?;
    }
}

impl Id017PtnairobLevel {

    /*
     * The level of the block relative to genesis. This is also the Shell's notion of level.
     */

    /*
     * The level of the block relative to the successor of the genesis block. More precisely, it is the position of the block relative to the block that starts the "Alpha family" of protocols, which includes all protocols except Genesis (that is, from 001 onwards).
     */

    /*
     * The current cycle's number. Note that cycles are a protocol-specific notion. As a result, the cycle number starts at 0 with the first block of the Alpha family of protocols.
     */

    /*
     * The current level of the block relative to the first block of the current cycle.
     */

    /*
     * Tells whether the baker of this block has to commit a seed nonce hash.
     */
}
enum Id017PtnairobLevel__Bool {
    FALSE,
    TRUE,
}
