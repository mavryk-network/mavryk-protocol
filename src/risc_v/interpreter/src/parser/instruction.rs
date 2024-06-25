// SPDX-FileCopyrightText: 2024 Nomadic Labs <contact@nomadic-labs.com>
// SPDX-FileCopyrightText: 2024 TriliTech <contact@trili.tech>
//
// SPDX-License-Identifier: MIT

use std::fmt;

use crate::{
    interpreter::float::RoundingMode,
    machine_state::{
        csregisters::CSRegister,
        registers::{FRegister, XRegister},
    },
};

#[derive(Debug, PartialEq, Clone, Copy)]
pub struct RTypeArgs {
    pub rd: XRegister,
    pub rs1: XRegister,
    pub rs2: XRegister,
}

#[derive(Debug, PartialEq, Clone, Copy)]
pub struct ITypeArgs {
    pub rd: XRegister,
    pub rs1: XRegister,
    pub imm: i64,
}

#[derive(Debug, PartialEq, Clone, Copy)]
pub struct SBTypeArgs {
    pub rs1: XRegister,
    pub rs2: XRegister,
    pub imm: i64,
}

#[derive(Debug, PartialEq, Clone, Copy)]
pub struct UJTypeArgs {
    pub rd: XRegister,
    pub imm: i64,
}

#[derive(Debug, PartialEq, Clone, Copy)]
pub struct CsrArgs {
    pub rd: XRegister,
    pub rs1: XRegister,
    pub csr: CSRegister,
}

#[derive(Debug, PartialEq, Clone, Copy)]
pub struct CsriArgs {
    pub rd: XRegister,
    pub imm: i64,
    pub csr: CSRegister,
}

#[derive(Debug, PartialEq, Clone, Copy)]
pub struct FenceSet {
    pub i: bool,
    pub o: bool,
    pub r: bool,
    pub w: bool,
}

#[derive(Debug, PartialEq, Clone, Copy)]
pub struct FenceArgs {
    pub pred: FenceSet,
    pub succ: FenceSet,
}

#[derive(Debug, PartialEq, Clone, Copy)]
pub struct FRegToXRegArgs {
    pub rd: XRegister,
    pub rs1: FRegister,
}

#[derive(Debug, PartialEq, Clone, Copy)]
pub struct XRegToFRegArgs {
    pub rd: FRegister,
    pub rs1: XRegister,
}

#[derive(Debug, PartialEq, Clone, Copy)]
pub struct FCmpArgs {
    pub rs1: FRegister,
    pub rs2: FRegister,
    pub rd: XRegister,
}

#[derive(Debug, PartialEq, Clone, Copy)]
pub struct FRArgs {
    pub rs1: FRegister,
    pub rs2: FRegister,
    pub rd: FRegister,
}

/// There are 6 supported rounding modes that an instruction may use.
#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum InstrRoundingMode {
    Dynamic,
    Static(RoundingMode),
}

impl InstrRoundingMode {
    /// Read the parsing mode from the byte given
    pub fn from_rm(rm: u32) -> Option<Self> {
        if rm == 0b111 {
            Some(Self::Dynamic)
        } else {
            RoundingMode::try_from(rm as u64).map(Self::Static).ok()
        }
    }
}

/// Floating-point R-type instruction, containing
/// rounding mode, and one input argument.
#[derive(Debug, PartialEq, Clone, Copy)]
pub struct FR1ArgWithRounding {
    pub rs1: FRegister,
    pub rm: InstrRoundingMode,
    pub rd: FRegister,
}

/// Floating-point R-type instruction, containing
/// rounding mode, and two input arguments.
#[derive(Debug, PartialEq, Clone, Copy)]
pub struct FR2ArgsWithRounding {
    pub rs1: FRegister,
    pub rs2: FRegister,
    pub rm: InstrRoundingMode,
    pub rd: FRegister,
}

