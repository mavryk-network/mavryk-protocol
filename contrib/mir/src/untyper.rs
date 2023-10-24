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
            // ↑ This transformation for pairs deviates from the optimized representation of the
            // reference implementation, because reference implementation optimizes the size of combs
            // and uses an untyped representation that is the shortest.
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

#[cfg(test)]
mod test_untypers {
    use proptest::prelude::*;

    use crate::{ast::test_strategies as TS, context::Ctx};

    proptest! {
        #[test]
        fn value_typecheck_untype_roundtrip(inp in TS::typed_value_and_type()) {
            let mut ctx = Ctx::default();
            let roundtripped = inp.val.clone().untype().typecheck(&mut ctx, &inp.ty);
            assert_eq!(roundtripped, Ok(inp.val))
        }
    }
}
