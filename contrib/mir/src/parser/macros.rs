/******************************************************************************/
/*                                                                            */
/* SPDX-License-Identifier: MIT                                               */
/* Copyright (c) [2023] Serokell <hi@serokell.io>                             */
/*                                                                            */
/******************************************************************************/

use super::*;

use crate::lexer::macros::*;

#[derive(Debug, PartialEq, Eq, thiserror::Error)]
pub enum MacroError {
    #[error("unknown primitive: {0}")]
    UnknownMacro(String),
    #[error("unexpected number of arguments for macro: {0}")]
    UnexpectedArgumentCount(String),
}

fn unwrap_arg<T>(macro_name: &Macro, o_arg: &mut Option<T>) -> Result<T, MacroError> {
    o_arg
        .take()
        .ok_or_else(|| MacroError::UnexpectedArgumentCount(macro_name.to_string()))
}

pub fn expand_macro(
    m: &Macro,
    ib1: &mut Option<ParsedInstructionBlock>,
    ib2: &mut Option<ParsedInstructionBlock>,
) -> Result<ParsedInstructionBlock, ParserError> {
    let r = expand_macro_(m, ib1, ib2);
    // expansion must consume non-empty arguments. Assert that all arguments
    // were consumed here.
    if ib1.is_none() && ib2.is_none() {
        r
    } else {
        Err(MacroError::UnexpectedArgumentCount(m.to_string()).into())
    }
}

fn expand_macro_(
    m: &Macro,
    ib1: &mut Option<ParsedInstructionBlock>,
    ib2: &mut Option<ParsedInstructionBlock>,
) -> Result<ParsedInstructionBlock, ParserError> {
    use Instruction::*;
    use Macro::*;
    match m {
        IF_SOME => Ok(vec![IfNone(unwrap_arg(m, ib2)?, unwrap_arg(m, ib1)?)]),
        IFCMPEQ => Ok(vec![
            Compare,
            Eq,
            If(unwrap_arg(m, ib1)?, unwrap_arg(m, ib2)?),
        ]),
        IFCMPLE => Ok(vec![
            Compare,
            Le,
            If(unwrap_arg(m, ib1)?, unwrap_arg(m, ib2)?),
        ]),
        ASSERT => Ok(vec![If(
            Vec::new(),
            expand_macro(&FAIL, &mut None, &mut None)?,
        )]),
        ASSERT_CMPEQ => expand_macro(
            &IFCMPEQ,
            &mut Some(Vec::new()),
            &mut Some(expand_macro(&FAIL, &mut None, &mut None)?),
        ),
        ASSERT_CMPLE => expand_macro(
            &IFCMPLE,
            &mut Some(Vec::new()),
            &mut Some(expand_macro(&FAIL, &mut None, &mut None)?),
        ),
        FAIL => Ok(vec![Unit, Failwith(())]),
        DIIP(c) => Ok(vec![Dip(Some(*c), unwrap_arg(m, ib1)?)]),
        DUUP(c) => Ok(vec![Dup(Some(*c))]),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_macros() {
        assert_eq!(
            parse("{ ASSERT }").unwrap(),
            vec![Instruction::MacroSeq(vec![Instruction::If(
                vec![],
                vec![Instruction::Unit, Instruction::Failwith(())]
            )])]
        );

        assert_eq!(
            parse("{ ASSERT_CMPEQ }").unwrap(),
            vec![Instruction::MacroSeq(vec![
                Instruction::Compare,
                Instruction::Eq,
                Instruction::If(vec![], vec![Instruction::Unit, Instruction::Failwith(())])
            ])]
        );

        assert_eq!(
            parse("{ ASSERT_CMPLE }").unwrap(),
            vec![Instruction::MacroSeq(vec![
                Instruction::Compare,
                Instruction::Le,
                Instruction::If(vec![], vec![Instruction::Unit, Instruction::Failwith(())])
            ])]
        );

        assert_eq!(
            parse("{ IF_SOME { UNIT } {} }").unwrap(),
            vec![Instruction::MacroSeq(vec![Instruction::IfNone(
                vec![],
                vec![Instruction::Unit]
            )])]
        );

        assert_eq!(
            parse("{ IFCMPEQ { UNIT } {} }").unwrap(),
            vec![Instruction::MacroSeq(vec![
                Instruction::Compare,
                Instruction::Eq,
                Instruction::If(vec![Instruction::Unit], vec![])
            ])]
        );

        assert_eq!(
            parse("{ IFCMPLE { UNIT } {} }").unwrap(),
            vec![Instruction::MacroSeq(vec![
                Instruction::Compare,
                Instruction::Le,
                Instruction::If(vec![Instruction::Unit], vec![])
            ])]
        );

        assert_eq!(
            parse("{ DIIIP { UNIT } }").unwrap(),
            vec![Instruction::MacroSeq(vec![Instruction::Dip(
                Some(3),
                vec![Instruction::Unit]
            )])]
        );

        assert_eq!(
            parse("{ DUUP }").unwrap(),
            vec![Instruction::MacroSeq(vec![Instruction::Dup(Some(2))])]
        );

        assert_eq!(
            parse("{ DUUUUP }").unwrap(),
            vec![Instruction::MacroSeq(vec![Instruction::Dup(Some(4))])]
        );

        assert_eq!(
            parse("{ FAIL }").unwrap(),
            vec![Instruction::MacroSeq(vec![
                Instruction::Unit,
                Instruction::Failwith(())
            ])]
        );

        assert_eq!(
            parse("{ FAIL {} {} }").unwrap_err().to_string(),
            "unexpected number of arguments for macro: FAIL"
        );
    }
}
