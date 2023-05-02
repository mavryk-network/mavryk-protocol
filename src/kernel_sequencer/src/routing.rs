pub enum FilterBehavior {
    /// All message are accepted
    AllowAll,
    /// Only messages starting by the rollup address are accepted
    OnlyThisRollup,
}

impl FilterBehavior {
    /// Check if the message has to be processed by this rollup or not
    pub fn predicate(&self, payload: &[u8], rollup_address: &[u8]) -> bool {
        match self {
            FilterBehavior::AllowAll => true,
            FilterBehavior::OnlyThisRollup => {
                let splitted = payload.split_first();
                match splitted {
                    None => false,
                    Some((tag, remaining)) => match tag {
                        0x00 => {
                            // internal
                            match remaining {
                                [0x00, ..] => {
                                    // If it's a transfer then the last n bytes should be the rollup address
                                    remaining.ends_with(rollup_address)
                                }
                                _ => true, // All the internal messages are kept
                            }
                        }
                        0x01 => {
                            // All external messages should start by the rollup address
                            remaining.starts_with(rollup_address)
                        }
                        _ => {
                            // Unknown encoding
                            false
                        }
                    },
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use tezos_crypto_rs::hash::{BlockHash, ContractKt1Hash, HashTrait};
    use tezos_smart_rollup_encoding::{
        inbox::{InboxMessage, InfoPerLevel, InternalInboxMessage, Transfer},
        michelson::MichelsonUnit,
        public_key_hash::PublicKeyHash,
        smart_rollup::SmartRollupAddress,
        timestamp::Timestamp,
    };

    use super::FilterBehavior;

    fn address() -> SmartRollupAddress {
        SmartRollupAddress::from_b58check("sr1UNDWPUYVeomgG15wn5jSw689EJ4RNnVQa")
            .expect("decoding should work")
    }

    fn other_address() -> SmartRollupAddress {
        SmartRollupAddress::from_b58check("sr1UXY5i5Z1sF8xd8ZUyzur827MAaFWREzvj")
            .expect("decoding should work")
    }

    fn start_of_level() -> Vec<u8> {
        let start_of_level =
            InboxMessage::<MichelsonUnit>::Internal(InternalInboxMessage::StartOfLevel);
        let mut encoded = Vec::new();
        start_of_level
            .serialize(&mut encoded)
            .expect("encoding should work");
        encoded
    }

    fn end_of_level() -> Vec<u8> {
        let end_of_level =
            InboxMessage::<MichelsonUnit>::Internal(InternalInboxMessage::EndOfLevel);
        let mut encoded = Vec::new();
        end_of_level
            .serialize(&mut encoded)
            .expect("encoding should work");
        encoded
    }

    fn info_per_level() -> Vec<u8> {
        let predecessor =
            BlockHash::from_base58_check("BLockGenesisGenesisGenesisGenesisGenesisb83baZgbyZe")
                .expect("decoding should work");

        let info_per_level = InfoPerLevel {
            predecessor_timestamp: Timestamp::from(0),
            predecessor,
        };

        let info_per_level = InboxMessage::<MichelsonUnit>::Internal(
            InternalInboxMessage::InfoPerLevel(info_per_level),
        );
        let mut encoded = Vec::new();
        info_per_level
            .serialize(&mut encoded)
            .expect("encoding should work");
        encoded
    }

    fn transfer(rollup_address: &SmartRollupAddress) -> Vec<u8> {
        let transfer = Transfer {
            payload: MichelsonUnit {},
            sender: ContractKt1Hash::from_b58check("KT1NRLjyE7wxeSZ6La6DfuhSKCAAnc9Lnvdg")
                .expect("decoding should work"),
            source: PublicKeyHash::from_b58check("tz1bonDYXPijpBMA2kntUr87VqNe3oaLzpP1")
                .expect("decoding should work"),
            destination: rollup_address.clone(),
        };

        let transfer =
            InboxMessage::<MichelsonUnit>::Internal(InternalInboxMessage::Transfer(transfer));
        let mut encoded = Vec::new();
        transfer
            .serialize(&mut encoded)
            .expect("encoding should work");
        encoded
    }

    fn predicate(filter: FilterBehavior, msg: &[u8], rollup_address: &SmartRollupAddress) -> bool {
        let rollup_address_bytes = rollup_address.hash().as_ref();
        filter.predicate(&msg, &rollup_address_bytes)
    }

    #[test]
    fn test_allow_all_start_of_level() {
        assert!(predicate(
            FilterBehavior::AllowAll,
            &start_of_level(),
            &address(),
        ));
    }

    #[test]
    fn test_allow_all_end_of_level() {
        assert!(predicate(
            FilterBehavior::AllowAll,
            &end_of_level(),
            &address(),
        ));
    }

    #[test]
    fn test_allow_all_info_per_level() {
        assert!(predicate(
            FilterBehavior::AllowAll,
            &info_per_level(),
            &address(),
        ));
    }

    #[test]
    fn test_allow_all_transfer() {
        assert!(predicate(
            FilterBehavior::AllowAll,
            &transfer(&address()),
            &address(),
        ));
    }

    #[test]
    fn test_allow_all_external() {
        let external = [0x01, 0x0, 0x0];
        assert!(predicate(FilterBehavior::AllowAll, &external, &address(),));
    }

    #[test]
    fn test_only_this_rollup_start_of_level() {
        assert!(predicate(
            FilterBehavior::OnlyThisRollup,
            &start_of_level(),
            &address(),
        ));
    }

    #[test]
    fn test_only_this_rollup_info_per_level() {
        assert!(predicate(
            FilterBehavior::OnlyThisRollup,
            &info_per_level(),
            &address(),
        ));
    }

    #[test]
    fn test_only_this_rollup_end_of_level() {
        assert!(predicate(
            FilterBehavior::OnlyThisRollup,
            &end_of_level(),
            &address(),
        ));
    }

    #[test]
    fn test_only_this_rollup_accept_transfer() {
        assert!(predicate(
            FilterBehavior::OnlyThisRollup,
            &transfer(&address()),
            &address(),
        ));
    }

    #[test]
    fn test_only_this_rollup_refuse_transfer() {
        assert!(!predicate(
            FilterBehavior::OnlyThisRollup,
            &transfer(&other_address()),
            &address(),
        ));
    }

    #[test]
    fn test_only_this_rollup_accept_external() {
        let mut external = vec![0x01];
        let rollup_address = address();
        let mut rollup_address = rollup_address.hash().as_ref().clone();
        external.append(&mut rollup_address);

        assert!(predicate(
            FilterBehavior::OnlyThisRollup,
            &external,
            &address(),
        ));
    }

    #[test]
    fn test_only_this_rollup_refuse_external() {
        let mut external = vec![0x01];
        let rollup_address = other_address();
        let mut rollup_address = rollup_address.hash().as_ref().clone();
        external.append(&mut rollup_address);

        assert!(!predicate(
            FilterBehavior::OnlyThisRollup,
            &external,
            &address(),
        ));
    }
}
