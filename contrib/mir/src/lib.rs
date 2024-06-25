/******************************************************************************/
/*                                                                            */
/* SPDX-License-Identifier: MIT                                               */
/* Copyright (c) [2023] Serokell <hi@serokell.io>                             */
/*                                                                            */
/******************************************************************************/
#![warn(clippy::redundant_clone)]
#![warn(missing_docs)]
#![deny(clippy::disallowed_methods)]

//! # M.I.R. -- Michelson in Rust
//!
//! Rust implementation of the typechecker and interpreter for the Michelson
//! smart contract language.
//!
//! The library is currently incomplete. The following instructions are not
//! supported:
//!
//! - `EMPTY_MAP`
//! - `SAPLING_EMPTY_STATE`
//! - `SAPLING_VERIFY_UPDATE`
//! - `OPEN_CHEST`
//! - `VIEW`
//!
//! The following types are currently not supported:
//!
//! - `chest`
//! - `chest_key`
//! - `tx_rollup_l2_address`
//! - `sapling_state`
//! - `sapling_transaction`
//!
//! # Usage
//!
//! The general pipeline is as follows: parse → typecheck → interpret →
//! serialize result.
//!
//! There are essentially two parsers available, one, in [parser::Parser], which
//! can be used to parse Michelson source code from strings. Another one is
//! implemented as [ast::Micheline::decode_raw], which can be used to
//! deserialize Michelson from bytes.
//!
//! Whether parsed from string or bytes, the result of a parse is
//! [ast::Micheline]. Since Micheline can represent any part of a Michelson
//! script, several associated functions exist for typechecking:
//!
//! - [ast::Micheline::typecheck_value] can be used to typecheck a Michelson
//!   value, e.g. `1` or `Some "string"`.
//! - [ast::Micheline::typecheck_instruction] can be used to typecheck a Michelson
//!   instruction or a sequence of instructions.
//! - [ast::Micheline::typecheck_script] can be used to typecheck a full
//!   Michelson script, i.e. something that defines `parameter`, `storage` and
//!   `code` fields.
//!
//! Any of these functions requires a reference to the external context,
//! [context::Ctx]. Context keeps track of the used gas, and also carries
//! information about the world outside of the interpreter. You can construct a
//! context with reasonable defaults using [`context::Ctx::default()`]. After that, you
//! may want to adjust some things. Refer to [context::Ctx] documentation.
//!
//! Once `Micheline` is typechecked, it will result in either [ast::TypedValue],
//! [ast::Instruction], or [ast::ContractScript]. The latter two have
//! [ast::Instruction::interpret] and [ast::ContractScript::interpret]
//! associated functions that serve as main entry-points for the interpreter.
//!
//! The result of interpretation is either a [ast::TypedValue] or a stack of
//! them. [ast::IntoMicheline::into_micheline_optimized_legacy] can be used to
//! convert [ast::TypedValue] into [ast::Micheline], at which point,
//! [ast::Micheline::encode] can be employed to serialize the data.
//!
//! Some functions require access to a [typed_arena::Arena]. [parser::Parser]
//! already has one, so that one can be reused. If memory consumption is a
//! concern, and depending on the workload, it may be slightly more economical
//! to create a new `Arena` for different stages.
//!
//! Here's a simple example, running a Fibonacci contract:
//!
//! ```
//! use mir::ast::*;
//! use mir::context::Ctx;
//! use mir::parser::Parser;
//! use typed_arena::Arena;
//! let script = r#"
//! parameter nat;
//! storage int;
//! code { CAR ; INT ; PUSH int 0 ; DUP 2 ; GT ;
//!        IF { DIP { PUSH int -1 ; ADD } ;
//!             PUSH int 1 ;
//!             DUP 3 ;
//!             GT ;
//!             LOOP { SWAP ; DUP 2 ; ADD ; DIP 2 { PUSH int -1 ; ADD } ; DUP 3 ; GT } ;
//!             DIP { DROP 2 } }
//!           { DIP { DROP } };
//!         NIL operation;
//!         PAIR }
//! "#;
//! let parser = Parser::new();
//! let contract_micheline = parser.parse_top_level(script).unwrap();
//! let mut ctx = Ctx::default();
//! // You can change various things about the context here, see [Ctx]
//! // documentation.
//! let contract_typechecked = contract_micheline.typecheck_script(&mut ctx).unwrap();
//! // We construct parameter and storage manually, but you'd probably
//! // parse or deserialize them from some sort of input/storage, so we use
//! // parser and decoder respectively.
//! // Note that you can opt to use a new parser and/or a new arena for
//! // parameter and storage. However, they _must_ outlive `ctx`.
//! let parameter = parser.parse("123").unwrap();
//! let storage = Micheline::decode_raw(&parser.arena, &[0x00, 0x00]).unwrap(); // integer 0
//! // Note: the arena passed in here _must_ outlive `ctx`. We reuse the one
//! // from `parser` for simplicity, you may also opt to create a new one to
//! // potentially save a bit of memory (depends on the workload).
//! let (operations_iter, new_storage) = contract_typechecked
//!     .interpret(&mut ctx, &parser.arena, parameter, storage)
//!     .unwrap();
//! let TypedValue::Int(new_storage_int) = &new_storage else { unreachable!() };
//! assert_eq!(new_storage_int, &22698374052006863956975682u128.into());
//! assert_eq!(operations_iter.collect::<Vec<_>>(), vec![]);
//! // Arena passed in here does not need to outlive `ctx`. Could reuse the one
//! // from `parser` again, but we create a new one to mix things up. If you're
//! // not concerned about memory consumption, it may be faster to reuse the
//! // same arena everywhere.
//! let packed_new_storage = new_storage
//!     .into_micheline_optimized_legacy(&Arena::new())
//!     .encode();
//! assert_eq!(
//!     packed_new_storage,
//!     vec![0x00, 0x82, 0x81, 0x8d, 0xe6, 0xdf, 0x96, 0x8c, 0xad, 0xa5, 0xc5, 0xb4, 0xac, 0x02]
//! );
//! ```
//!
//! You can find more examples in
//! <https://gitlab.com/tezos/tezos/-/tree/master/contrib/mir/examples>

