meta:
  id: id_009__psfloren__operation__internal
  endian: be
doc: ! 'Encoding id: 009-PsFLoren.operation.internal'
types:
  id_009__psfloren__operation__alpha__internal_operation:
    seq:
    - id: source
      type: id_009__psfloren__contract_id
      doc: ! >-
        A contract handle: A contract notation as given to an RPC or inside scripts.
        Can be a base58 implicit contract hash or a base58 originated contract hash.
    - id: nonce
      type: u2
    - id: id_009__psfloren__operation__alpha__internal_operation_tag
      type: u1
      enum: id_009__psfloren__operation__alpha__internal_operation_tag
    - id: reveal__id_009__psfloren__operation__alpha__internal_operation
      type: reveal__public_key
      if: (id_009__psfloren__operation__alpha__internal_operation_tag == id_009__psfloren__operation__alpha__internal_operation_tag::reveal)
      doc: A Ed25519, Secp256k1, or P256 public key
    - id: transaction__id_009__psfloren__operation__alpha__internal_operation
      type: transaction__id_009__psfloren__operation__alpha__internal_operation
      if: (id_009__psfloren__operation__alpha__internal_operation_tag == id_009__psfloren__operation__alpha__internal_operation_tag::transaction)
    - id: origination__id_009__psfloren__operation__alpha__internal_operation
      type: origination__id_009__psfloren__operation__alpha__internal_operation
      if: (id_009__psfloren__operation__alpha__internal_operation_tag == id_009__psfloren__operation__alpha__internal_operation_tag::origination)
    - id: delegation__id_009__psfloren__operation__alpha__internal_operation
      type: delegation__id_009__psfloren__operation__alpha__internal_operation
      if: (id_009__psfloren__operation__alpha__internal_operation_tag == id_009__psfloren__operation__alpha__internal_operation_tag::delegation)
  delegation__id_009__psfloren__operation__alpha__internal_operation:
    seq:
    - id: delegate_tag
      type: u1
      enum: bool
    - id: delegate
      type: delegation__public_key_hash
      if: (delegate_tag == bool::true)
      doc: A Ed25519, Secp256k1, or P256 public key hash
  delegation__public_key_hash:
    seq:
    - id: public_key_hash_tag
      type: u1
      enum: public_key_hash_tag
    - id: delegation__p256__public_key_hash
      size: 20
      if: (public_key_hash_tag == public_key_hash_tag::p256)
  origination__id_009__psfloren__operation__alpha__internal_operation:
    seq:
    - id: balance
      type: n
    - id: delegate_tag
      type: u1
      enum: bool
    - id: delegate
      type: origination__public_key_hash
      if: (delegate_tag == bool::true)
      doc: A Ed25519, Secp256k1, or P256 public key hash
    - id: script
      type: origination__id_009__psfloren__scripted__contracts
  origination__id_009__psfloren__scripted__contracts:
    seq:
    - id: origination__code
      type: origination__code
    - id: origination__storage
      type: origination__storage
  origination__storage:
    seq:
    - id: size_of_storage
      type: u4
      valid:
        max: 1073741823
    - id: storage
      size: size_of_storage
  origination__code:
    seq:
    - id: size_of_code
      type: u4
      valid:
        max: 1073741823
    - id: code
      size: size_of_code
  origination__public_key_hash:
    seq:
    - id: public_key_hash_tag
      type: u1
      enum: public_key_hash_tag
    - id: origination__p256__public_key_hash
      size: 20
      if: (public_key_hash_tag == public_key_hash_tag::p256)
  transaction__id_009__psfloren__operation__alpha__internal_operation:
    seq:
    - id: amount
      type: n
    - id: destination
      type: transaction__id_009__psfloren__contract_id
      doc: ! >-
        A contract handle: A contract notation as given to an RPC or inside scripts.
        Can be a base58 implicit contract hash or a base58 originated contract hash.
    - id: parameters_tag
      type: u1
      enum: bool
    - id: transaction__parameters
      type: transaction__parameters
      if: (parameters_tag == bool::true)
  transaction__parameters:
    seq:
    - id: entrypoint
      type: transaction__id_009__psfloren__entrypoint
      doc: ! 'entrypoint: Named entrypoint to a Michelson smart contract'
    - id: transaction__value
      type: transaction__value
  transaction__value:
    seq:
    - id: size_of_value
      type: u4
      valid:
        max: 1073741823
    - id: value
      size: size_of_value
  transaction__id_009__psfloren__entrypoint:
    seq:
    - id: id_009__psfloren__entrypoint_tag
      type: u1
      enum: id_009__psfloren__entrypoint_tag
    - id: transaction__named__id_009__psfloren__entrypoint
      type: transaction__named__id_009__psfloren__entrypoint
      if: (id_009__psfloren__entrypoint_tag == id_009__psfloren__entrypoint_tag::named)
  transaction__named__id_009__psfloren__entrypoint:
    seq:
    - id: size_of_named
      type: u1
    - id: named
      size: size_of_named
      size-eos: true
      valid:
        max: 31
  transaction__id_009__psfloren__contract_id:
    seq:
    - id: id_009__psfloren__contract_id_tag
      type: u1
      enum: id_009__psfloren__contract_id_tag
    - id: transaction__implicit__id_009__psfloren__contract_id
      type: transaction__implicit__public_key_hash
      if: (id_009__psfloren__contract_id_tag == id_009__psfloren__contract_id_tag::implicit)
      doc: A Ed25519, Secp256k1, or P256 public key hash
    - id: transaction__originated__id_009__psfloren__contract_id
      type: transaction__originated__id_009__psfloren__contract_id
      if: (id_009__psfloren__contract_id_tag == id_009__psfloren__contract_id_tag::originated)
  transaction__originated__id_009__psfloren__contract_id:
    seq:
    - id: contract_hash
      size: 20
    - id: originated_padding
      size: 1
      doc: This field is for padding, ignore
  transaction__implicit__public_key_hash:
    seq:
    - id: public_key_hash_tag
      type: u1
      enum: public_key_hash_tag
    - id: transaction__implicit__p256__public_key_hash
      size: 20
      if: (public_key_hash_tag == public_key_hash_tag::p256)
  n:
    seq:
    - id: n
      type: n_chunk
      repeat: until
      repeat-until: not (_.has_more).as<bool>
  n_chunk:
    seq:
    - id: has_more
      type: b1be
    - id: payload
      type: b7be
  reveal__public_key:
    seq:
    - id: public_key_tag
      type: u1
      enum: public_key_tag
    - id: reveal__p256__public_key
      size: 33
      if: (public_key_tag == public_key_tag::p256)
  id_009__psfloren__contract_id:
    seq:
    - id: id_009__psfloren__contract_id_tag
      type: u1
      enum: id_009__psfloren__contract_id_tag
    - id: implicit__id_009__psfloren__contract_id
      type: implicit__public_key_hash
      if: (id_009__psfloren__contract_id_tag == id_009__psfloren__contract_id_tag::implicit)
      doc: A Ed25519, Secp256k1, or P256 public key hash
    - id: originated__id_009__psfloren__contract_id
      type: originated__id_009__psfloren__contract_id
      if: (id_009__psfloren__contract_id_tag == id_009__psfloren__contract_id_tag::originated)
  originated__id_009__psfloren__contract_id:
    seq:
    - id: contract_hash
      size: 20
    - id: originated_padding
      size: 1
      doc: This field is for padding, ignore
  implicit__public_key_hash:
    seq:
    - id: public_key_hash_tag
      type: u1
      enum: public_key_hash_tag
    - id: implicit__p256__public_key_hash
      size: 20
      if: (public_key_hash_tag == public_key_hash_tag::p256)
enums:
  id_009__psfloren__entrypoint_tag:
    0: default
    1: root
    2: do
    3: set_delegate
    4: remove_delegate
    255: named
  bool:
    0: false
    255: true
  public_key_tag:
    0: ed25519
    1: secp256k1
    2: p256
  id_009__psfloren__operation__alpha__internal_operation_tag:
    0: reveal
    1: transaction
    2: origination
    3: delegation
  public_key_hash_tag:
    0: ed25519
    1: secp256k1
    2: p256
  id_009__psfloren__contract_id_tag:
    0: implicit
    1: originated
seq:
- id: id_009__psfloren__operation__alpha__internal_operation
  type: id_009__psfloren__operation__alpha__internal_operation
