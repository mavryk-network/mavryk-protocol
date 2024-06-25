/******************************************************************************/
/*                                                                            */
/* SPDX-License-Identifier: MIT                                               */
/* Copyright (c) [2023] Serokell <hi@serokell.io>                             */
/*                                                                            */
/******************************************************************************/

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum Add {
    IntInt,
    NatNat,
    IntNat,
    NatInt,
    MumavMumav,
    Bls12381G1,
    Bls12381G2,
    Bls12381Fr,
    TimestampInt,
    IntTimestamp,
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum Sub {
    NatNat,
    NatInt,
    IntNat,
    IntInt,
    TimestampInt,
    TimestampTimestamp,
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum And {
    Bool,
    NatNat,
    IntNat,
    Bytes,
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum Or {
    Bool,
    Nat,
    Bytes,
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum Xor {
    Bool,
    Nat,
    Bytes,
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum Not {
    Bool,
    Nat,
    Int,
    Bytes,
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum Mem {
    Set,
    Map,
    BigMap,
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum Mul {
    NatNat,
    NatInt,
    IntNat,
    IntInt,
    MumavNat,
    NatMumav,
    Bls12381G1Bls12381Fr,
    Bls12381G2Bls12381Fr,
    Bls12381FrBls12381Fr,
    NatBls12381Fr,
    IntBls12381Fr,
    Bls12381FrNat,
    Bls12381FrInt,
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum EDiv {
    NatNat,
    NatInt,
    IntNat,
    IntInt,
    MumavNat,
    MumavMumav,
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum Neg {
    Nat,
    Int,
    Bls12381G1,
    Bls12381G2,
    Bls12381Fr,
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum Lsl {
    Nat,
    Bytes,
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum Lsr {
    Nat,
    Bytes,
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum Get {
    Map,
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum Update {
    Map,
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum Iter {
    List,
    Map,
}