pub mod ast;
pub mod context;
pub mod gas;
pub mod interpreter;
pub mod irrefutable_match;
pub mod lexer;
pub mod parser;
pub mod stack;
pub mod syntax;
pub mod typechecker;
pub mod tzt;

#[cfg(test)]
mod tests {
    use crate::ast::micheline::test_helpers::*;
    use crate::ast::*;
    use crate::context::Ctx;
    use crate::gas::Gas;
    use crate::interpreter;
    use crate::parser::test_helpers::{parse, parse_contract_script};
    use crate::stack::{stk, tc_stk};
    use crate::typechecker;

    fn report_gas<R, F: FnOnce(&mut Ctx) -> R>(ctx: &mut Ctx, f: F) -> R {
        let initial_milligas = ctx.gas.milligas();
        let r = f(ctx);
        let gas_diff = initial_milligas - ctx.gas.milligas();
        println!("Gas consumed: {}.{:0>3}", gas_diff / 1000, gas_diff % 1000);
        r
    }

    #[test]
    fn interpret_test_expect_success() {
        let ast = parse(FIBONACCI_SRC).unwrap();
        let ast = ast
            .typecheck_instruction(&mut Ctx::default(), None, &[app!(nat)])
            .unwrap();
        let mut istack = stk![TypedValue::Nat(10)];
        assert!(ast.interpret(&mut Ctx::default(), &mut istack).is_ok());
        assert!(istack.len() == 1 && istack[0] == TypedValue::Int(55));
    }

    #[test]
    fn interpret_mumav_push_add() {
        let ast = parse("{ PUSH mumav 100; PUSH mumav 500; ADD }").unwrap();
        let mut ctx = Ctx::default();
        let ast = ast.typecheck_instruction(&mut ctx, None, &[]).unwrap();
        let mut istack = stk![];
        assert!(ast.interpret(&mut ctx, &mut istack).is_ok());
        assert_eq!(istack, stk![TypedValue::Mumav(600)]);
    }

