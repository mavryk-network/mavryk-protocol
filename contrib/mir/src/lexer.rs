/******************************************************************************/
/*                                                                            */
/* SPDX-License-Identifier: MIT                                               */
/* Copyright (c) [2023] Serokell <hi@serokell.io>                             */
/*                                                                            */
/******************************************************************************/

use logos::Logos;
pub mod common;
pub mod macros;

pub use common::*;
use macros::*;

/// Takes a list of primitive names, creates a simple `enum` with the names
/// provided, and defines `FromStr` implementation using stringified
/// representation of the identifiers.
macro_rules! defprim {
    ($ty:ident; $($prim:ident),* $(,)*) => {
        #[derive(Debug, Clone, Copy, PartialEq, Eq)]
        #[allow(non_camel_case_types, clippy::upper_case_acronyms)]
        pub enum $ty {
            $($prim),*
        }

        impl std::fmt::Display for $ty {
            fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
                write!(f, "{:?}", &self)
            }
        }

        impl std::str::FromStr for $ty {
            type Err = PrimError;
            fn from_str(s: &str) -> Result<Self, Self::Err> {
                match s {
                    $(stringify!($prim) => Ok($ty::$prim),)*
                        _ => Err(PrimError(s.to_owned()))
                }
            }
        }
    };
}

// NB: Primitives will be lexed as written, so capitalization matters.
defprim! {
    Prim;
    parameter,
    storage,
    code,
    int,
    nat,
    bool,
    mutez,
    string,
    unit,
    operation,
    pair,
    option,
    list,
    map,
    True,
    False,
    Unit,
    None,
    Pair,
    Some,
    Elt,
    PUSH,
    INT,
    GT,
    EQ,
    LE,
    LOOP,
    DIP,
    ADD,
    DROP,
    SWAP,
    IF,
    DUP,
    FAILWITH,
    UNIT,
    CAR,
    CDR,
    PAIR,
    IF_NONE,
    SOME,
    COMPARE,
    AMOUNT,
    NIL,
    GET,
    UPDATE,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[allow(non_camel_case_types, clippy::upper_case_acronyms)]
pub enum TztPrim {
    Stack_elt,
    input,
    output,
    Failed,
    amount,
    MutezOverflow,
    GeneralOverflow,
    StaticError,
    Underscore,
}

impl std::fmt::Display for TztPrim {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:?}", &self)
    }
}

