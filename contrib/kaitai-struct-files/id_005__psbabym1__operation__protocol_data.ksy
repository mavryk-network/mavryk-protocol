meta:
  id: id_005__psbabym1__operation__protocol_data
  endian: be
doc: ! 'Encoding id: 005-PsBabyM1.operation.protocol_data'
types:
  id_005__psbabym1__operation__alpha__contents_and_signature:
    seq:
    - id: contents
      type: contents_entries
      repeat: eos
    - id: signature
      size: 64
  contents_entries:
    seq:
    - id: id_005__psbabym1__operation__alpha__contents
      type: id_005__psbabym1__operation__alpha__contents
  id_005__psbabym1__operation__alpha__contents:
    seq:
    - id: id_005__psbabym1__operation__alpha__contents_tag
      type: u1
      enum: id_005__psbabym1__operation__alpha__contents_tag
    - id: endorsement__id_005__psbabym1__operation__alpha__contents
      type: s4
      if: (id_005__psbabym1__operation__alpha__contents_tag == id_005__psbabym1__operation__alpha__contents_tag::endorsement)
    - id: seed_nonce_revelation__id_005__psbabym1__operation__alpha__contents
      type: seed_nonce_revelation__id_005__psbabym1__operation__alpha__contents
      if: (id_005__psbabym1__operation__alpha__contents_tag == id_005__psbabym1__operation__alpha__contents_tag::seed_nonce_revelation)
    - id: double_endorsement_evidence__id_005__psbabym1__operation__alpha__contents
      type: double_endorsement_evidence__id_005__psbabym1__operation__alpha__contents
      if: (id_005__psbabym1__operation__alpha__contents_tag == id_005__psbabym1__operation__alpha__contents_tag::double_endorsement_evidence)
    - id: double_baking_evidence__id_005__psbabym1__operation__alpha__contents
      type: double_baking_evidence__id_005__psbabym1__operation__alpha__contents
      if: (id_005__psbabym1__operation__alpha__contents_tag == id_005__psbabym1__operation__alpha__contents_tag::double_baking_evidence)
    - id: activate_account__id_005__psbabym1__operation__alpha__contents
      type: activate_account__id_005__psbabym1__operation__alpha__contents
      if: (id_005__psbabym1__operation__alpha__contents_tag == id_005__psbabym1__operation__alpha__contents_tag::activate_account)
    - id: proposals__id_005__psbabym1__operation__alpha__contents
      type: proposals__id_005__psbabym1__operation__alpha__contents
      if: (id_005__psbabym1__operation__alpha__contents_tag == id_005__psbabym1__operation__alpha__contents_tag::proposals)
    - id: ballot__id_005__psbabym1__operation__alpha__contents
      type: ballot__id_005__psbabym1__operation__alpha__contents
      if: (id_005__psbabym1__operation__alpha__contents_tag == id_005__psbabym1__operation__alpha__contents_tag::ballot)
    - id: reveal__id_005__psbabym1__operation__alpha__contents
      type: reveal__id_005__psbabym1__operation__alpha__contents
      if: (id_005__psbabym1__operation__alpha__contents_tag == id_005__psbabym1__operation__alpha__contents_tag::reveal)
    - id: transaction__id_005__psbabym1__operation__alpha__contents
      type: transaction__id_005__psbabym1__operation__alpha__contents
      if: (id_005__psbabym1__operation__alpha__contents_tag == id_005__psbabym1__operation__alpha__contents_tag::transaction)
    - id: origination__id_005__psbabym1__operation__alpha__contents
      type: origination__id_005__psbabym1__operation__alpha__contents
      if: (id_005__psbabym1__operation__alpha__contents_tag == id_005__psbabym1__operation__alpha__contents_tag::origination)
    - id: delegation__id_005__psbabym1__operation__alpha__contents
      type: delegation__id_005__psbabym1__operation__alpha__contents
      if: (id_005__psbabym1__operation__alpha__contents_tag == id_005__psbabym1__operation__alpha__contents_tag::delegation)
  delegation__id_005__psbabym1__operation__alpha__contents:
    seq:
    - id: source
      type: delegation__public_key_hash
      doc: A Ed25519, Secp256k1, or P256 public key hash
    - id: fee
      type: n
    - id: counter
      type: n
    - id: gas_limit
      type: n
    - id: storage_limit
      type: n
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
  origination__id_005__psbabym1__operation__alpha__contents:
    seq:
    - id: source
      type: origination__public_key_hash
      doc: A Ed25519, Secp256k1, or P256 public key hash
    - id: fee
      type: n
    - id: counter
      type: n
    - id: gas_limit
      type: n
    - id: storage_limit
      type: n
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
      type: origination__id_005__psbabym1__scripted__contracts
  origination__id_005__psbabym1__scripted__contracts:
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
  transaction__id_005__psbabym1__operation__alpha__contents:
    seq:
    - id: source
      type: transaction__public_key_hash
      doc: A Ed25519, Secp256k1, or P256 public key hash
    - id: fee
      type: n
    - id: counter
      type: n
    - id: gas_limit
      type: n
    - id: storage_limit
      type: n
    - id: amount
      type: n
    - id: destination
      type: transaction__id_005__psbabym1__contract_id
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
      type: transaction__id_005__psbabym1__entrypoint
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
  transaction__id_005__psbabym1__entrypoint:
    seq:
    - id: id_005__psbabym1__entrypoint_tag
      type: u1
      enum: id_005__psbabym1__entrypoint_tag
    - id: transaction__named__id_005__psbabym1__entrypoint
      type: transaction__named__id_005__psbabym1__entrypoint
      if: (id_005__psbabym1__entrypoint_tag == id_005__psbabym1__entrypoint_tag::named)
  transaction__named__id_005__psbabym1__entrypoint:
    seq:
    - id: size_of_named
      type: u1
    - id: named
      size: size_of_named
      size-eos: true
      valid:
        max: 31
  transaction__id_005__psbabym1__contract_id:
    seq:
    - id: id_005__psbabym1__contract_id_tag
      type: u1
      enum: id_005__psbabym1__contract_id_tag
    - id: transaction__implicit__id_005__psbabym1__contract_id
      type: transaction__implicit__public_key_hash
      if: (id_005__psbabym1__contract_id_tag == id_005__psbabym1__contract_id_tag::implicit)
      doc: A Ed25519, Secp256k1, or P256 public key hash
    - id: transaction__originated__id_005__psbabym1__contract_id
      type: transaction__originated__id_005__psbabym1__contract_id
      if: (id_005__psbabym1__contract_id_tag == id_005__psbabym1__contract_id_tag::originated)
  transaction__originated__id_005__psbabym1__contract_id:
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
  transaction__public_key_hash:
    seq:
    - id: public_key_hash_tag
      type: u1
      enum: public_key_hash_tag
    - id: transaction__p256__public_key_hash
      size: 20
      if: (public_key_hash_tag == public_key_hash_tag::p256)
  reveal__id_005__psbabym1__operation__alpha__contents:
    seq:
    - id: source
      type: reveal__public_key_hash
      doc: A Ed25519, Secp256k1, or P256 public key hash
    - id: fee
      type: n
    - id: counter
      type: n
    - id: gas_limit
      type: n
    - id: storage_limit
      type: n
    - id: public_key
      type: reveal__public_key
      doc: A Ed25519, Secp256k1, or P256 public key
  reveal__public_key:
    seq:
    - id: public_key_tag
      type: u1
      enum: public_key_tag
    - id: reveal__p256__public_key
      size: 33
      if: (public_key_tag == public_key_tag::p256)
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
  reveal__public_key_hash:
    seq:
    - id: public_key_hash_tag
      type: u1
      enum: public_key_hash_tag
    - id: reveal__p256__public_key_hash
      size: 20
      if: (public_key_hash_tag == public_key_hash_tag::p256)
  ballot__id_005__psbabym1__operation__alpha__contents:
    seq:
    - id: source
      type: ballot__public_key_hash
      doc: A Ed25519, Secp256k1, or P256 public key hash
    - id: period
      type: s4
    - id: proposal
      size: 32
    - id: ballot
      type: s1
  ballot__public_key_hash:
    seq:
    - id: public_key_hash_tag
      type: u1
      enum: public_key_hash_tag
    - id: ballot__p256__public_key_hash
      size: 20
      if: (public_key_hash_tag == public_key_hash_tag::p256)
  proposals__id_005__psbabym1__operation__alpha__contents:
    seq:
    - id: source
      type: proposals__public_key_hash
      doc: A Ed25519, Secp256k1, or P256 public key hash
    - id: period
      type: s4
    - id: proposals__proposals
      type: proposals__proposals
  proposals__proposals:
    seq:
    - id: size_of_proposals
      type: u4
      valid:
        max: 1073741823
    - id: proposals
      type: proposals__proposals_entries
      size: size_of_proposals
      repeat: eos
  proposals__proposals_entries:
    seq:
    - id: protocol_hash
      size: 32
  proposals__public_key_hash:
    seq:
    - id: public_key_hash_tag
      type: u1
      enum: public_key_hash_tag
    - id: proposals__p256__public_key_hash
      size: 20
      if: (public_key_hash_tag == public_key_hash_tag::p256)
  activate_account__id_005__psbabym1__operation__alpha__contents:
    seq:
    - id: pkh
      size: 20
    - id: secret
      size: 20
  double_baking_evidence__id_005__psbabym1__operation__alpha__contents:
    seq:
    - id: double_baking_evidence__bh1
      type: double_baking_evidence__bh1
    - id: double_baking_evidence__bh2
      type: double_baking_evidence__bh2
  double_baking_evidence__bh2:
    seq:
    - id: size_of_bh2
      type: u4
      valid:
        max: 1073741823
    - id: bh2
      type: double_baking_evidence__id_005__psbabym1__block_header__alpha__full_header
      size: size_of_bh2
  double_baking_evidence__bh1:
    seq:
    - id: size_of_bh1
      type: u4
      valid:
        max: 1073741823
    - id: bh1
      type: double_baking_evidence__id_005__psbabym1__block_header__alpha__full_header
      size: size_of_bh1
  double_baking_evidence__id_005__psbabym1__block_header__alpha__full_header:
    seq:
    - id: double_baking_evidence__block_header__shell
      type: double_baking_evidence__block_header__shell
      doc: ! >-
        Shell header: Block header's shell-related content. It contains information
        such as the block level, its predecessor and timestamp.
    - id: double_baking_evidence__id_005__psbabym1__block_header__alpha__signed_contents
      type: double_baking_evidence__id_005__psbabym1__block_header__alpha__signed_contents
  double_baking_evidence__id_005__psbabym1__block_header__alpha__signed_contents:
    seq:
    - id: double_baking_evidence__id_005__psbabym1__block_header__alpha__unsigned_contents
      type: double_baking_evidence__id_005__psbabym1__block_header__alpha__unsigned_contents
    - id: signature
      size: 64
  double_baking_evidence__id_005__psbabym1__block_header__alpha__unsigned_contents:
    seq:
    - id: priority
      type: u2
    - id: proof_of_work_nonce
      size: 8
    - id: seed_nonce_hash_tag
      type: u1
      enum: bool
    - id: seed_nonce_hash
      size: 32
      if: (seed_nonce_hash_tag == bool::true)
  double_baking_evidence__block_header__shell:
    seq:
    - id: level
      type: s4
    - id: proto
      type: u1
    - id: predecessor
      size: 32
    - id: timestamp
      type: s8
      doc: ! 'A timestamp as seen by the protocol: second-level precision, epoch based.'
    - id: validation_pass
      type: u1
    - id: operations_hash
      size: 32
    - id: fitness
      type: double_baking_evidence__fitness
      doc: ! >-
        Block fitness: The fitness, or score, of a block, that allow the Tezos to
        decide which chain is the best. A fitness value is a list of byte sequences.
        They are compared as follows: shortest lists are smaller; lists of the same
        length are compared according to the lexicographical order.
    - id: context
      size: 32
  double_baking_evidence__fitness:
    seq:
    - id: size_of_fitness
      type: u4
      valid:
        max: 1073741823
    - id: fitness
      type: double_baking_evidence__fitness_entries
      size: size_of_fitness
      repeat: eos
  double_baking_evidence__fitness_entries:
    seq:
    - id: double_baking_evidence__fitness__elem
      type: double_baking_evidence__fitness__elem
  double_baking_evidence__fitness__elem:
    seq:
    - id: size_of_fitness__elem
      type: u4
      valid:
        max: 1073741823
    - id: fitness__elem
      size: size_of_fitness__elem
  double_endorsement_evidence__id_005__psbabym1__operation__alpha__contents:
    seq:
    - id: double_endorsement_evidence__op1
      type: double_endorsement_evidence__op1
    - id: double_endorsement_evidence__op2
      type: double_endorsement_evidence__op2
  double_endorsement_evidence__op2:
    seq:
    - id: size_of_op2
      type: u4
      valid:
        max: 1073741823
    - id: op2
      type: double_endorsement_evidence__id_005__psbabym1__inlined__endorsement
      size: size_of_op2
  double_endorsement_evidence__op1:
    seq:
    - id: size_of_op1
      type: u4
      valid:
        max: 1073741823
    - id: op1
      type: double_endorsement_evidence__id_005__psbabym1__inlined__endorsement
      size: size_of_op1
  double_endorsement_evidence__id_005__psbabym1__inlined__endorsement:
    seq:
    - id: operation__shell_header
      size: 32
      doc: An operation's shell header.
    - id: operations
      type: double_endorsement_evidence__id_005__psbabym1__inlined__endorsement__contents
    - id: signature_tag
      type: u1
      enum: bool
    - id: signature
      size: 64
      if: (signature_tag == bool::true)
  double_endorsement_evidence__id_005__psbabym1__inlined__endorsement__contents:
    seq:
    - id: id_005__psbabym1__inlined__endorsement__contents_tag
      type: u1
      enum: id_005__psbabym1__inlined__endorsement__contents_tag
    - id: double_endorsement_evidence__endorsement__id_005__psbabym1__inlined__endorsement__contents
      type: s4
      if: (id_005__psbabym1__inlined__endorsement__contents_tag == id_005__psbabym1__inlined__endorsement__contents_tag::endorsement)
  seed_nonce_revelation__id_005__psbabym1__operation__alpha__contents:
    seq:
    - id: level
      type: s4
    - id: nonce
      size: 32
enums:
  id_005__psbabym1__entrypoint_tag:
    0: default
    1: root
    2: do
    3: set_delegate
    4: remove_delegate
    255: named
  id_005__psbabym1__contract_id_tag:
    0: implicit
    1: originated
  public_key_tag:
    0: ed25519
    1: secp256k1
    2: p256
  public_key_hash_tag:
    0: ed25519
    1: secp256k1
    2: p256
  bool:
    0: false
    255: true
  id_005__psbabym1__inlined__endorsement__contents_tag:
    0: endorsement
  id_005__psbabym1__operation__alpha__contents_tag:
    0: endorsement
    1: seed_nonce_revelation
    2: double_endorsement_evidence
    3: double_baking_evidence
    4: activate_account
    5: proposals
    6: ballot
    107: reveal
    108: transaction
    109: origination
    110: delegation
seq:
- id: id_005__psbabym1__operation__alpha__contents_and_signature
  type: id_005__psbabym1__operation__alpha__contents_and_signature
