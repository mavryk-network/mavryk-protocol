use super::TypedValue;

impl PartialOrd for TypedValue {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        use TypedValue::*;
        match (self, other) {
            (Int(a), Int(b)) => a.partial_cmp(b),
            (Int(..), _) => None,

            (Nat(a), Nat(b)) => a.partial_cmp(b),
            (Nat(..), _) => None,

            (Mumav(a), Mumav(b)) => a.partial_cmp(b),
            (Mumav(..), _) => None,

            (Bool(a), Bool(b)) => a.partial_cmp(b),
            (Bool(..), _) => None,

            (String(a), String(b)) => a.partial_cmp(b),
            (String(..), _) => None,

            (Unit, Unit) => Some(std::cmp::Ordering::Equal),
            (Unit, _) => None,

            (Pair(l), Pair(r)) => l.partial_cmp(r),
            (Pair(..), _) => None,

            (Option(x), Option(y)) => x.as_deref().partial_cmp(&y.as_deref()),
            (Option(..), _) => None,

            (Or(x), Or(y)) => x.as_ref().partial_cmp(y.as_ref()),
            (Or(..), _) => None,

            (Address(l), Address(r)) => l.partial_cmp(r),
            (Address(..), _) => None,

            (ChainId(l), ChainId(r)) => l.partial_cmp(r),
            (ChainId(..), _) => None,

            // non-comparable types
            (List(..) | Map(..) | Contract(..), _) => None,
        }
    }
}

impl Ord for TypedValue {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        self.partial_cmp(other)
            .expect("Comparing incomparable values in TypedValue")
    }
}

#[cfg(test)]
mod tests {
    use mavryk_crypto_rs::hash::HashTrait;

    use super::*;

    #[test]
    fn compare() {
        use TypedValue as V;
        use TypedValue::*;
        macro_rules! assert_cmp {
            ($c:expr; $($l:expr),*; $($r:expr),*; $ord:ident) => {
                assert!($c($($l),*).partial_cmp(&$c($($r),*)) == Some(std::cmp::Ordering::$ord));
                assert!($c($($l),*).cmp(&$c($($r),*)) == std::cmp::Ordering::$ord);
            };
        }

        assert_cmp!(Int; -1; 0; Less);
        assert_cmp!(Int; -1; -1; Equal);
        assert_cmp!(Int; -1; -2; Greater);

        assert_cmp!(Nat; 3; 4; Less);
        assert_cmp!(Nat; 4; 4; Equal);
        assert_cmp!(Nat; 5; 4; Greater);

        assert_cmp!(Mumav; 3; 4; Less);
        assert_cmp!(Mumav; 3; 3; Equal);
        assert_cmp!(Mumav; 32; 4; Greater);

        assert_cmp!(Bool; false; false; Equal);
        assert_cmp!(Bool; false; true; Less);
        assert_cmp!(Bool; true; false; Greater);
        assert_cmp!(Bool; true; true; Equal);

        assert_cmp!(String; "hello".to_owned(); "iello".to_owned(); Less);
        assert_cmp!(String; "a".to_owned(); "bfoo".to_owned(); Less);
        assert_cmp!(String; "afoo".to_owned(); "b".to_owned(); Less);
        assert_cmp!(String; "foo".to_owned(); "foo".to_owned(); Equal);
        assert_cmp!(String; "foo".to_owned(); "bar".to_owned(); Greater);

        assert_cmp!(V::new_option; None; None; Equal);
        assert_cmp!(V::new_option; None; Some(Int(3)); Less);
        assert_cmp!(V::new_option; Some(Int(3)); None; Greater);
        assert_cmp!(V::new_option; Some(Int(3)); Some(Int(4)); Less);
        assert_cmp!(V::new_option; Some(Int(4)); Some(Int(4)); Equal);
        assert_cmp!(V::new_option; Some(Int(4)); Some(Int(3)); Greater);

        assert_cmp!(V::new_pair; Int(3), Nat(4); Int(3), Nat(5); Less);
        assert_cmp!(V::new_pair; Int(3), Nat(4); Int(4), Nat(4); Less);
        assert_cmp!(V::new_pair; Int(3), Nat(4); Int(3), Nat(4); Equal);
        assert_cmp!(V::new_pair; Int(4), Nat(4); Int(3), Nat(4); Greater);
        assert_cmp!(V::new_pair; Int(3), Nat(5); Int(3), Nat(4); Greater);

        use crate::ast::Or;

        assert_cmp!(V::new_or; Or::Left(Int(3)); Or::Left(Int(4)); Less);
        assert_cmp!(V::new_or; Or::Left(Int(5)); Or::Left(Int(4)); Greater);
        assert_cmp!(V::new_or; Or::Left(Int(4)); Or::Left(Int(4)); Equal);
        assert_cmp!(V::new_or; Or::Right(Int(3)); Or::Right(Int(4)); Less);
        assert_cmp!(V::new_or; Or::Right(Int(5)); Or::Right(Int(4)); Greater);
        assert_cmp!(V::new_or; Or::Right(Int(4)); Or::Right(Int(4)); Equal);
        assert_cmp!(V::new_or; Or::Left(Int(5)); Or::Right(Int(3)); Less);
        assert_cmp!(V::new_or; Or::Right(Int(3)); Or::Left(Int(5)); Greater);

        // different types don't compare
        assert_eq!(Bool(true).partial_cmp(&Int(5)), None);
    }

