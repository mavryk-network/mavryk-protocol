meta:
  id: id_009__psfloren__receipt__balance_updates
  endian: be
doc: ! 'Encoding id: 009-PsFLoren.receipt.balance_updates'
types:
  id_009__psfloren__operation_metadata__alpha__balance_updates:
    seq:
    - id: size_of_id_009__psfloren__operation_metadata__alpha__balance_updates
      type: u4
      valid:
        max: 1073741823
    - id: id_009__psfloren__operation_metadata__alpha__balance_updates
      type: id_009__psfloren__operation_metadata__alpha__balance_updates_entries
      size: size_of_id_009__psfloren__operation_metadata__alpha__balance_updates
      repeat: eos
  id_009__psfloren__operation_metadata__alpha__balance_updates_entries:
    seq:
    - id: id_009__psfloren__operation_metadata__alpha__balance
      type: id_009__psfloren__operation_metadata__alpha__balance
    - id: id_009__psfloren__operation_metadata__alpha__balance_update
      type: s8
    - id: id_009__psfloren__operation_metadata__alpha__update_origin
      type: u1
      enum: origin_tag
  id_009__psfloren__operation_metadata__alpha__balance:
    seq:
    - id: id_009__psfloren__operation_metadata__alpha__balance_tag
      type: u1
      enum: id_009__psfloren__operation_metadata__alpha__balance_tag
    - id: contract__id_009__psfloren__operation_metadata__alpha__balance
      type: contract__id_009__psfloren__contract_id
      if: (id_009__psfloren__operation_metadata__alpha__balance_tag == id_009__psfloren__operation_metadata__alpha__balance_tag::contract)
      doc: ! >-
        A contract handle: A contract notation as given to an RPC or inside scripts.
        Can be a base58 implicit contract hash or a base58 originated contract hash.
    - id: rewards__id_009__psfloren__operation_metadata__alpha__balance
      type: rewards__id_009__psfloren__operation_metadata__alpha__balance
      if: (id_009__psfloren__operation_metadata__alpha__balance_tag == id_009__psfloren__operation_metadata__alpha__balance_tag::rewards)
    - id: fees__id_009__psfloren__operation_metadata__alpha__balance
      type: fees__id_009__psfloren__operation_metadata__alpha__balance
      if: (id_009__psfloren__operation_metadata__alpha__balance_tag == id_009__psfloren__operation_metadata__alpha__balance_tag::fees)
    - id: deposits__id_009__psfloren__operation_metadata__alpha__balance
      type: deposits__id_009__psfloren__operation_metadata__alpha__balance
      if: (id_009__psfloren__operation_metadata__alpha__balance_tag == id_009__psfloren__operation_metadata__alpha__balance_tag::deposits)
  deposits__id_009__psfloren__operation_metadata__alpha__balance:
    seq:
    - id: delegate
      type: deposits__public_key_hash
      doc: A Ed25519, Secp256k1, or P256 public key hash
    - id: cycle
      type: s4
  deposits__public_key_hash:
    seq:
    - id: public_key_hash_tag
      type: u1
      enum: public_key_hash_tag
    - id: deposits__p256__public_key_hash
      size: 20
      if: (public_key_hash_tag == public_key_hash_tag::p256)
  fees__id_009__psfloren__operation_metadata__alpha__balance:
    seq:
    - id: delegate
      type: fees__public_key_hash
      doc: A Ed25519, Secp256k1, or P256 public key hash
    - id: cycle
      type: s4
  fees__public_key_hash:
    seq:
    - id: public_key_hash_tag
      type: u1
      enum: public_key_hash_tag
    - id: fees__p256__public_key_hash
      size: 20
      if: (public_key_hash_tag == public_key_hash_tag::p256)
  rewards__id_009__psfloren__operation_metadata__alpha__balance:
    seq:
    - id: delegate
      type: rewards__public_key_hash
      doc: A Ed25519, Secp256k1, or P256 public key hash
    - id: cycle
      type: s4
  rewards__public_key_hash:
    seq:
    - id: public_key_hash_tag
      type: u1
      enum: public_key_hash_tag
    - id: rewards__p256__public_key_hash
      size: 20
      if: (public_key_hash_tag == public_key_hash_tag::p256)
  contract__id_009__psfloren__contract_id:
    seq:
    - id: id_009__psfloren__contract_id_tag
      type: u1
      enum: id_009__psfloren__contract_id_tag
    - id: contract__implicit__id_009__psfloren__contract_id
      type: contract__implicit__public_key_hash
      if: (id_009__psfloren__contract_id_tag == id_009__psfloren__contract_id_tag::implicit)
      doc: A Ed25519, Secp256k1, or P256 public key hash
    - id: contract__originated__id_009__psfloren__contract_id
      type: contract__originated__id_009__psfloren__contract_id
      if: (id_009__psfloren__contract_id_tag == id_009__psfloren__contract_id_tag::originated)
  contract__originated__id_009__psfloren__contract_id:
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
  public_key_hash_tag:
    0: ed25519
    1: secp256k1
    2: p256
  id_009__psfloren__contract_id_tag:
    0: implicit
    1: originated
  id_009__psfloren__operation_metadata__alpha__balance_tag:
    0: contract
    1: rewards
    2: fees
    3: deposits
seq:
- id: id_009__psfloren__operation_metadata__alpha__balance_updates
  type: id_009__psfloren__operation_metadata__alpha__balance_updates
