/******************************************************************************/
/*                                                                            */
/* SPDX-License-Identifier: MIT                                               */
/* Copyright (c) [2023] Serokell <hi@serokell.io>                             */
/*                                                                            */
/******************************************************************************/

#[derive(Debug, Clone, Eq, PartialOrd, Ord, PartialEq)]
pub enum Or<L, R> {
    Left(L),
    Right(R),
}