    #[test]
    fn compare_addrs() {
        // ordering was verified against mavkit-client, see script below
        let ordered_addrs = [
            "mv1TbDxBB8N5k4CvwDKrgJ2aeDQ6dGgYm5uq",
            "mv1TCgPv2w81gDfp7cLY5ohESufwJqqrV2K9",
            "mv1CgijVVqTSPtzACGGroFqhyGWet82JnDcQ",
            "mv1SBut28idjAnU5qAfZW7j1oxomL9ABfgb3",
            "mv1DWi3SvRpq3QydtukomxLEwtydLRTzfpse%bar",
            "mv1DWi3SvRpq3QydtukomxLEwtydLRTzfpse%defauls",
            "mv1DWi3SvRpq3QydtukomxLEwtydLRTzfpse",
            "mv1DWi3SvRpq3QydtukomxLEwtydLRTzfpse%defaulu",
            "mv1DWi3SvRpq3QydtukomxLEwtydLRTzfpse%foo",
            "mv1RU12shPetXpVMsHMFJD9bCa6mKMwFAVG4",
            "mv2PC6q5GhTmtVLjt5jMmdPcHpVbBss2yBst%bar",
            "mv2PC6q5GhTmtVLjt5jMmdPcHpVbBss2yBst",
            "mv2PC6q5GhTmtVLjt5jMmdPcHpVbBss2yBst%foo",
            "mv3TG4fsbRnmMFRmd87AcqyWzqTVEaBbQ85g%bar",
            "mv3TG4fsbRnmMFRmd87AcqyWzqTVEaBbQ85g",
            "mv3TG4fsbRnmMFRmd87AcqyWzqTVEaBbQ85g%foo",
            "mv4YhGYGC1Rc73raRoQrpTv4SoDzVbQSH9ib%bar",
            "mv4YhGYGC1Rc73raRoQrpTv4SoDzVbQSH9ib",
            "mv4YhGYGC1Rc73raRoQrpTv4SoDzVbQSH9ib%foo",
            "KT1BRd2ka5q2cPRdXALtXD1QZ38CPam2j1ye%bar",
            "KT1BRd2ka5q2cPRdXALtXD1QZ38CPam2j1ye",
            "KT1BRd2ka5q2cPRdXALtXD1QZ38CPam2j1ye%foo",
            "sr1RYurGZtN8KNSpkMcCt9CgWeUaNkzsAfXf%bar",
            "sr1RYurGZtN8KNSpkMcCt9CgWeUaNkzsAfXf",
            "sr1RYurGZtN8KNSpkMcCt9CgWeUaNkzsAfXf%foo",
        ]
        .map(|x| TypedValue::Address(crate::ast::Address::from_base58_check(x).unwrap()));

        for (i, addr_i) in ordered_addrs.iter().enumerate() {
            for (j, addr_j) in ordered_addrs.iter().enumerate() {
                assert_eq!(addr_i.partial_cmp(addr_j), i.partial_cmp(&j));
                assert_eq!(addr_i.cmp(addr_j), i.cmp(&j));
            }
        }
    }