/// Floating-point R-type instruction, containing
/// rounding mode, and three input arguments.
#[derive(Debug, PartialEq, Clone, Copy)]
pub struct FR3ArgsWithRounding {
    pub rs1: FRegister,
    pub rs2: FRegister,
    pub rs3: FRegister,
    pub rm: InstrRoundingMode,
    pub rd: FRegister,
}

#[derive(Debug, PartialEq, Clone, Copy)]
pub struct FStoreArgs {
    pub rs1: XRegister,
    pub rs2: FRegister,
    pub imm: i64,
}

#[derive(Debug, PartialEq, Clone, Copy)]
pub struct FLoadArgs {
    pub rs1: XRegister,
    pub rd: FRegister,
    pub imm: i64,
}

// R-type instructions with 2 additional bits which specify memory ordering
// constraints as viewed by other RISC-V harts
#[derive(Debug, PartialEq, Clone, Copy)]
pub struct AmoArgs {
    pub rd: XRegister,
    pub rs1: XRegister,
    pub rs2: XRegister,
    pub aq: bool,
    pub rl: bool,
}

/// RISC-V parsed instructions. Along with legal instructions, potentially
/// illegal instructions are parsed as `Unknown` or `UnknownCompressed`.
/// These instructions are successfully parsed, but must not be interpreted.
#[derive(Debug, PartialEq, Clone, Copy)]
pub enum Instr {
    // RV64I R-type instructions
    Add(RTypeArgs),
    Sub(RTypeArgs),
    Xor(RTypeArgs),
    Or(RTypeArgs),
    And(RTypeArgs),
    Sll(RTypeArgs),
    Srl(RTypeArgs),
    Sra(RTypeArgs),
    Slt(RTypeArgs),
    Sltu(RTypeArgs),
    Addw(RTypeArgs),
    Subw(RTypeArgs),
    Sllw(RTypeArgs),
    Srlw(RTypeArgs),
    Sraw(RTypeArgs),

    // RV64I I-type instructions
    Addi(ITypeArgs),
    Addiw(ITypeArgs),
    Xori(ITypeArgs),
    Ori(ITypeArgs),
    Andi(ITypeArgs),
    Slli(ITypeArgs),
    Srli(ITypeArgs),
    Srai(ITypeArgs),
    Slliw(ITypeArgs),
    Srliw(ITypeArgs),
    Sraiw(ITypeArgs),
    Slti(ITypeArgs),
    Sltiu(ITypeArgs),
    Lb(ITypeArgs),
    Lh(ITypeArgs),
    Lw(ITypeArgs),
    Lbu(ITypeArgs),
    Lhu(ITypeArgs),
    Lwu(ITypeArgs),
    Ld(ITypeArgs),
    Fence(FenceArgs),
    FenceTso(FenceArgs),
    Ecall,
    Ebreak,

    // RV64I S-type instructions
    Sb(SBTypeArgs),
    Sh(SBTypeArgs),
    Sw(SBTypeArgs),
    Sd(SBTypeArgs),

    // RV64I B-type instructions
    Beq(SBTypeArgs),
    Bne(SBTypeArgs),
    Blt(SBTypeArgs),
    Bge(SBTypeArgs),
    Bltu(SBTypeArgs),
    Bgeu(SBTypeArgs),

    // RV64I U-type instructions
    Lui(UJTypeArgs),
    Auipc(UJTypeArgs),

    // RV64I jump instructions
    Jal(UJTypeArgs),
    Jalr(ITypeArgs),

    // RV64A R-type atomic instructions
    Amoswapw(AmoArgs),
    Amoaddw(AmoArgs),
    Amoxorw(AmoArgs),
    Amoandw(AmoArgs),
    Amoorw(AmoArgs),
    Amominw(AmoArgs),
    Amomaxw(AmoArgs),
    Amominuw(AmoArgs),
    Amomaxuw(AmoArgs),

    // RV64M division instructions
    Rem(RTypeArgs),
    Remu(RTypeArgs),
    Remw(RTypeArgs),
    Remuw(RTypeArgs),
    Div(RTypeArgs),
    Divu(RTypeArgs),
    Divw(RTypeArgs),
    Divuw(RTypeArgs),
    Mul(RTypeArgs),
    Mulh(RTypeArgs),
    Mulhsu(RTypeArgs),
    Mulhu(RTypeArgs),
    Mulw(RTypeArgs),