    #[test]
    fn interpret_test_gas_consumption() {
        let ast = parse(FIBONACCI_SRC).unwrap();
        let ast = ast
            .typecheck_instruction(&mut Ctx::default(), None, &[app!(nat)])
            .unwrap();
        let mut istack = stk![TypedValue::Nat(5)];
        let mut ctx = Ctx::default();
        report_gas(&mut ctx, |ctx| {
            assert!(ast.interpret(ctx, &mut istack).is_ok());
        });
        assert_eq!(Gas::default().milligas() - ctx.gas.milligas(), 1359);
    }

    #[test]
    fn interpret_test_gas_out_of_gas() {
        let ast = parse(FIBONACCI_SRC).unwrap();
        let ast = ast
            .typecheck_instruction(&mut Ctx::default(), None, &[app!(nat)])
            .unwrap();
        let mut istack = stk![TypedValue::Nat(5)];
        let mut ctx = Ctx {
            gas: Gas::new(1),
            ..Ctx::default()
        };
        assert_eq!(
            ast.interpret(&mut ctx, &mut istack),
            Err(interpreter::InterpretError::OutOfGas(crate::gas::OutOfGas)),
        );
    }

    #[test]
    fn typecheck_test_expect_success() {
        let ast = parse(FIBONACCI_SRC).unwrap();
        let mut stack = tc_stk![Type::Nat];
        assert!(
            typechecker::typecheck_instruction(&ast, &mut Ctx::default(), None, &mut stack).is_ok()
        );
        assert_eq!(stack, tc_stk![Type::Int])
    }

    #[test]
    fn typecheck_gas() {
        let ast = parse(FIBONACCI_SRC).unwrap();
        let mut ctx = Ctx::default();
        let start_milligas = ctx.gas.milligas();
        report_gas(&mut ctx, |ctx| {
            assert!(ast.typecheck_instruction(ctx, None, &[app!(nat)]).is_ok());
        });
        assert_eq!(start_milligas - ctx.gas.milligas(), 12680);
    }

    #[test]
    fn typecheck_out_of_gas() {
        let ast = parse(FIBONACCI_SRC).unwrap();
        let mut ctx = Ctx {
            gas: Gas::new(1000),
            ..Ctx::default()
        };
        assert_eq!(
            ast.typecheck_instruction(&mut ctx, None, &[app!(nat)]),
            Err(typechecker::TcError::OutOfGas(crate::gas::OutOfGas))
        );
    }

    #[test]
    fn typecheck_test_expect_fail() {
        use typechecker::{NoMatchingOverloadReason, TcError};
        let ast = parse(FIBONACCI_ILLTYPED_SRC).unwrap();
        assert_eq!(
            ast.typecheck_instruction(&mut Ctx::default(), None, &[app!(nat)]),
            Err(TcError::NoMatchingOverload {
                instr: crate::lexer::Prim::DUP,
                stack: stk![Type::Int, Type::Int, Type::Int],
                reason: Some(NoMatchingOverloadReason::StackTooShort { expected: 4 })
            })
        );
    }

    #[test]
    fn parser_test_expect_success() {
        use crate::ast::micheline::test_helpers::*;

        let ast = parse(FIBONACCI_SRC).unwrap();
        // use built in pretty printer to validate the expected AST.
        assert_eq!(
            ast,
            seq! {
                app!(INT);
                app!(PUSH[app!(int), 0]);
                app!(DUP[2]);
                app!(GT);
                app!(IF[
                    seq!{
                        app!(DIP[seq!{app!(PUSH[app!(int), -1]); app!(ADD) }]);
                        app!(PUSH[app!(int), 1]);
                        app!(DUP[3]);
                        app!(GT);
                        app!(LOOP[seq!{
                            app!(SWAP);
                            app!(DUP[2]);
                            app!(ADD);
                            app!(DIP[2, seq!{
                                app!(PUSH[app!(int), -1]);
                                app!(ADD)
                            }]);
                            app!(DUP[3]);
                            app!(GT);
                        }]);
                        app!(DIP[seq!{app!(DROP[2])}]);
                    },
                    seq!{
                        app!(DIP[seq!{ app!(DROP) }])
                    },
                ]);
            }
        );
    }

