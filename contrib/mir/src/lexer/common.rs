#[derive(Debug, PartialEq, Eq, Clone, thiserror::Error)]
#[error("unknown primitive: {0}")]
pub struct PrimError(pub String);

#[derive(Debug, PartialEq, Eq, Clone, thiserror::Error)]
pub enum LexerError {
    #[error("unknown token")]
    UnknownToken,
    #[error("parsing of numeric literal {0} failed")]
    NumericLiteral(String),
    #[error("forbidden character found in string literal \"{0}\"")]
    ForbiddenCharacterIn(String),
    #[error("undefined escape sequence: \"\\{0}\"")]
    UndefinedEscape(char),
    #[error(transparent)]
    PrimError(#[from] PrimError),
}

impl Default for LexerError {
    fn default() -> Self {
        LexerError::UnknownToken
    }
}