    // RV64F instructions
    FclassS(FRegToXRegArgs),
    Feqs(FCmpArgs),
    Fles(FCmpArgs),
    Flts(FCmpArgs),
    Fadds(FR2ArgsWithRounding),
    Fsubs(FR2ArgsWithRounding),
    Fmuls(FR2ArgsWithRounding),
    Fdivs(FR2ArgsWithRounding),
    Fsqrts(FR1ArgWithRounding),
    Fmins(FRArgs),
    Fmaxs(FRArgs),
    Fmadds(FR3ArgsWithRounding),
    Fmsubs(FR3ArgsWithRounding),
    Fnmsubs(FR3ArgsWithRounding),
    Fnmadds(FR3ArgsWithRounding),
    Flw(FLoadArgs),
    Fsw(FStoreArgs),
    Fsgnjs(FRArgs),
    Fsgnjns(FRArgs),
    Fsgnjxs(FRArgs),
    FmvXW(FRegToXRegArgs),
    FmvWX(XRegToFRegArgs),

    // RV64D instructions
    FclassD(FRegToXRegArgs),
    Feqd(FCmpArgs),
    Fled(FCmpArgs),
    Fltd(FCmpArgs),
    Faddd(FR2ArgsWithRounding),
    Fsubd(FR2ArgsWithRounding),
    Fmuld(FR2ArgsWithRounding),
    Fdivd(FR2ArgsWithRounding),
    Fsqrtd(FR1ArgWithRounding),
    Fmind(FRArgs),
    Fmaxd(FRArgs),
    Fmaddd(FR3ArgsWithRounding),
    Fmsubd(FR3ArgsWithRounding),
    Fnmsubd(FR3ArgsWithRounding),
    Fnmaddd(FR3ArgsWithRounding),
    Fld(FLoadArgs),
    Fsd(FStoreArgs),
    Fsgnjd(FRArgs),
    Fsgnjnd(FRArgs),
    Fsgnjxd(FRArgs),
    FmvXD(FRegToXRegArgs),
    FmvDX(XRegToFRegArgs),

    // Zicsr instructions
    Csrrw(CsrArgs),
    Csrrs(CsrArgs),
    Csrrc(CsrArgs),
    Csrrwi(CsriArgs),
    Csrrsi(CsriArgs),
    Csrrci(CsriArgs),

    // Zifencei instructions
    FenceI,

    // Privileged instructions
    // Trap-Return
    Mret,
    Sret,
    Mnret,
    // Interrupt-Management
    Wfi,
    // Supervisor Memory-Management
    SFenceVma { asid: XRegister, vaddr: XRegister },

    Unknown { instr: u32 },
    UnknownCompressed { instr: u16 },
}

use Instr::*;