    #[test]
    /// checks that an array of chain ids is sorted without a priori assuming
    /// that the comparison operator on chain ids is transitive.
    fn compare_chain_ids() {
        // ordering was verified against mavkit-client
        let ordered_chain_ids = [
            "00000000", "00000001", "00000002", "00000100", "00000200", "01020304", "a0b0c0d0",
            "a1b2c3d4", "ffffffff",
        ]
        .map(|x| {
            TypedValue::ChainId(
                mavryk_crypto_rs::hash::ChainId::try_from_bytes(&hex::decode(x).unwrap()).unwrap(),
            )
        });

        for (i, addr_i) in ordered_chain_ids.iter().enumerate() {
            for (j, addr_j) in ordered_chain_ids.iter().enumerate() {
                assert_eq!(addr_i.partial_cmp(addr_j), i.partial_cmp(&j));
                assert_eq!(addr_i.cmp(addr_j), i.cmp(&j));
            }
        }
    }

    #[test]
    #[should_panic(expected = "Comparing incomparable values in TypedValue")]
    fn compare_different_comparable() {
        // Comparable panics on different types
        use TypedValue::*;
        let _ = Bool(true).cmp(&Int(5)); //panics
    }
}

/*
Script to verify address ordering. Should print "with -1" for all checked address pairs.

```
#!/bin/bash

addrs=(
  "mv1TbDxBB8N5k4CvwDKrgJ2aeDQ6dGgYm5uq"
  "mv1TCgPv2w81gDfp7cLY5ohESufwJqqrV2K9"
  "mv1CgijVVqTSPtzACGGroFqhyGWet82JnDcQ"
  "mv1SBut28idjAnU5qAfZW7j1oxomL9ABfgb3"
  "mv1DWi3SvRpq3QydtukomxLEwtydLRTzfpse%bar"
  "mv1DWi3SvRpq3QydtukomxLEwtydLRTzfpse%defauls"
  "mv1DWi3SvRpq3QydtukomxLEwtydLRTzfpse"
  "mv1DWi3SvRpq3QydtukomxLEwtydLRTzfpse%defaulu"
  "mv1DWi3SvRpq3QydtukomxLEwtydLRTzfpse%foo"
  "mv1RU12shPetXpVMsHMFJD9bCa6mKMwFAVG4"
  "mv2PC6q5GhTmtVLjt5jMmdPcHpVbBss2yBst%bar"
  "mv2PC6q5GhTmtVLjt5jMmdPcHpVbBss2yBst"
  "mv2PC6q5GhTmtVLjt5jMmdPcHpVbBss2yBst%foo"
  "mv3TG4fsbRnmMFRmd87AcqyWzqTVEaBbQ85g%bar"
  "mv3TG4fsbRnmMFRmd87AcqyWzqTVEaBbQ85g"
  "mv3TG4fsbRnmMFRmd87AcqyWzqTVEaBbQ85g%foo"
  "mv4YhGYGC1Rc73raRoQrpTv4SoDzVbQSH9ib%bar"
  "mv4YhGYGC1Rc73raRoQrpTv4SoDzVbQSH9ib"
  "mv4YhGYGC1Rc73raRoQrpTv4SoDzVbQSH9ib%foo"
  "KT1BRd2ka5q2cPRdXALtXD1QZ38CPam2j1ye%bar"
  "KT1BRd2ka5q2cPRdXALtXD1QZ38CPam2j1ye"
  "KT1BRd2ka5q2cPRdXALtXD1QZ38CPam2j1ye%foo"
  "sr1RYurGZtN8KNSpkMcCt9CgWeUaNkzsAfXf%bar"
  "sr1RYurGZtN8KNSpkMcCt9CgWeUaNkzsAfXf"
  "sr1RYurGZtN8KNSpkMcCt9CgWeUaNkzsAfXf%foo"
)

prev=""
for addr in "${addrs[@]}"; do
  if [ -n "$prev" ]; then
    echo $prev $addr
    mavkit-client --mode mockup run script 'parameter address; storage address; code { UNPAIR; SWAP; COMPARE; FAILWITH }' on storage "\"$prev\"" and input "\"$addr\"" 2>&1 | grep '^with'
  fi
  prev="$addr"
done
```
*/
