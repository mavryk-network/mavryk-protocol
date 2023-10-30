meta:
  id: id_014__ptkathma__receipt__balance_updates
  endian: be
doc: ! 'Encoding id: 014-PtKathma.receipt.balance_updates'
types:
  id_014__ptkathma__operation_metadata__alpha__balance_updates:
    seq:
    - id: size_of_id_014__ptkathma__operation_metadata__alpha__balance_updates
      type: u4
      valid:
        max: 1073741823
    - id: id_014__ptkathma__operation_metadata__alpha__balance_updates
      type: id_014__ptkathma__operation_metadata__alpha__balance_updates_entries
      size: size_of_id_014__ptkathma__operation_metadata__alpha__balance_updates
      repeat: eos
  id_014__ptkathma__operation_metadata__alpha__balance_updates_entries:
    seq:
    - id: id_014__ptkathma__operation_metadata__alpha__balance
      type: id_014__ptkathma__operation_metadata__alpha__balance
    - id: id_014__ptkathma__operation_metadata__alpha__balance_update
      type: s8
    - id: id_014__ptkathma__operation_metadata__alpha__update_origin
      type: u1
      enum: origin_tag
  id_014__ptkathma__operation_metadata__alpha__balance:
    seq:
    - id: id_014__ptkathma__operation_metadata__alpha__balance_tag
      type: u1
      enum: id_014__ptkathma__operation_metadata__alpha__balance_tag
    - id: commitments__id_014__ptkathma__operation_metadata__alpha__balance
      size: 20
      if: (id_014__ptkathma__operation_metadata__alpha__balance_tag == id_014__ptkathma__operation_metadata__alpha__balance_tag::commitments)
    - id: frozen_bonds__id_014__ptkathma__operation_metadata__alpha__balance
      type: frozen_bonds__id_014__ptkathma__operation_metadata__alpha__balance
      if: (id_014__ptkathma__operation_metadata__alpha__balance_tag == id_014__ptkathma__operation_metadata__alpha__balance_tag::frozen_bonds)
  frozen_bonds__id_014__ptkathma__operation_metadata__alpha__balance:
    seq:
    - id: contract
      type: frozen_bonds__id_014__ptkathma__contract_id
      doc: ! >-
        A contract handle: A contract notation as given to an RPC or inside scripts.
        Can be a base58 implicit contract hash or a base58 originated contract hash.
    - id: bond_id
      type: frozen_bonds__id_014__ptkathma__bond_id
  frozen_bonds__id_014__ptkathma__bond_id:
    seq:
    - id: id_014__ptkathma__bond_id_tag
      type: u1
      enum: id_014__ptkathma__bond_id_tag
    - id: frozen_bonds__sc_rollup_bond_id__id_014__ptkathma__bond_id
      type: frozen_bonds__sc_rollup_bond_id__id_014__ptkathma__rollup_address
      if: (id_014__ptkathma__bond_id_tag == id_014__ptkathma__bond_id_tag::sc_rollup_bond_id)
      doc: ! >-
        A smart contract rollup address: A smart contract rollup is identified by
        a base58 address starting with scr1
  frozen_bonds__sc_rollup_bond_id__id_014__ptkathma__rollup_address:
    seq:
    - id: size_of_id_014__ptkathma__rollup_address
      type: u4
      valid:
        max: 1073741823
    - id: id_014__ptkathma__rollup_address
      size: size_of_id_014__ptkathma__rollup_address
  frozen_bonds__id_014__ptkathma__contract_id:
    seq:
    - id: id_014__ptkathma__contract_id_tag
      type: u1
      enum: id_014__ptkathma__contract_id_tag
    - id: frozen_bonds__implicit__id_014__ptkathma__contract_id
      type: frozen_bonds__implicit__public_key_hash
      if: (id_014__ptkathma__contract_id_tag == id_014__ptkathma__contract_id_tag::implicit)
      doc: A Ed25519, Secp256k1, or P256 public key hash
    - id: frozen_bonds__originated__id_014__ptkathma__contract_id
      type: frozen_bonds__originated__id_014__ptkathma__contract_id
      if: (id_014__ptkathma__contract_id_tag == id_014__ptkathma__contract_id_tag::originated)
  frozen_bonds__originated__id_014__ptkathma__contract_id:
    seq:
    - id: contract_hash
      size: 20
    - id: originated_padding
      size: 1
      doc: This field is for padding, ignore
  frozen_bonds__implicit__public_key_hash:
    seq:
    - id: public_key_hash_tag
      type: u1
      enum: public_key_hash_tag
    - id: frozen_bonds__implicit__p256__public_key_hash
      size: 20
      if: (public_key_hash_tag == public_key_hash_tag::p256)
  lost_endorsing_rewards__id_014__ptkathma__operation_metadata__alpha__balance:
    seq:
    - id: delegate
      type: lost_endorsing_rewards__public_key_hash
      doc: A Ed25519, Secp256k1, or P256 public key hash
    - id: participation
      type: u1
      enum: bool
    - id: revelation
      type: u1
      enum: bool
  lost_endorsing_rewards__public_key_hash:
    seq:
    - id: public_key_hash_tag
      type: u1
      enum: public_key_hash_tag
    - id: lost_endorsing_rewards__p256__public_key_hash
      size: 20
      if: (public_key_hash_tag == public_key_hash_tag::p256)
  deposits__public_key_hash:
    seq:
    - id: public_key_hash_tag
      type: u1
      enum: public_key_hash_tag
    - id: deposits__p256__public_key_hash
      size: 20
      if: (public_key_hash_tag == public_key_hash_tag::p256)
  contract__id_014__ptkathma__contract_id:
    seq:
    - id: id_014__ptkathma__contract_id_tag
      type: u1
      enum: id_014__ptkathma__contract_id_tag
    - id: contract__implicit__id_014__ptkathma__contract_id
      type: contract__implicit__public_key_hash
      if: (id_014__ptkathma__contract_id_tag == id_014__ptkathma__contract_id_tag::implicit)
      doc: A Ed25519, Secp256k1, or P256 public key hash
    - id: contract__originated__id_014__ptkathma__contract_id
      type: contract__originated__id_014__ptkathma__contract_id
      if: (id_014__ptkathma__contract_id_tag == id_014__ptkathma__contract_id_tag::originated)
  contract__originated__id_014__ptkathma__contract_id:
    seq:
    - id: contract_hash
      size: 20
    - id: originated_padding
      size: 1
      doc: This field is for padding, ignore
  contract__implicit__public_key_hash:
    seq:
    - id: public_key_hash_tag
      type: u1
      enum: public_key_hash_tag
    - id: contract__implicit__p256__public_key_hash
      size: 20
      if: (public_key_hash_tag == public_key_hash_tag::p256)