impl Instr {
    /// Return the width of the instruction in bytes.
    pub fn width(&self) -> u64 {
        match self {
            // 4 bytes instructions
            Add(_)
            | Sub(_)
            | Xor(_)
            | Or(_)
            | And(_)
            | Sll(_)
            | Srl(_)
            | Sra(_)
            | Slt(_)
            | Sltu(_)
            | Addw(_)
            | Subw(_)
            | Sllw(_)
            | Srlw(_)
            | Sraw(_)
            | Addi(_)
            | Addiw(_)
            | Xori(_)
            | Ori(_)
            | Andi(_)
            | Slli(_)
            | Srli(_)
            | Srai(_)
            | Slliw(_)
            | Srliw(_)
            | Sraiw(_)
            | Slti(_)
            | Sltiu(_)
            | Lb(_)
            | Lh(_)
            | Lw(_)
            | Lbu(_)
            | Lhu(_)
            | Lwu(_)
            | Ld(_)
            | Fence(_)
            | FenceTso(_)
            | Ecall
            | Ebreak
            | Sb(_)
            | Sh(_)
            | Sw(_)
            | Sd(_)
            | Beq(_)
            | Bne(_)
            | Blt(_)
            | Bge(_)
            | Bltu(_)
            | Bgeu(_)
            | Lui(_)
            | Auipc(_)
            | Jal(_)
            | Jalr(_)
            | Amoswapw(_)
            | Amoaddw(_)
            | Amoxorw(_)
            | Amoandw(_)
            | Amoorw(_)
            | Amominw(_)
            | Amomaxw(_)
            | Amominuw(_)
            | Amomaxuw(_)
            | Rem(_)
            | Remu(_)
            | Remw(_)
            | Remuw(_)
            | Div(_)
            | Divu(_)
            | Divw(_)
            | Divuw(_)
            | Mul(_)
            | Mulh(_)
            | Mulhsu(_)
            | Mulhu(_)
            | Mulw(_)
            | FmvXW(_)
            | FmvWX(_)
            | Fsgnjs(_)
            | Fsgnjns(_)
            | Fsgnjxs(_)
            | FclassS(_)
            | Feqs(_)
            | Fles(_)
            | Flts(_)
            | Fadds(_)
            | Fsubs(_)
            | Fmuls(_)
            | Fdivs(_)
            | Fsqrts(_)
            | Fmins(_)
            | Fmaxs(_)
            | Fmadds(_)
            | Fmsubs(_)
            | Fnmsubs(_)
            | Fnmadds(_)
            | Flw(_)
            | Fsw(_)
            | FmvXD(_)
            | FmvDX(_)
            | Fsgnjd(_)
            | Fsgnjnd(_)
            | Fsgnjxd(_)
            | FclassD(_)
            | Feqd(_)
            | Fled(_)
            | Fltd(_)
            | Faddd(_)
            | Fsubd(_)
            | Fmuld(_)
            | Fdivd(_)
            | Fsqrtd(_)
            | Fmind(_)
            | Fmaxd(_)
            | Fmaddd(_)
            | Fmsubd(_)
            | Fnmsubd(_)
            | Fnmaddd(_)
            | Fld(_)
            | Fsd(_)
            | Csrrw(_)
            | Csrrs(_)
            | Csrrc(_)
            | Csrrwi(_)
            | Csrrsi(_)
            | Csrrci(_)
            | FenceI
            | Mret
            | Sret
            | Mnret
            | Wfi
            | SFenceVma { .. }
            | Unknown { instr: _ } => 4,

            // 2 bytes instructions (compressed instructions)
            UnknownCompressed { instr: _ } => 2,
        }
    }
}

macro_rules! r_instr {
    ($f:expr, $op:expr, $args:expr) => {
        write!($f, "{} {},{},{}", $op, $args.rd, $args.rs1, $args.rs2)
    };
}

macro_rules! r2_instr {
    ($f:expr, $op:expr, $args:expr) => {
        write!($f, "{} {},{}", $op, $args.rd, $args.rs1)
    };
}

macro_rules! r4_instr {
    ($f:expr, $op:expr, $args:expr) => {
        write!(
            $f,
            "{} {},{},{},{}",
            $op, $args.rd, $args.rs1, $args.rs2, $args.rs3
        )
    };
}

macro_rules! i_instr {
    ($f:expr, $op:expr, $args:expr) => {
        write!($f, "{} {},{},{}", $op, $args.rd, $args.rs1, $args.imm)
    };
}

macro_rules! i_instr_hex {
    ($f:expr, $op:expr, $args:expr) => {
        write!($f, "{} {},{},0x{:x}", $op, $args.rd, $args.rs1, $args.imm)
    };
}

macro_rules! i_instr_load {
    ($f:expr, $op:expr, $args:expr) => {
        write!($f, "{} {},{}({})", $op, $args.rd, $args.imm, $args.rs1)
    };
}

macro_rules! j_instr {
    ($f:expr, $op:expr, $args:expr) => {
        write!($f, "{} {},0x{:x}", $op, $args.rd, $args.imm)
    };
}