impl std::str::FromStr for TztPrim {
    type Err = PrimError;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        use TztPrim::*;
        match s {
            "Stack_elt" => Ok(Stack_elt),
            "input" => Ok(input),
            "output" => Ok(output),
            "Failed" => Ok(Failed),
            "amount" => Ok(amount),
            "MutezOverflow" => Ok(MutezOverflow),
            "GeneralOverflow" => Ok(GeneralOverflow),
            "StaticError" => Ok(StaticError),
            "_" => Ok(Underscore),
            _ => Err(PrimError(s.to_owned())),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Noun {
    Prim(Prim),
    TztPrim(TztPrim),
    MacroPrim(Macro),
}

#[derive(Debug, Clone, PartialEq, Eq, Logos)]
#[logos(error = LexerError, skip r"[ \t\r\n\v\f]+|#[^\n]*\n")]
pub enum Tok {
    #[regex(r"[A-Za-z_]+", lex_noun)]
    Noun(Noun),

    #[regex("([+-]?)[0-9]+", lex_number)]
    Number(i128),

    #[regex(r#""(\\.|[^\\"])*""#, lex_string)]
    String(String),

    // regex as per https://tezos.gitlab.io/active/michelson.html#syntax
    #[regex(r"@%|@%%|%@|[@:%][_0-9a-zA-Z][_0-9a-zA-Z\.%@]*")]
    Annotation,

    #[token("(")]
    LParen,
    #[token(")")]
    RParen,
    #[token("{")]
    LBrace,
    #[token("}")]
    RBrace,
    #[token(";")]
    Semi,
}

impl std::fmt::Display for Tok {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match &self {
            Tok::Noun(Noun::Prim(p)) => p.fmt(f),
            Tok::Noun(Noun::TztPrim(p)) => p.fmt(f),
            Tok::Number(n) => n.fmt(f),
            Tok::String(s) => s.fmt(f),
            Tok::Annotation => write!(f, "<ann>"),
            Tok::LParen => write!(f, "("),
            Tok::RParen => write!(f, ")"),
            Tok::LBrace => write!(f, "{{"),
            Tok::RBrace => write!(f, "}}"),
            Tok::Semi => write!(f, ";"),
            Tok::Noun(Noun::MacroPrim(m)) => m.fmt(f),
        }
    }
}

type Lexer<'a> = logos::Lexer<'a, Tok>;

fn lex_macro(lex: &mut Lexer) -> Result<Macro, PrimError> {
    let slice = lex.slice();
    match Macro::lexer(slice).collect::<Result<Vec<Macro>, common::LexerError>>() {
        Ok(mut v) => Ok(v.pop().unwrap()),
        Err(_) => Err(PrimError(slice.to_string())),
    }
}

fn lex_noun(lex: &mut Lexer) -> Result<Noun, LexerError> {
    lex.slice()
        .parse()
        .map(Noun::Prim)
        .or_else(|_| lex.slice().parse().map(Noun::TztPrim))
        .or_else(|_| lex_macro(lex).map(Noun::MacroPrim))
        .map_err(LexerError::PrimError)
}

fn lex_number(lex: &mut Lexer) -> Result<i128, LexerError> {
    lex.slice()
        .parse()
        .map_err(|_| LexerError::NumericLiteral(lex.slice().to_owned()))
}

/// Takes a string _with_ the sourrounding quotes, strips the quotes, checks the
/// string is valid (i.e. contains only printable ASCII characters) and replaces
/// escapes with corresponding characters.
fn lex_string(lex: &mut Lexer) -> Result<String, LexerError> {
    let s = lex.slice();
    // strip the quotes
    let s = &s[1..s.len() - 1];

    // check if all characters are printable ASCII
    if !s.chars().all(|c| matches!(c, ' '..='~')) {
        return Err(LexerError::ForbiddenCharacterIn(s.to_owned()));
    }

    let mut res = String::new();
    // this may overreserve, but no more than 2x
    res.reserve(s.len());

    let unescape_char = |c| match c {
        'n' => Ok('\n'),
        'r' => Ok('\r'),
        '"' => Ok('"'),
        '\\' => Ok('\\'),
        _ => Err(LexerError::UndefinedEscape(c)),
    };

    let mut in_escape: bool = false;
    for c in s.chars() {
        if in_escape {
            res.push(unescape_char(c)?);
            in_escape = false;
        } else if matches!(c, '\\') {
            in_escape = true;
        } else {
            res.push(c);
        }
    }

    Ok(res)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_lex() {
        dbg!(Tok::lexer("IF_SOME {} {}").collect::<Vec<Result<Tok, common::LexerError>>>());
    }

    #[test]
    fn unescape_string() {
        macro_rules! assert_parse {
            ($s:expr, $e:expr) => {
                assert_eq!(
                    Tok::lexer($s)
                        .map(|i| i.map_err(|x| x.to_string()))
                        .collect::<Vec<Result<Tok, String>>>(),
                    vec![($e as Result<&str, &str>)
                        .map(|v| Tok::String(v.to_owned()))
                        .map_err(|e| e.to_owned())]
                )
            };
        }
        assert_parse!(r#""bar""#, Ok("bar"));
        assert_parse!(r#""foo\nbar""#, Ok("foo\nbar"));
        assert_parse!(r#""foo\"bar\"""#, Ok("foo\"bar\""));
        assert_parse!(r#""foo\rbar""#, Ok("foo\rbar"));
        assert_parse!(r#""foo\\rbar""#, Ok("foo\\rbar"));
        assert_parse!(r#""foo\\nbar""#, Ok("foo\\nbar"));
        assert_parse!(r#""foo\\\\bar""#, Ok("foo\\\\bar"));
        // unicode is not accepted
        assert_parse!(
            r#""हिन्दी""#,
            Err("forbidden character found in string literal \"हिन्दी\"")
        );
        // unknown escapes are not accepted
        assert_parse!(r#""\a""#, Err("undefined escape sequence: \"\\a\""));
        // unterminated strings are not accepted
        assert_parse!(r#"""#, Err("unknown token"));
        assert_parse!(r#""\""#, Err("unknown token"));
    }

    #[test]
    fn unknown_prim_err() {
        assert_eq!(
            Tok::lexer("foo").next().unwrap().unwrap_err().to_string(),
            "unknown primitive: foo"
        )
    }
}
