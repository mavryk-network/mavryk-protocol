meta:
  id: id_009__psfloren__lazy_storage_diff
  endian: be
doc: ! 'Encoding id: 009-PsFLoren.lazy_storage_diff'
types:
  id_009__psfloren__lazy_storage_diff_entries:
    seq:
    - id: id_009__psfloren__lazy_storage_diff_elt_tag
      type: u1
      enum: id_009__psfloren__lazy_storage_diff_elt_tag
    - id: big_map__id_009__psfloren__lazy_storage_diff_elt
      type: big_map__id_009__psfloren__lazy_storage_diff_elt
      if: (id_009__psfloren__lazy_storage_diff_elt_tag == id_009__psfloren__lazy_storage_diff_elt_tag::big_map)
    - id: sapling_state__id_009__psfloren__lazy_storage_diff_elt
      type: sapling_state__id_009__psfloren__lazy_storage_diff_elt
      if: (id_009__psfloren__lazy_storage_diff_elt_tag == id_009__psfloren__lazy_storage_diff_elt_tag::sapling_state)
  sapling_state__id_009__psfloren__lazy_storage_diff_elt:
    seq:
    - id: id
      type: z
      doc: ! 'Sapling state identifier: A sapling state identifier'
    - id: sapling_state__diff
      type: sapling_state__diff
  sapling_state__diff:
    seq:
    - id: diff_tag
      type: u1
      enum: diff_tag
    - id: sapling_state__update__diff
      type: sapling_state__update__updates
      if: (diff_tag == diff_tag::update)
    - id: sapling_state__copy__diff
      type: sapling_state__copy__diff
      if: (diff_tag == diff_tag::copy)
    - id: sapling_state__alloc__diff
      type: sapling_state__alloc__diff
      if: (diff_tag == diff_tag::alloc)
  sapling_state__alloc__diff:
    seq:
    - id: sapling_state__alloc__updates
      type: sapling_state__alloc__updates
    - id: memo_size
      type: u2
  sapling_state__alloc__updates:
    seq:
    - id: sapling_state__alloc__commitments_and_ciphertexts
      type: sapling_state__alloc__commitments_and_ciphertexts
    - id: sapling_state__alloc__nullifiers
      type: sapling_state__alloc__nullifiers
  sapling_state__alloc__nullifiers:
    seq:
    - id: size_of_nullifiers
      type: u4
      valid:
        max: 1073741823
    - id: nullifiers
      type: sapling_state__alloc__nullifiers_entries
      size: size_of_nullifiers
      repeat: eos
  sapling_state__alloc__nullifiers_entries:
    seq:
    - id: sapling__transaction__nullifier
      size: 32
  sapling_state__alloc__commitments_and_ciphertexts:
    seq:
    - id: size_of_commitments_and_ciphertexts
      type: u4
      valid:
        max: 1073741823
    - id: commitments_and_ciphertexts
      type: sapling_state__alloc__commitments_and_ciphertexts_entries
      size: size_of_commitments_and_ciphertexts
      repeat: eos
  sapling_state__alloc__commitments_and_ciphertexts_entries:
    seq:
    - id: commitments_and_ciphertexts_elt_field0
      size: 32
      doc: sapling__transaction__commitment
    - id: commitments_and_ciphertexts_elt_field1
      type: sapling_state__alloc__sapling__transaction__ciphertext
      doc: sapling_state__alloc__sapling__transaction__ciphertext
  sapling_state__alloc__sapling__transaction__ciphertext:
    seq:
    - id: cv
      size: 32
    - id: epk
      size: 32
    - id: sapling_state__alloc__payload_enc
      type: sapling_state__alloc__payload_enc
    - id: nonce_enc
      size: 24
    - id: payload_out
      size: 80
    - id: nonce_out
      size: 24
  sapling_state__alloc__payload_enc:
    seq:
    - id: size_of_payload_enc
      type: u4
      valid:
        max: 1073741823
    - id: payload_enc
      size: size_of_payload_enc
  sapling_state__copy__diff:
    seq:
    - id: source
      type: z
      doc: ! 'Sapling state identifier: A sapling state identifier'
    - id: sapling_state__copy__updates
      type: sapling_state__copy__updates
  sapling_state__copy__updates:
    seq:
    - id: sapling_state__copy__commitments_and_ciphertexts
      type: sapling_state__copy__commitments_and_ciphertexts
    - id: sapling_state__copy__nullifiers
      type: sapling_state__copy__nullifiers
  sapling_state__copy__nullifiers:
    seq:
    - id: size_of_nullifiers
      type: u4
      valid:
        max: 1073741823
    - id: nullifiers
      type: sapling_state__copy__nullifiers_entries
      size: size_of_nullifiers
      repeat: eos
  sapling_state__copy__nullifiers_entries:
    seq:
    - id: sapling__transaction__nullifier
      size: 32
  sapling_state__copy__commitments_and_ciphertexts:
    seq:
    - id: size_of_commitments_and_ciphertexts
      type: u4
      valid:
        max: 1073741823
    - id: commitments_and_ciphertexts
      type: sapling_state__copy__commitments_and_ciphertexts_entries
      size: size_of_commitments_and_ciphertexts
      repeat: eos
  sapling_state__copy__commitments_and_ciphertexts_entries:
    seq:
    - id: commitments_and_ciphertexts_elt_field0
      size: 32
      doc: sapling__transaction__commitment
    - id: commitments_and_ciphertexts_elt_field1
      type: sapling_state__copy__sapling__transaction__ciphertext
      doc: sapling_state__copy__sapling__transaction__ciphertext
  sapling_state__copy__sapling__transaction__ciphertext:
    seq:
    - id: cv
      size: 32
    - id: epk
      size: 32
    - id: sapling_state__copy__payload_enc
      type: sapling_state__copy__payload_enc
    - id: nonce_enc
      size: 24
    - id: payload_out
      size: 80
    - id: nonce_out
      size: 24
  sapling_state__copy__payload_enc:
    seq:
    - id: size_of_payload_enc
      type: u4
      valid:
        max: 1073741823
    - id: payload_enc
      size: size_of_payload_enc
  sapling_state__update__updates:
    seq:
    - id: sapling_state__update__commitments_and_ciphertexts
      type: sapling_state__update__commitments_and_ciphertexts
    - id: sapling_state__update__nullifiers
      type: sapling_state__update__nullifiers
  sapling_state__update__nullifiers:
    seq:
    - id: size_of_nullifiers
      type: u4
      valid:
        max: 1073741823
    - id: nullifiers
      type: sapling_state__update__nullifiers_entries
      size: size_of_nullifiers
      repeat: eos
  sapling_state__update__nullifiers_entries:
    seq:
    - id: sapling__transaction__nullifier
      size: 32
  sapling_state__update__commitments_and_ciphertexts:
    seq:
    - id: size_of_commitments_and_ciphertexts
      type: u4
      valid:
        max: 1073741823
    - id: commitments_and_ciphertexts
      type: sapling_state__update__commitments_and_ciphertexts_entries
      size: size_of_commitments_and_ciphertexts
      repeat: eos
  sapling_state__update__commitments_and_ciphertexts_entries:
    seq:
    - id: commitments_and_ciphertexts_elt_field0
      size: 32
      doc: sapling__transaction__commitment
    - id: commitments_and_ciphertexts_elt_field1
      type: sapling_state__update__sapling__transaction__ciphertext
      doc: sapling_state__update__sapling__transaction__ciphertext
  sapling_state__update__sapling__transaction__ciphertext:
    seq:
    - id: cv
      size: 32
    - id: epk
      size: 32
    - id: sapling_state__update__payload_enc
      type: sapling_state__update__payload_enc
    - id: nonce_enc
      size: 24
    - id: payload_out
      size: 80
    - id: nonce_out
      size: 24
  sapling_state__update__payload_enc:
    seq:
    - id: size_of_payload_enc
      type: u4
      valid:
        max: 1073741823
    - id: payload_enc
      size: size_of_payload_enc
  big_map__id_009__psfloren__lazy_storage_diff_elt:
    seq:
    - id: id
      type: z
      doc: ! 'Big map identifier: A big map identifier'
    - id: big_map__diff
      type: big_map__diff
  big_map__diff:
    seq:
    - id: diff_tag
      type: u1
      enum: diff_tag
    - id: big_map__update__diff
      type: big_map__update__updates
      if: (diff_tag == diff_tag::update)
    - id: big_map__copy__diff
      type: big_map__copy__diff
      if: (diff_tag == diff_tag::copy)
    - id: big_map__alloc__diff
      type: big_map__alloc__diff
      if: (diff_tag == diff_tag::alloc)
  big_map__alloc__diff:
    seq:
    - id: big_map__alloc__updates
      type: big_map__alloc__updates
    - id: key_type
      type: micheline__009__psfloren__michelson_v1__expression
    - id: value_type
      type: micheline__009__psfloren__michelson_v1__expression
  big_map__alloc__updates:
    seq:
    - id: size_of_updates
      type: u4
      valid:
        max: 1073741823
    - id: updates
      type: big_map__alloc__updates_entries
      size: size_of_updates
      repeat: eos
  big_map__alloc__updates_entries:
    seq:
    - id: key_hash
      size: 32
    - id: key
      type: micheline__009__psfloren__michelson_v1__expression
    - id: value_tag
      type: u1
      enum: bool
    - id: value
      type: micheline__009__psfloren__michelson_v1__expression
      if: (value_tag == bool::true)
  big_map__copy__diff:
    seq:
    - id: source
      type: z
      doc: ! 'Big map identifier: A big map identifier'
    - id: big_map__copy__updates
      type: big_map__copy__updates
  big_map__copy__updates:
    seq:
    - id: size_of_updates
      type: u4
      valid:
        max: 1073741823
    - id: updates
      type: big_map__copy__updates_entries
      size: size_of_updates
      repeat: eos
  big_map__copy__updates_entries:
    seq:
    - id: key_hash
      size: 32
    - id: key
      type: micheline__009__psfloren__michelson_v1__expression
    - id: value_tag
      type: u1
      enum: bool
    - id: value
      type: micheline__009__psfloren__michelson_v1__expression
      if: (value_tag == bool::true)
  big_map__update__updates:
    seq:
    - id: size_of_updates
      type: u4
      valid:
        max: 1073741823
    - id: updates
      type: big_map__update__updates_entries
      size: size_of_updates
      repeat: eos
  big_map__update__updates_entries:
    seq:
    - id: key_hash
      size: 32
    - id: key
      type: big_map__update__micheline__009__psfloren__michelson_v1__expression
    - id: value_tag
      type: u1
      enum: bool
    - id: value
      type: micheline__009__psfloren__michelson_v1__expression
      if: (value_tag == bool::true)
  big_map__update__micheline__009__psfloren__michelson_v1__expression:
    seq:
    - id: micheline__009__psfloren__michelson_v1__expression_tag
      type: u1
      enum: micheline__009__psfloren__michelson_v1__expression_tag
    - id: big_map__update__bytes__micheline__009__psfloren__michelson_v1__expression
      type: big_map__update__bytes__bytes
      if: (micheline__009__psfloren__michelson_v1__expression_tag == micheline__009__psfloren__michelson_v1__expression_tag::bytes)
  big_map__update__bytes__bytes:
    seq:
    - id: size_of_bytes
      type: u4
      valid:
        max: 1073741823
    - id: bytes
      size: size_of_bytes
  big_map__update__prim__generic__micheline__009__psfloren__michelson_v1__expression:
    seq:
    - id: prim
      type: u1
      enum: big_map__update__prim__generic__id_009__psfloren__michelson__v1__primitives
    - id: big_map__update__prim__generic__args
      type: big_map__update__prim__generic__args
    - id: big_map__update__prim__generic__annots
      type: big_map__update__prim__generic__annots
  big_map__update__prim__generic__annots:
    seq:
    - id: size_of_annots
      type: u4
      valid:
        max: 1073741823
    - id: annots
      size: size_of_annots
  big_map__update__prim__generic__args:
    seq:
    - id: size_of_args
      type: u4
      valid:
        max: 1073741823
    - id: args
      type: big_map__update__prim__generic__args_entries
      size: size_of_args
      repeat: eos
  big_map__update__prim__generic__args_entries:
    seq:
    - id: args_elt
      type: micheline__009__psfloren__michelson_v1__expression
  big_map__update__prim__2_args__some_annots__micheline__009__psfloren__michelson_v1__expression:
    seq:
    - id: prim
      type: u1
      enum: big_map__update__prim__2_args__some_annots__id_009__psfloren__michelson__v1__primitives
    - id: arg1
      type: micheline__009__psfloren__michelson_v1__expression
    - id: arg2
      type: micheline__009__psfloren__michelson_v1__expression
    - id: big_map__update__prim__2_args__some_annots__annots
      type: big_map__update__prim__2_args__some_annots__annots
  big_map__update__prim__2_args__some_annots__annots:
    seq:
    - id: size_of_annots
      type: u4
      valid:
        max: 1073741823
    - id: annots
      size: size_of_annots
  big_map__update__prim__2_args__no_annots__micheline__009__psfloren__michelson_v1__expression:
    seq:
    - id: prim
      type: u1
      enum: big_map__update__prim__2_args__no_annots__id_009__psfloren__michelson__v1__primitives
    - id: arg1
      type: micheline__009__psfloren__michelson_v1__expression
    - id: arg2
      type: micheline__009__psfloren__michelson_v1__expression
  big_map__update__prim__1_arg__some_annots__micheline__009__psfloren__michelson_v1__expression:
    seq:
    - id: prim
      type: u1
      enum: big_map__update__prim__1_arg__some_annots__id_009__psfloren__michelson__v1__primitives
    - id: arg
      type: micheline__009__psfloren__michelson_v1__expression
    - id: big_map__update__prim__1_arg__some_annots__annots
      type: big_map__update__prim__1_arg__some_annots__annots
  big_map__update__prim__1_arg__some_annots__annots:
    seq:
    - id: size_of_annots
      type: u4
      valid:
        max: 1073741823
    - id: annots
      size: size_of_annots
  big_map__update__prim__1_arg__no_annots__micheline__009__psfloren__michelson_v1__expression:
    seq:
    - id: prim
      type: u1
      enum: big_map__update__prim__1_arg__no_annots__id_009__psfloren__michelson__v1__primitives
    - id: arg
      type: micheline__009__psfloren__michelson_v1__expression
  big_map__update__prim__no_args__some_annots__micheline__009__psfloren__michelson_v1__expression:
    seq:
    - id: prim
      type: u1
      enum: big_map__update__prim__no_args__some_annots__id_009__psfloren__michelson__v1__primitives
    - id: big_map__update__prim__no_args__some_annots__annots
      type: big_map__update__prim__no_args__some_annots__annots
  big_map__update__prim__no_args__some_annots__annots:
    seq:
    - id: size_of_annots
      type: u4
      valid:
        max: 1073741823
    - id: annots
      size: size_of_annots
  big_map__update__sequence__micheline__009__psfloren__michelson_v1__expression:
    seq:
    - id: size_of_sequence
      type: u4
      valid:
        max: 1073741823
    - id: sequence
      type: big_map__update__sequence__sequence_entries
      size: size_of_sequence
      repeat: eos
  big_map__update__sequence__sequence_entries:
    seq:
    - id: sequence_elt
      type: micheline__009__psfloren__michelson_v1__expression
  big_map__update__string__string:
    seq:
    - id: size_of_string
      type: u4
      valid:
        max: 1073741823
    - id: string
      size: size_of_string
  z:
    seq:
    - id: has_tail
      type: b1be
    - id: sign
      type: b1be
    - id: payload
      type: b6be
    - id: tail
      type: n_chunk
      repeat: until
      repeat-until: not (_.has_more).as<bool>
      if: has_tail.as<bool>
  n_chunk:
    seq:
    - id: has_more
      type: b1be
    - id: payload
      type: b7be