macro_rules! s_instr {
    ($f:expr, $op:expr, $args:expr) => {
        write!($f, "{} {},{}({})", $op, $args.rs2, $args.imm, $args.rs1)
    };
}

macro_rules! b_instr {
    ($f:expr, $op:expr, $args:expr) => {
        write!($f, "{} {},{},{}", $op, $args.rs1, $args.rs2, $args.imm)
    };
}

macro_rules! u_instr {
    ($f:expr, $op:expr, $args:expr) => {
        write!($f, "{} {},{}", $op, $args.rd, $args.imm)
    };
}

macro_rules! f_s1_instr {
    ($f:expr, $op:expr, $args:expr) => {
        write!($f, "{} {},{}", $op, $args.rd, $args.rs1)
    };
}

macro_rules! fence_instr {
    ($f:expr, $op:expr, $args:expr) => {
        write!($f, "{} {},{}", $op, $args.pred, $args.succ)
    };
}

macro_rules! amo_instr {
    ($f:expr, $op:expr, $args:expr) => {
        write!($f, "{} {},{},({})", $op, $args.rd, $args.rs2, $args.rs1)
    };
}

macro_rules! csr_instr {
    ($f:expr, $op:expr, $args:expr) => {
        write!($f, "{} {},{},{}", $op, $args.rd, $args.csr, $args.rs1)
    };
}

macro_rules! csri_instr {
    ($f:expr, $op:expr, $args:expr) => {
        write!($f, "{} {},{},{}", $op, $args.rd, $args.csr, $args.imm)
    };
}

impl fmt::Display for FenceSet {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut out = String::new();
        if self.i {
            out.push('i')
        };
        if self.o {
            out.push('o')
        };
        if self.r {
            out.push('r')
        };
        if self.w {
            out.push('w')
        };
        if out.is_empty() {
            write!(f, "unknown")
        } else {
            write!(f, "{}", out)
        }
    }
}

/// An objdump-style prettyprinter for parsed instructions, used in testing
/// the parser against objdump.
impl fmt::Display for Instr {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            // RV64I R-type instructions
            Add(args) => r_instr!(f, "add", args),
            Sub(args) => r_instr!(f, "sub", args),
            Xor(args) => r_instr!(f, "xor", args),
            Or(args) => r_instr!(f, "or", args),
            And(args) => r_instr!(f, "and", args),
            Sll(args) => r_instr!(f, "sll", args),
            Srl(args) => r_instr!(f, "srl", args),
            Sra(args) => r_instr!(f, "sra", args),
            Slt(args) => r_instr!(f, "slt", args),
            Sltu(args) => r_instr!(f, "sltu", args),
            Addw(args) => r_instr!(f, "addw", args),
            Subw(args) => r_instr!(f, "subw", args),
            Sllw(args) => r_instr!(f, "sllw", args),
            Srlw(args) => r_instr!(f, "srlw", args),
            Sraw(args) => r_instr!(f, "sraw", args),

            // RV64I I-type instructions
            Addi(args) => i_instr!(f, "addi", args),
            Addiw(args) => i_instr!(f, "addiw", args),
            Xori(args) => i_instr!(f, "xori", args),
            Ori(args) => i_instr!(f, "ori", args),
            Andi(args) => i_instr!(f, "andi", args),
            Slli(args) => i_instr_hex!(f, "slli", args),
            Srli(args) => i_instr_hex!(f, "srli", args),
            // For consistency with objdump, only the shift amount is printed
            Srai(args) => {
                i_instr_hex!(
                    f,
                    "srai",
                    ITypeArgs {
                        imm: args.imm & !(1 << 10),
                        ..*args
                    }
                )
            }
            Slliw(args) => i_instr_hex!(f, "slliw", args),
            Srliw(args) => i_instr_hex!(f, "srliw", args),
            Sraiw(args) => {
                i_instr_hex!(
                    f,
                    "sraiw",
                    ITypeArgs {
                        imm: args.imm & !(1 << 10),
                        ..*args
                    }
                )
            }
            Slti(args) => i_instr!(f, "slti", args),
            Sltiu(args) => i_instr!(f, "sltiu", args),
            Lb(args) => i_instr_load!(f, "lb", args),
            Lh(args) => i_instr_load!(f, "lh", args),
            Lw(args) => i_instr_load!(f, "lw", args),
            Lbu(args) => i_instr_load!(f, "lbu", args),
            Lhu(args) => i_instr_load!(f, "lhu", args),
            Lwu(args) => i_instr_load!(f, "lwu", args),
            Ld(args) => i_instr_load!(f, "ld", args),

