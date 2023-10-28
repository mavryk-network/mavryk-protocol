use logos::*;

use super::common::*;

#[derive(Debug, Clone, PartialEq, Eq, Logos)]
#[allow(non_camel_case_types, clippy::upper_case_acronyms)]
#[logos(error = LexerError)]
pub enum Macro {
    #[token("IF_SOME")]
    IF_SOME,
    #[token("IFCMPEQ")]
    IFCMPEQ,
    #[token("IFCMPLE")]
    IFCMPLE,
    #[token("ASSERT")]
    ASSERT,
    #[token("ASSERT_CMPEQ")]
    ASSERT_CMPEQ,
    #[token("ASSERT_CMPLE")]
    ASSERT_CMPLE,
    #[token("FAIL")]
    FAIL,
    #[regex("DII+P", lex_diip)]
    DIIP(u16),
    #[regex("DUU+P", lex_duup)]
    DUUP(u16),
}

pub fn lex_diip<'a>(lex: &mut Lexer<'a, Macro>) -> Result<u16, LexerError> {
    Ok((lex.slice().len() - 2).try_into().unwrap())
}

pub fn lex_duup<'a>(lex: &mut Lexer<'a, Macro>) -> Result<u16, LexerError> {
    Ok((lex.slice().len() - 2).try_into().unwrap())
}

impl std::fmt::Display for Macro {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:?}", &self)
    }
}
