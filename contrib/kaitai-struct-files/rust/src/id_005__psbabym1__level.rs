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
pub struct Id005Psbabym1Level {
    pub level: i32,
    pub levelPosition: i32,
    pub cycle: i32,
    pub cyclePosition: i32,
    pub votingPeriod: i32,
    pub votingPeriodPosition: i32,
    pub expectedCommitment: Box<Id005Psbabym1Level__Bool>,
}

impl KaitaiStruct for Id005Psbabym1Level {
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
        self.votingPeriod = self.stream.read_s4be()?;
        self.votingPeriodPosition = self.stream.read_s4be()?;
        self.expectedCommitment = self.stream.read_u1()?;
    }
}

impl Id005Psbabym1Level {

    /*
     * The level of the block relative to genesis. This is also the Shell's notion of level
     */

    /*
     * The level of the block relative to the block that starts protocol alpha. This is specific to the protocol alpha. Other protocols might or might not include a similar notion.
     */

    /*
     * The current cycle's number. Note that cycles are a protocol-specific notion. As a result, the cycle number starts at 0 with the first block of protocol alpha.
     */

    /*
     * The current level of the block relative to the first block of the current cycle.
     */

    /*
     * The current voting period's index. Note that cycles are a protocol-specific notion. As a result, the voting period index starts at 0 with the first block of protocol alpha.
     */

    /*
     * The current level of the block relative to the first block of the current voting period.
     */

    /*
     * Tells wether the baker of this block has to commit a seed nonce hash.
     */
}
enum Id005Psbabym1Level__Bool {
    FALSE,
    TRUE,
}