            Fence(args) => fence_instr!(f, "fence", args),
            FenceTso(args) => fence_instr!(f, "fence.tso", args),

            Ecall => write!(f, "ecall"),
            Ebreak => write!(f, "ebreak"),

            // RV64I S-type instructions
            Sb(args) => s_instr!(f, "sb", args),
            Sh(args) => s_instr!(f, "sh", args),
            Sw(args) => s_instr!(f, "sw", args),
            Sd(args) => s_instr!(f, "sd", args),

            // RV64I B-type instructions
            Beq(args) => b_instr!(f, "beq", args),
            Bne(args) => b_instr!(f, "bne", args),
            Blt(args) => b_instr!(f, "blt", args),
            Bge(args) => b_instr!(f, "bge", args),
            Bltu(args) => b_instr!(f, "bltu", args),
            Bgeu(args) => b_instr!(f, "bgeu", args),

            // RV64I U-type instructions
            // For consistency with objdump, upper immediates are shifted down
            Lui(args) => j_instr!(
                f,
                "lui",
                UJTypeArgs {
                    rd: args.rd,
                    imm: (args.imm >> 12) & ((0b1 << 20) - 1),
                }
            ),
            Auipc(args) => j_instr!(
                f,
                "auipc",
                UJTypeArgs {
                    rd: args.rd,
                    imm: (args.imm >> 12) & ((0b1 << 20) - 1),
                }
            ),

            // RV64I jump instructions
            Jal(args) => u_instr!(f, "jal", args),
            Jalr(args) => i_instr_load!(f, "jalr", args),

            Amoswapw(args) => amo_instr!(f, "amoswap.w", args),
            Amoaddw(args) => amo_instr!(f, "amoadd.w", args),
            Amoxorw(args) => amo_instr!(f, "amoxor.w", args),
            Amoandw(args) => amo_instr!(f, "amoand.w", args),
            Amoorw(args) => amo_instr!(f, "amoor.w", args),
            Amominw(args) => amo_instr!(f, "amomin.w", args),
            Amomaxw(args) => amo_instr!(f, "amomax.w", args),
            Amominuw(args) => amo_instr!(f, "amominu.w", args),
            Amomaxuw(args) => amo_instr!(f, "amomaxu.w", args),

            // RV64M multiplication and division instructions
            Rem(args) => r_instr!(f, "rem", args),
            Remu(args) => r_instr!(f, "remu", args),
            Remw(args) => r_instr!(f, "remw", args),
            Remuw(args) => r_instr!(f, "remuw", args),
            Div(args) => r_instr!(f, "div", args),
            Divu(args) => r_instr!(f, "divu", args),
            Divw(args) => r_instr!(f, "divw", args),
            Divuw(args) => r_instr!(f, "divuw", args),
            Mul(args) => r_instr!(f, "mul", args),
            Mulh(args) => r_instr!(f, "mulh", args),
            Mulhsu(args) => r_instr!(f, "mulhsu", args),
            Mulhu(args) => r_instr!(f, "mulhu", args),
            Mulw(args) => r_instr!(f, "mulw", args),

