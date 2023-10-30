meta:
  id: id_012__psithaca__receipt__balance_updates
  endian: be
doc: ! 'Encoding id: 012-Psithaca.receipt.balance_updates'
types:
  id_012__psithaca__operation_metadata__alpha__balance_updates:
    seq:
    - id: size_of_id_012__psithaca__operation_metadata__alpha__balance_updates
      type: u4
      valid:
        max: 1073741823
    - id: id_012__psithaca__operation_metadata__alpha__balance_updates
      type: id_012__psithaca__operation_metadata__alpha__balance_updates_entries
      size: size_of_id_012__psithaca__operation_metadata__alpha__balance_updates
      repeat: eos
  id_012__psithaca__operation_metadata__alpha__balance_updates_entries:
    seq:
    - id: id_012__psithaca__operation_metadata__alpha__balance
      type: id_012__psithaca__operation_metadata__alpha__balance
    - id: id_012__psithaca__operation_metadata__alpha__balance_update
      type: s8
    - id: id_012__psithaca__operation_metadata__alpha__update_origin
      type: u1
      enum: origin_tag
  id_012__psithaca__operation_metadata__alpha__balance:
    seq:
    - id: id_012__psithaca__operation_metadata__alpha__balance_tag
      type: u1
      enum: id_012__psithaca__operation_metadata__alpha__balance_tag
    - id: commitments__id_012__psithaca__operation_metadata__alpha__balance
      size: 20
      if: (id_012__psithaca__operation_metadata__alpha__balance_tag == id_012__psithaca__operation_metadata__alpha__balance_tag::commitments)
  lost_endorsing_rewards__id_012__psithaca__operation_metadata__alpha__balance:
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
  legacy_fees__id_012__psithaca__operation_metadata__alpha__balance:
    seq:
    - id: delegate
      type: legacy_fees__public_key_hash
      doc: A Ed25519, Secp256k1, or P256 public key hash
    - id: cycle
      type: s4
  legacy_fees__public_key_hash:
    seq:
    - id: public_key_hash_tag
      type: u1
      enum: public_key_hash_tag
    - id: legacy_fees__p256__public_key_hash
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
  legacy_deposits__id_012__psithaca__operation_metadata__alpha__balance:
    seq:
    - id: delegate
      type: legacy_deposits__public_key_hash
      doc: A Ed25519, Secp256k1, or P256 public key hash
    - id: cycle
      type: s4
  legacy_deposits__public_key_hash:
    seq:
    - id: public_key_hash_tag
      type: u1
      enum: public_key_hash_tag
    - id: legacy_deposits__p256__public_key_hash
      size: 20
      if: (public_key_hash_tag == public_key_hash_tag::p256)
  legacy_rewards__id_012__psithaca__operation_metadata__alpha__balance:
    seq:
    - id: delegate
      type: legacy_rewards__public_key_hash
      doc: A Ed25519, Secp256k1, or P256 public key hash
    - id: cycle
      type: s4
  legacy_rewards__public_key_hash:
    seq:
    - id: public_key_hash_tag
      type: u1
      enum: public_key_hash_tag
    - id: legacy_rewards__p256__public_key_hash
      size: 20
      if: (public_key_hash_tag == public_key_hash_tag::p256)
  contract__id_012__psithaca__contract_id:
    seq:
    - id: id_012__psithaca__contract_id_tag
      type: u1
      enum: id_012__psithaca__contract_id_tag
    - id: contract__implicit__id_012__psithaca__contract_id
      type: contract__implicit__public_key_hash
      if: (id_012__psithaca__contract_id_tag == id_012__psithaca__contract_id_tag::implicit)
      doc: A Ed25519, Secp256k1, or P256 public key hash
    - id: contract__originated__id_012__psithaca__contract_id
      type: contract__originated__id_012__psithaca__contract_id
      if: (id_012__psithaca__contract_id_tag == id_012__psithaca__contract_id_tag::originated)
  contract__originated__id_012__psithaca__contract_id:
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
  bool:
    0: false
    255: true
  public_key_hash_tag:
    0: ed25519
    1: secp256k1
    2: p256
  id_012__psithaca__contract_id_tag:
    0: implicit
    1: originated
  id_012__psithaca__operation_metadata__alpha__balance_tag:
    0: contract
    1: legacy_rewards
    2: block_fees
    3: legacy_deposits
    4: deposits
    5: nonce_revelation_rewards
    6: double_signing_evidence_rewards
    7: endorsing_rewards
    8: baking_rewards
    9: baking_bonuses
    10: legacy_fees
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
seq:
- id: id_012__psithaca__operation_metadata__alpha__balance_updates
  type: id_012__psithaca__operation_metadata__alpha__balance_updates
