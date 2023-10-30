//! Michelson serialization

use crate::{ast::Value, lexer::Prim};

/// Helper type with common encoding operations.
pub struct Buf(Vec<u8>);

impl Buf {
    /// Create a buffer and write given bytes to it.
    pub fn start_with(v: Vec<u8>) -> Self {
        Buf(v)
    }

    /// Obtain the result.
    pub fn finalize(self) -> Vec<u8> {
        self.0
    }

    /// Put one byte.
    pub fn byte(&mut self, b: u8) {
        self.0.push(b)
    }

    /// Put a Michiline primitive.
    pub fn prim(&mut self, prim: Prim, args_num: u8) {
        self.byte(args_num * 2 + 3);
        self.byte(prim as u8)
    }

    /// Put length of something.
    pub fn put_len(&mut self, len: u32) {
        self.0.extend_from_slice(&len.to_be_bytes())
    }

    /// Put dynamically-sized bytes.
    pub fn dynamic_bytes(&mut self, bs: &[u8]) {
        self.byte(0x0a);
        self.put_len(bs.len() as u32);
        self.0.extend_from_slice(bs)
    }

    /// Put a Michelson string.
    pub fn string(&mut self, s: &str) {
        self.byte(0x01);
        self.put_len(s.len() as u32);
        self.0.extend_from_slice(s.as_bytes())
    }

    /// Put a container.
    pub fn list<V>(&mut self, list: &[V], encoder: impl Fn(&mut Buf, &V)) {
        self.byte(0x02);
        self.put_len(0); // don't know the right length in advance
        let i = self.0.len();
        for val in list {
            encoder(self, val)
        }
        let written_len = (self.0.len() - i) as u32;
        self.0[(i - 4)..i].copy_from_slice(&written_len.to_be_bytes())
    }
}

impl Value {
    /// Serialize value using Michelson encoding.
    fn encode(&self) -> Vec<u8> {
        self.encode_starting_with(&[])
    }

    /// Like [Value::encode], but allows specifying a prefix, useful for
    /// `PACK` implementation.
    fn encode_starting_with(&self, start_bytes: &[u8]) -> Vec<u8> {
        let mut buf = Buf::start_with(Vec::from(start_bytes));
        encode_value(&mut buf, self);
        buf.finalize()
    }
}

/// Recursive encoding function for [Value].
fn encode_value(buf: &mut Buf, value: &Value) {
    use Value::*;
    match value {
        Number(_) => todo!(), // for a later MR
        Boolean(false) => buf.prim(Prim::False, 0),
        Boolean(true) => buf.prim(Prim::True, 0),
        Unit => buf.prim(Prim::Unit, 0),
        String(s) => buf.string(s),
        Bytes(b) => buf.dynamic_bytes(b),
        Pair(p) => {
            buf.prim(Prim::Pair, 2);
            encode_value(buf, &p.0);
            encode_value(buf, &p.1);
        }
        Option(None) => {
            buf.prim(Prim::None, 0);
        }
        Option(Some(v)) => {
            buf.prim(Prim::Some, 1);
            encode_value(buf, v);
        }
        Seq(l) => buf.list(l, encode_value),
        Elt(e) => {
            buf.prim(Prim::Elt, 2);
            encode_value(buf, &e.0);
            encode_value(buf, &e.1);
        }
    }
}