enums:
  bool:
    0: false
    255: true
  big_map__update__prim__generic__id_009__psfloren__michelson__v1__primitives:
    2: code
    78: set_delegate
    40: ge
    28: create_account
    34: ediv
    75: sub
    61: nil
    42: gt
    39: failwith
    93: key_hash
    87: cast
    115: apply
    35: empty_map
    112: dig
    92: key
    133: sapling_empty_state
    83: loop_left
    67: push
    43: hash_key
    49: lambda
    66: pair
    130: bls12_381_fr
    44: if
    101: pair
    69: size
    90: contract
    68: right
    53: lsl
    129: bls12_381_g2
    91: int
    56: map
    36: empty_set
    94: lambda
    6: none
    54: lsr
    139: join_tickets
    110: address
    51: left
    62: none
    38: exec
    82: iter
    136: ticket
    47: if_none
    13: unpack
    9: some
    11: unit
    134: sapling_verify_update
    52: loop
    70: some
    138: split_ticket
    86: isnat
    117: chain_id
    131: sapling_state
    65: or
    23: cdr
    111: slice
    106: mutez
    96: map
    72: sender
    140: get_and_update
    88: rename
    64: now
    121: never
    12: pack
    30: implicit_account
    118: level
    73: self
    81: xor
    132: sapling_transaction
    74: steps_to_quota
    89: bool
    14: blake2b
    127: pairing_check
    57: mem
    29: create_contract
    48: int
    45: if_cons
    24: check_signature
    108: unit
    137: read_ticket
    107: timestamp
    20: and
    104: string
    80: update
    7: pair
    37: eq
    120: never
    0: parameter
    10: true
    84: address
    97: big_map
    85: contract
    59: neg
    32: drop
    122: unpair
    98: nat
    5: left
    41: get
    60: neq
    27: cons
    22: car
    105: bytes
    33: dup
    76: swap
    79: unit
    26: concat
    128: bls12_381_g1
    55: lt
    95: list
    17: abs
    31: dip
    19: amount
    103: signature
    58: mul
    116: chain_id
    126: sha3
    25: compare
    113: dug
    77: transfer_tokens
    100: or
    63: not
    109: operation
    114: empty_big_map
    21: balance
    16: sha512
    3: false
    71: source
    1: storage
    135: ticket
    102: set
    50: le
    8: right
    99: option
    15: sha256
    123: voting_power
    124: total_voting_power
    4: elt
    125: keccak
    119: self_address
    46: if_left
    18: add
  big_map__update__prim__2_args__some_annots__id_009__psfloren__michelson__v1__primitives:
    2: code
    78: set_delegate
    40: ge
    28: create_account
    34: ediv
    75: sub
    61: nil
    42: gt
    39: failwith
    93: key_hash
    87: cast
    115: apply
    35: empty_map
    112: dig
    92: key
    133: sapling_empty_state
    83: loop_left
    67: push
    43: hash_key
    49: lambda
    66: pair
    130: bls12_381_fr
    44: if
    101: pair
    69: size
    90: contract
    68: right
    53: lsl
    129: bls12_381_g2
    91: int
    56: map
    36: empty_set
    94: lambda
    6: none
    54: lsr
    139: join_tickets
    110: address
    51: left
    62: none
    38: exec
    82: iter
    136: ticket
    47: if_none
    13: unpack
    9: some
    11: unit
    134: sapling_verify_update
    52: loop
    70: some
    138: split_ticket
    86: isnat
    117: chain_id
    131: sapling_state
    65: or
    23: cdr
    111: slice
    106: mutez
    96: map
    72: sender
    140: get_and_update
    88: rename
    64: now
    121: never
    12: pack
    30: implicit_account
    118: level
    73: self
    81: xor
    132: sapling_transaction
    74: steps_to_quota
    89: bool
    14: blake2b
    127: pairing_check
    57: mem
    29: create_contract
    48: int
    45: if_cons
    24: check_signature
    108: unit
    137: read_ticket
    107: timestamp
    20: and
    104: string
    80: update
    7: pair
    37: eq
    120: never
    0: parameter
    10: true
    84: address
    97: big_map
    85: contract
    59: neg
    32: drop
    122: unpair
    98: nat
    5: left
    41: get
    60: neq
    27: cons
    22: car
    105: bytes
    33: dup
    76: swap
    79: unit
    26: concat
    128: bls12_381_g1
    55: lt
    95: list
    17: abs
    31: dip
    19: amount
    103: signature
    58: mul
    116: chain_id
    126: sha3
    25: compare
    113: dug
    77: transfer_tokens
    100: or
    63: not
    109: operation
    114: empty_big_map
    21: balance
    16: sha512
    3: false
    71: source
    1: storage
    135: ticket
    102: set
    50: le
    8: right
    99: option
    15: sha256
    123: voting_power
    124: total_voting_power
    4: elt
    125: keccak
    119: self_address
    46: if_left
    18: add
  big_map__update__prim__2_args__no_annots__id_009__psfloren__michelson__v1__primitives:
    2: code
    78: set_delegate
    40: ge
    28: create_account
    34: ediv
    75: sub
    61: nil
    42: gt
    39: failwith
    93: key_hash
    87: cast
    115: apply
    35: empty_map
    112: dig
    92: key
    133: sapling_empty_state
    83: loop_left
    67: push
    43: hash_key
    49: lambda
    66: pair
    130: bls12_381_fr
    44: if
    101: pair
    69: size
    90: contract
    68: right
    53: lsl
    129: bls12_381_g2
    91: int
    56: map
    36: empty_set
    94: lambda
    6: none
    54: lsr
    139: join_tickets
    110: address
    51: left
    62: none
    38: exec
    82: iter
    136: ticket
    47: if_none
    13: unpack
    9: some
    11: unit
    134: sapling_verify_update
    52: loop
    70: some
    138: split_ticket
    86: isnat
    117: chain_id
    131: sapling_state
    65: or
    23: cdr
    111: slice
    106: mutez
    96: map
    72: sender
    140: get_and_update
    88: rename
    64: now
    121: never
    12: pack
    30: implicit_account
    118: level
    73: self
    81: xor
    132: sapling_transaction
    74: steps_to_quota
    89: bool
    14: blake2b
    127: pairing_check
    57: mem
    29: create_contract
    48: int
    45: if_cons
    24: check_signature
    108: unit
    137: read_ticket
    107: timestamp
    20: and
    104: string
    80: update
    7: pair
    37: eq
    120: never
    0: parameter
    10: true
    84: address
    97: big_map
    85: contract
    59: neg
    32: drop
    122: unpair
    98: nat
    5: left
    41: get
    60: neq
    27: cons
    22: car
    105: bytes
    33: dup
    76: swap
    79: unit
    26: concat
    128: bls12_381_g1
    55: lt
    95: list
    17: abs
    31: dip
    19: amount
    103: signature
    58: mul
    116: chain_id
    126: sha3
    25: compare
    113: dug
    77: transfer_tokens
    100: or
    63: not
    109: operation
    114: empty_big_map
    21: balance
    16: sha512
    3: false
    71: source
    1: storage
    135: ticket
    102: set
    50: le
    8: right
    99: option
    15: sha256
    123: voting_power
    124: total_voting_power
    4: elt
    125: keccak
    119: self_address
    46: if_left
    18: add
  big_map__update__prim__1_arg__some_annots__id_009__psfloren__michelson__v1__primitives:
    2: code
    78: set_delegate
    40: ge
    28: create_account
    34: ediv
    75: sub
    61: nil
    42: gt
    39: failwith
    93: key_hash
    87: cast
    115: apply
    35: empty_map
    112: dig
    92: key
    133: sapling_empty_state
    83: loop_left
    67: push
    43: hash_key
    49: lambda
    66: pair
    130: bls12_381_fr
    44: if
    101: pair
    69: size
    90: contract
    68: right
    53: lsl
    129: bls12_381_g2
    91: int
    56: map
    36: empty_set
    94: lambda
    6: none
    54: lsr
    139: join_tickets
    110: address
    51: left
    62: none
    38: exec
    82: iter
    136: ticket
    47: if_none
    13: unpack
    9: some
    11: unit
    134: sapling_verify_update
    52: loop
    70: some
    138: split_ticket
    86: isnat
    117: chain_id
    131: sapling_state
    65: or
    23: cdr
    111: slice
    106: mutez
    96: map
    72: sender
    140: get_and_update
    88: rename
    64: now
    121: never
    12: pack
    30: implicit_account
    118: level
    73: self
    81: xor
    132: sapling_transaction
    74: steps_to_quota
    89: bool
    14: blake2b
    127: pairing_check
    57: mem
    29: create_contract
    48: int
    45: if_cons
    24: check_signature
    108: unit
    137: read_ticket
    107: timestamp
    20: and
    104: string
    80: update
    7: pair
    37: eq
    120: never
    0: parameter
    10: true
    84: address
    97: big_map
    85: contract
    59: neg
    32: drop
    122: unpair
    98: nat
    5: left
    41: get
    60: neq
    27: cons
    22: car
    105: bytes
    33: dup
    76: swap
    79: unit
    26: concat
    128: bls12_381_g1
    55: lt
    95: list
    17: abs
    31: dip
    19: amount
    103: signature
    58: mul
    116: chain_id
    126: sha3
    25: compare
    113: dug
    77: transfer_tokens
    100: or
    63: not
    109: operation
    114: empty_big_map
    21: balance
    16: sha512
    3: false
    71: source
    1: storage
    135: ticket
    102: set
    50: le
    8: right
    99: option
    15: sha256
    123: voting_power
    124: total_voting_power
    4: elt
    125: keccak
    119: self_address
    46: if_left
    18: add
  big_map__update__prim__1_arg__no_annots__id_009__psfloren__michelson__v1__primitives:
    2: code
    78: set_delegate
    40: ge
    28: create_account
    34: ediv
    75: sub
    61: nil
    42: gt
    39: failwith
    93: key_hash
    87: cast
    115: apply
    35: empty_map
    112: dig
    92: key
    133: sapling_empty_state
    83: loop_left
    67: push
    43: hash_key
    49: lambda
    66: pair
    130: bls12_381_fr
    44: if
    101: pair
    69: size
    90: contract
    68: right
    53: lsl
    129: bls12_381_g2
    91: int
    56: map
    36: empty_set
    94: lambda
    6: none
    54: lsr
    139: join_tickets
    110: address
    51: left
    62: none
    38: exec
    82: iter
    136: ticket
    47: if_none
    13: unpack
    9: some
    11: unit
    134: sapling_verify_update
    52: loop
    70: some
    138: split_ticket
    86: isnat
    117: chain_id
    131: sapling_state
    65: or
    23: cdr
    111: slice
    106: mutez
    96: map
    72: sender
    140: get_and_update
    88: rename
    64: now
    121: never
    12: pack
    30: implicit_account
    118: level
    73: self
    81: xor
    132: sapling_transaction
    74: steps_to_quota
    89: bool
    14: blake2b
    127: pairing_check
    57: mem
    29: create_contract
    48: int
    45: if_cons
    24: check_signature
    108: unit
    137: read_ticket
    107: timestamp
    20: and
    104: string
    80: update
    7: pair
    37: eq
    120: never
    0: parameter
    10: true
    84: address
    97: big_map
    85: contract
    59: neg
    32: drop
    122: unpair
    98: nat
    5: left
    41: get
    60: neq
    27: cons
    22: car
    105: bytes
    33: dup
    76: swap
    79: unit
    26: concat
    128: bls12_381_g1
    55: lt
    95: list
    17: abs
    31: dip
    19: amount
    103: signature
    58: mul
    116: chain_id
    126: sha3
    25: compare
    113: dug
    77: transfer_tokens
    100: or
    63: not
    109: operation
    114: empty_big_map
    21: balance
    16: sha512
    3: false
    71: source
    1: storage
    135: ticket
    102: set
    50: le
    8: right
    99: option
    15: sha256
    123: voting_power
    124: total_voting_power
    4: elt
    125: keccak
    119: self_address
    46: if_left
    18: add
  big_map__update__prim__no_args__some_annots__id_009__psfloren__michelson__v1__primitives:
    2: code
    78: set_delegate
    40: ge
    28: create_account
    34: ediv
    75: sub
    61: nil
    42: gt
    39: failwith
    93: key_hash
    87: cast
    115: apply
    35: empty_map
    112: dig
    92: key
    133: sapling_empty_state
    83: loop_left
    67: push
    43: hash_key
    49: lambda
    66: pair
    130: bls12_381_fr
    44: if
    101: pair
    69: size
    90: contract
    68: right
    53: lsl
    129: bls12_381_g2
    91: int
    56: map
    36: empty_set
    94: lambda
    6: none
    54: lsr
    139: join_tickets
    110: address
    51: left
    62: none
    38: exec
    82: iter
    136: ticket
    47: if_none
    13: unpack
    9: some
    11: unit
    134: sapling_verify_update
    52: loop
    70: some
    138: split_ticket
    86: isnat
    117: chain_id
    131: sapling_state
    65: or
    23: cdr
    111: slice
    106: mutez
    96: map
    72: sender
    140: get_and_update
    88: rename
    64: now
    121: never
    12: pack
    30: implicit_account
    118: level
    73: self
    81: xor
    132: sapling_transaction
    74: steps_to_quota
    89: bool
    14: blake2b
    127: pairing_check
    57: mem
    29: create_contract
    48: int
    45: if_cons
    24: check_signature
    108: unit
    137: read_ticket
    107: timestamp
    20: and
    104: string
    80: update
    7: pair
    37: eq
    120: never
    0: parameter
    10: true
    84: address
    97: big_map
    85: contract
    59: neg
    32: drop
    122: unpair
    98: nat
    5: left
    41: get
    60: neq
    27: cons
    22: car
    105: bytes
    33: dup
    76: swap
    79: unit
    26: concat
    128: bls12_381_g1
    55: lt
    95: list
    17: abs
    31: dip
    19: amount
    103: signature
    58: mul
    116: chain_id
    126: sha3
    25: compare
    113: dug
    77: transfer_tokens
    100: or
    63: not
    109: operation
    114: empty_big_map
    21: balance
    16: sha512
    3: false
    71: source
    1: storage
    135: ticket
    102: set
    50: le
    8: right
    99: option
    15: sha256
    123: voting_power
    124: total_voting_power
    4: elt
    125: keccak
    119: self_address
    46: if_left
    18: add
  big_map__update__prim__no_args__no_annots__id_009__psfloren__michelson__v1__primitives:
    2: code
    78: set_delegate
    40: ge
    28: create_account
    34: ediv
    75: sub
    61: nil
    42: gt
    39: failwith
    93: key_hash
    87: cast
    115: apply
    35: empty_map
    112: dig
    92: key
    133: sapling_empty_state
    83: loop_left
    67: push
    43: hash_key
    49: lambda
    66: pair
    130: bls12_381_fr
    44: if
    101: pair
    69: size
    90: contract
    68: right
    53: lsl
    129: bls12_381_g2
    91: int
    56: map
    36: empty_set
    94: lambda
    6: none
    54: lsr
    139: join_tickets
    110: address
    51: left
    62: none
    38: exec
    82: iter
    136: ticket
    47: if_none
    13: unpack
    9: some
    11: unit
    134: sapling_verify_update
    52: loop
    70: some
    138: split_ticket
    86: isnat
    117: chain_id
    131: sapling_state
    65: or
    23: cdr
    111: slice
    106: mutez
    96: map
    72: sender
    140: get_and_update
    88: rename
    64: now
    121: never
    12: pack
    30: implicit_account
    118: level
    73: self
    81: xor
    132: sapling_transaction
    74: steps_to_quota
    89: bool
    14: blake2b
    127: pairing_check
    57: mem
    29: create_contract
    48: int
    45: if_cons
    24: check_signature
    108: unit
    137: read_ticket
    107: timestamp
    20: and
    104: string
    80: update
    7: pair
    37: eq
    120: never
    0: parameter
    10: true
    84: address
    97: big_map
    85: contract
    59: neg
    32: drop
    122: unpair
    98: nat
    5: left
    41: get
    60: neq
    27: cons
    22: car
    105: bytes
    33: dup
    76: swap
    79: unit
    26: concat
    128: bls12_381_g1
    55: lt
    95: list
    17: abs
    31: dip
    19: amount
    103: signature
    58: mul
    116: chain_id
    126: sha3
    25: compare
    113: dug
    77: transfer_tokens
    100: or
    63: not
    109: operation
    114: empty_big_map
    21: balance
    16: sha512
    3: false
    71: source
    1: storage
    135: ticket
    102: set
    50: le
    8: right
    99: option
    15: sha256
    123: voting_power
    124: total_voting_power
    4: elt
    125: keccak
    119: self_address
    46: if_left
    18: add
  micheline__009__psfloren__michelson_v1__expression_tag:
    0: int
    1: string
    2: sequence
    3: prim__no_args__no_annots
    4: prim__no_args__some_annots
    5: prim__1_arg__no_annots
    6: prim__1_arg__some_annots
    7: prim__2_args__no_annots
    8: prim__2_args__some_annots
    9: prim__generic
    10: bytes
  diff_tag:
    0: update
    1: remove
    2: copy
    3: alloc
  id_009__psfloren__lazy_storage_diff_elt_tag:
    0: big_map
    1: sapling_state
seq:
- id: size_of_id_009__psfloren__lazy_storage_diff
  type: u4
  valid:
    max: 1073741823
- id: id_009__psfloren__lazy_storage_diff
  type: id_009__psfloren__lazy_storage_diff_entries
  size: size_of_id_009__psfloren__lazy_storage_diff
  repeat: eos