enums:
  origin_tag:
    0: block_application
    1: protocol_migration
    2: subsidy
    3: simulation
  id_014__ptkathma__bond_id_tag:
    0: tx_rollup_bond_id
    1: sc_rollup_bond_id
  bool:
    0: false
    255: true
  public_key_hash_tag:
    0: ed25519
    1: secp256k1
    2: p256
  id_014__ptkathma__contract_id_tag:
    0: implicit
    1: originated
  id_014__ptkathma__operation_metadata__alpha__balance_tag:
    0: contract
    2: block_fees
    4: deposits
    5: nonce_revelation_rewards
    6: double_signing_evidence_rewards
    7: endorsing_rewards
    8: baking_rewards
    9: baking_bonuses
    11: storage_fees
    12: double_signing_punishments
    13: lost_endorsing_rewards
    14: liquidity_baking_subsidies
    15: burned
    16: commitments
    17: bootstrap
    18: invoice
    19: initial_commitments
    20: minted
    21: frozen_bonds
    22: tx_rollup_rejection_rewards
    23: tx_rollup_rejection_punishments
    24: sc_rollup_refutation_punishments
seq:
- id: id_014__ptkathma__operation_metadata__alpha__balance_updates
  type: id_014__ptkathma__operation_metadata__alpha__balance_updates