            // RV64F instructions
            FclassS(args) => f_s1_instr!(f, "fclass.s", args),
            Feqs(args) => r_instr!(f, "feq.s", args),
            Fles(args) => r_instr!(f, "fle.s", args),
            Flts(args) => r_instr!(f, "flt.s", args),
            Fadds(args) => r_instr!(f, "fadd.s", args),
            Fsubs(args) => r_instr!(f, "fsub.s", args),
            Fmuls(args) => r_instr!(f, "fmul.s", args),
            Fdivs(args) => r_instr!(f, "fdiv.s", args),
            Fsqrts(args) => r2_instr!(f, "fsqrt.s", args),
            Fmins(args) => r_instr!(f, "fmin.s", args),
            Fmaxs(args) => r_instr!(f, "fmax.s", args),
            Fmadds(args) => r4_instr!(f, "fmadd.s", args),
            Fmsubs(args) => r4_instr!(f, "fmsub.s", args),
            Fnmsubs(args) => r4_instr!(f, "fnmsub.s", args),
            Fnmadds(args) => r4_instr!(f, "fnmadd.s", args),
            Flw(args) => i_instr_load!(f, "flw", args),
            Fsw(args) => s_instr!(f, "fsw", args),
            Fsgnjs(args) => r_instr!(f, "fsgnj.s", args),
            Fsgnjns(args) => r_instr!(f, "fsgnjn.s", args),
            Fsgnjxs(args) => r_instr!(f, "fsgnjx.s", args),
            FmvXW(args) => f_s1_instr!(f, "fmv.x.w", args),
            FmvWX(args) => f_s1_instr!(f, "fmv.w.x", args),

            // RV64D instructions
            FclassD(args) => f_s1_instr!(f, "fclass.d", args),
            Feqd(args) => r_instr!(f, "feq.d", args),
            Fled(args) => r_instr!(f, "fle.d", args),
            Fltd(args) => r_instr!(f, "flt.d", args),
            Faddd(args) => r_instr!(f, "fadd.d", args),
            Fsubd(args) => r_instr!(f, "fsub.d", args),
            Fmuld(args) => r_instr!(f, "fmul.d", args),
            Fdivd(args) => r_instr!(f, "fdiv.d", args),
            Fsqrtd(args) => r2_instr!(f, "fsqrt.d", args),
            Fmind(args) => r_instr!(f, "fmin.d", args),
            Fmaxd(args) => r_instr!(f, "fmax.d", args),
            Fmaddd(args) => r4_instr!(f, "fmadd.d", args),
            Fmsubd(args) => r4_instr!(f, "fmsub.d", args),
            Fnmsubd(args) => r4_instr!(f, "fnmsub.d", args),
            Fnmaddd(args) => r4_instr!(f, "fnmadd.d", args),
            Fld(args) => i_instr_load!(f, "fld", args),
            Fsd(args) => s_instr!(f, "fsd", args),
            Fsgnjd(args) => r_instr!(f, "fsgnj.d", args),
            Fsgnjnd(args) => r_instr!(f, "fsgnjn.d", args),
            Fsgnjxd(args) => r_instr!(f, "fsgnjx.d", args),
            FmvXD(args) => f_s1_instr!(f, "fmv.x.d", args),
            FmvDX(args) => f_s1_instr!(f, "fmv.d.x", args),

            // Zicsr instructions
            Csrrw(args) => csr_instr!(f, "csrrw", args),
            Csrrs(args) => csr_instr!(f, "csrrs", args),
            Csrrc(args) => csr_instr!(f, "csrrc", args),
            Csrrwi(args) => csri_instr!(f, "csrrwi", args),
            Csrrsi(args) => csri_instr!(f, "csrrsi", args),
            Csrrci(args) => csri_instr!(f, "csrrci", args),

            // Zifencei instructions
            FenceI => write!(f, "fence.i"),

            // Privileged instructions
            // Trap-Return
            Mret => write!(f, "mret"),
            Sret => write!(f, "sret"),
            Mnret => write!(f, "mnret"),
            // Interrupt-management
            Wfi => write!(f, "wfi"),
            // Supervisor Memory-Management
            SFenceVma { asid, vaddr } => write!(f, "sfence.vma {vaddr},{asid}"),

            Unknown { instr } => write!(f, "unknown {:x}", instr),
            UnknownCompressed { instr } => write!(f, "unknown.c {:x}", instr),
        }
    }
}