    #[test]
    fn parser_test_expect_fail() {
        use crate::ast::micheline::test_helpers::app;
        assert_eq!(
            parse(FIBONACCI_MALFORMED_SRC)
                .unwrap()
                .typecheck_instruction(&mut Ctx::default(), None, &[app!(nat)]),
            Err(typechecker::TcError::UnexpectedMicheline(format!(
                "{:?}",
                app!(DUP[4, app!(GT)])
            )))
        );
    }

    #[test]
    fn parser_test_dip_dup_drop_args() {
        use crate::ast::micheline::test_helpers::*;

        assert_eq!(parse("DROP 1023"), Ok(app!(DROP[1023])));
        assert_eq!(parse("DIP 1023 {}"), Ok(app!(DIP[1023, seq!{}])));
        assert_eq!(parse("DUP 1023"), Ok(app!(DUP[1023])));
    }

    #[test]
    fn vote_contract() {
        use crate::ast::micheline::test_helpers::*;
        let mut ctx = Ctx {
            amount: 5_000_000,
            ..Ctx::default()
        };
        let interp_res = parse_contract_script(VOTE_SRC)
            .unwrap()
            .typecheck_script(&mut ctx)
            .unwrap()
            .interpret(
                &mut ctx,
                "foo".into(),
                seq! {app!(Elt["bar", 0]); app!(Elt["baz", 0]); app!(Elt["foo", 0])},
            );
        use TypedValue as TV;
        match interp_res.unwrap() {
            (_, TV::Map(m)) => {
                assert_eq!(m.get(&TV::String("foo".to_owned())).unwrap(), &TV::Int(1))
            }
            _ => panic!("unexpected contract output"),
        }
    }

    const FIBONACCI_SRC: &str = "{ INT ; PUSH int 0 ; DUP 2 ; GT ;
           IF { DIP { PUSH int -1 ; ADD } ;
            PUSH int 1 ;
            DUP 3 ;
            GT ;
            LOOP { SWAP ; DUP 2 ; ADD ; DIP 2 { PUSH int -1 ; ADD } ; DUP 3 ; GT } ;
            DIP { DROP 2 } }
          { DIP { DROP } } }";

    const FIBONACCI_ILLTYPED_SRC: &str = "{ INT ; PUSH int 0 ; DUP 2 ; GT ;
           IF { DIP { PUSH int -1 ; ADD } ;
            PUSH int 1 ;
            DUP 4 ;
            GT ;
            LOOP { SWAP ; DUP 2 ; ADD ; DIP 2 { PUSH int -1 ; ADD } ; DUP 3 ; GT } ;
            DIP { DROP 2 } }
          { DIP { DROP } } }";

    const FIBONACCI_MALFORMED_SRC: &str = "{ INT ; PUSH int 0 ; DUP 2 ; GT ;
           IF { DIP { PUSH int -1 ; ADD } ;
            PUSH int 1 ;
            DUP 4
            GT ;
            LOOP { SWAP ; DUP 2 ; ADD ; DIP 2 { PUSH int -1 ; ADD } ; DUP 3 ; GT } ;
            DIP { DROP 2 } }
          { DIP { DROP } } }";

    const VOTE_SRC: &str = "{
          parameter (string %vote);
          storage (map string int);
          code {
              AMOUNT;
              PUSH mumav 5000000;
              COMPARE; GT;
              IF { { UNIT; FAILWITH } } {};
              DUP; DIP { CDR; DUP }; CAR; DUP;
              DIP {
                  GET; { IF_NONE { { UNIT ; FAILWITH } } {} };
                  PUSH int 1; ADD; SOME
              };
              UPDATE;
              NIL operation; PAIR
          }
      }";
}
