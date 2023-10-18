use crate::ast::{TypedValue, Value};

impl TypedValue {
    pub fn untype(self) -> Value {
        use TypedValue as TV;
        use Value as V;
        match self {
            TV::Int(n) => V::Number(n),
            TV::Nat(n) => V::Number(n.try_into().unwrap()),
            // ↑ unwrap will go away with switch to BigInt
            TV::Bool(b) => V::Boolean(b),
            TV::Mutez(m) => V::Number(m.into()),
            TV::String(s) => V::String(s),
            TV::Unit => V::Unit,
            TV::Pair(pv) => {
                let (vl, vr) = *pv;
                V::new_pair(vl.untype(), vr.untype())
            }
            TV::Option(ov) => V::new_option(ov.map(|v| v.untype())),
            TV::List(lv) => {
                let res = lv.into_iter().map(|v| v.untype()).collect();
                V::Seq(res)
            }
            TV::Map(m) => {
                let res = m
                    .into_iter()
                    .map(|(k, v)| V::new_elt(k.untype(), v.untype()))
                    .collect();
                V::Seq(res)
            }
        }
    }
}
