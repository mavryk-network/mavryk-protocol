meta:
  id: id_011__pthangz2__lazy_storage_diff
  endian: be
doc: ! 'Encoding id: 011-PtHangz2.lazy_storage_diff'
types:
  id_011__pthangz2__lazy_storage_diff_entries:
    seq:
    - id: id_011__pthangz2__lazy_storage_diff_elt_tag
      type: u1
      enum: id_011__pthangz2__lazy_storage_diff_elt_tag
    - id: big_map__id_011__pthangz2__lazy_storage_diff_elt
      type: big_map__id_011__pthangz2__lazy_storage_diff_elt
      if: (id_011__pthangz2__lazy_storage_diff_elt_tag == id_011__pthangz2__lazy_storage_diff_elt_tag::big_map)
    - id: sapling_state__id_011__pthangz2__lazy_storage_diff_elt
      type: sapling_state__id_011__pthangz2__lazy_storage_diff_elt
      if: (id_011__pthangz2__lazy_storage_diff_elt_tag == id_011__pthangz2__lazy_storage_diff_elt_tag::sapling_state)
  sapling_state__id_011__pthangz2__lazy_storage_diff_elt:
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
  big_map__id_011__pthangz2__lazy_storage_diff_elt:
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
      type: micheline__011__pthangz2__michelson_v1__expression
    - id: value_type
      type: micheline__011__pthangz2__michelson_v1__expression
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
      type: micheline__011__pthangz2__michelson_v1__expression
    - id: value_tag
      type: u1
      enum: bool
    - id: value
      type: micheline__011__pthangz2__michelson_v1__expression
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
      type: micheline__011__pthangz2__michelson_v1__expression
    - id: value_tag
      type: u1
      enum: bool
    - id: value
      type: micheline__011__pthangz2__michelson_v1__expression
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
      type: big_map__update__micheline__011__pthangz2__michelson_v1__expression
    - id: value_tag
      type: u1
      enum: bool
    - id: value
      type: micheline__011__pthangz2__michelson_v1__expression
      if: (value_tag == bool::true)
  big_map__update__micheline__011__pthangz2__michelson_v1__expression:
    seq:
    - id: micheline__011__pthangz2__michelson_v1__expression_tag
      type: u1
      enum: micheline__011__pthangz2__michelson_v1__expression_tag
    - id: big_map__update__bytes__micheline__011__pthangz2__michelson_v1__expression
      type: big_map__update__bytes__bytes
      if: (micheline__011__pthangz2__michelson_v1__expression_tag == micheline__011__pthangz2__michelson_v1__expression_tag::bytes)
  big_map__update__bytes__bytes:
    seq:
    - id: size_of_bytes
      type: u4
      valid:
        max: 1073741823
    - id: bytes
      size: size_of_bytes
  big_map__update__prim__generic__micheline__011__pthangz2__michelson_v1__expression:
    seq:
    - id: prim
      type: u1
      enum: big_map__update__prim__generic__id_011__pthangz2__michelson__v1__primitives
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
      type: micheline__011__pthangz2__michelson_v1__expression
  big_map__update__prim__2_args__some_annots__micheline__011__pthangz2__michelson_v1__expression:
    seq:
    - id: prim
      type: u1
      enum: big_map__update__prim__2_args__some_annots__id_011__pthangz2__michelson__v1__primitives
    - id: arg1
      type: micheline__011__pthangz2__michelson_v1__expression
    - id: arg2
      type: micheline__011__pthangz2__michelson_v1__expression
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
  big_map__update__prim__2_args__no_annots__micheline__011__pthangz2__michelson_v1__expression:
    seq:
    - id: prim
      type: u1
      enum: big_map__update__prim__2_args__no_annots__id_011__pthangz2__michelson__v1__primitives
    - id: arg1
      type: micheline__011__pthangz2__michelson_v1__expression
    - id: arg2
      type: micheline__011__pthangz2__michelson_v1__expression
  big_map__update__prim__1_arg__some_annots__micheline__011__pthangz2__michelson_v1__expression:
    seq:
    - id: prim
      type: u1
      enum: big_map__update__prim__1_arg__some_annots__id_011__pthangz2__michelson__v1__primitives
    - id: arg
      type: micheline__011__pthangz2__michelson_v1__expression
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
  big_map__update__prim__1_arg__no_annots__micheline__011__pthangz2__michelson_v1__expression:
    seq:
    - id: prim
      type: u1
      enum: big_map__update__prim__1_arg__no_annots__id_011__pthangz2__michelson__v1__primitives
    - id: arg
      type: micheline__011__pthangz2__michelson_v1__expression
  big_map__update__prim__no_args__some_annots__micheline__011__pthangz2__michelson_v1__expression:
    seq:
    - id: prim
      type: u1
      enum: big_map__update__prim__no_args__some_annots__id_011__pthangz2__michelson__v1__primitives
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
  big_map__update__sequence__micheline__011__pthangz2__michelson_v1__expression:
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
      type: micheline__011__pthangz2__michelson_v1__expression
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
  big_map__update__prim__generic__id_011__pthangz2__michelson__v1__primitives:
    2: code
    115: apply
    76: swap
    27: cons
    33: dup
    111: slice
    59: neg
    41: get
    38: exec
    90: contract
    85: contract
    37: eq
    34: ediv
    133: sapling_empty_state
    89: bool
    87: cast
    81: xor
    140: get_and_update
    66: pair
    47: if_none
    64: now
    120: never
    42: gt
    98: nat
    67: push
    139: join_tickets
    122: unpair
    118: level
    143: open_chest
    116: chain_id
    114: empty_big_map
    54: lsr
    91: int
    5: left
    52: loop
    137: read_ticket
    107: timestamp
    49: lambda
    60: neq
    36: empty_set
    80: update
    146: constant
    126: sha3
    45: if_cons
    12: pack
    8: right
    10: true
    88: rename
    51: left
    68: right
    136: ticket
    84: address
    23: cdr
    109: operation
    63: not
    22: car
    103: signature
    73: self
    93: key_hash
    70: some
    40: ge
    86: isnat
    62: none
    112: dig
    11: unit
    29: create_contract
    71: source
    50: le
    79: unit
    108: unit
    119: self_address
    138: split_ticket
    13: unpack
    125: keccak
    55: lt
    28: create_account
    46: if_left
    43: hash_key
    117: chain_id
    105: bytes
    127: pairing_check
    104: string
    19: amount
    101: pair
    78: set_delegate
    6: none
    35: empty_map
    132: sapling_transaction
    0: parameter
    9: some
    82: iter
    94: lambda
    83: loop_left
    57: mem
    31: dip
    65: or
    95: list
    4: elt
    39: failwith
    58: mul
    26: concat
    21: balance
    102: set
    32: drop
    74: steps_to_quota
    77: transfer_tokens
    25: compare
    131: sapling_state
    142: chest_key
    130: bls12_381_fr
    53: lsl
    92: key
    16: sha512
    30: implicit_account
    18: add
    135: ticket
    100: or
    56: map
    110: address
    124: total_voting_power
    24: check_signature
    134: sapling_verify_update
    75: sub
    97: big_map
    61: nil
    106: mutez
    144: view
    20: and
    15: sha256
    145: view
    69: size
    1: storage
    128: bls12_381_g1
    99: option
    48: int
    7: pair
    129: bls12_381_g2
    96: map
    14: blake2b
    141: chest
    113: dug
    121: never
    3: false
    123: voting_power
    72: sender
    44: if
    17: abs
  big_map__update__prim__2_args__some_annots__id_011__pthangz2__michelson__v1__primitives:
    2: code
    115: apply
    76: swap
    27: cons
    33: dup
    111: slice
    59: neg
    41: get
    38: exec
    90: contract
    85: contract
    37: eq
    34: ediv
    133: sapling_empty_state
    89: bool
    87: cast
    81: xor
    140: get_and_update
    66: pair
    47: if_none
    64: now
    120: never
    42: gt
    98: nat
    67: push
    139: join_tickets
    122: unpair
    118: level
    143: open_chest
    116: chain_id
    114: empty_big_map
    54: lsr
    91: int
    5: left
    52: loop
    137: read_ticket
    107: timestamp
    49: lambda
    60: neq
    36: empty_set
    80: update
    146: constant
    126: sha3
    45: if_cons
    12: pack
    8: right
    10: true
    88: rename
    51: left
    68: right
    136: ticket
    84: address
    23: cdr
    109: operation
    63: not
    22: car
    103: signature
    73: self
    93: key_hash
    70: some
    40: ge
    86: isnat
    62: none
    112: dig
    11: unit
    29: create_contract
    71: source
    50: le
    79: unit
    108: unit
    119: self_address
    138: split_ticket
    13: unpack
    125: keccak
    55: lt
    28: create_account
    46: if_left
    43: hash_key
    117: chain_id
    105: bytes
    127: pairing_check
    104: string
    19: amount
    101: pair
    78: set_delegate
    6: none
    35: empty_map
    132: sapling_transaction
    0: parameter
    9: some
    82: iter
    94: lambda
    83: loop_left
    57: mem
    31: dip
    65: or
    95: list
    4: elt
    39: failwith
    58: mul
    26: concat
    21: balance
    102: set
    32: drop
    74: steps_to_quota
    77: transfer_tokens
    25: compare
    131: sapling_state
    142: chest_key
    130: bls12_381_fr
    53: lsl
    92: key
    16: sha512
    30: implicit_account
    18: add
    135: ticket
    100: or
    56: map
    110: address
    124: total_voting_power
    24: check_signature
    134: sapling_verify_update
    75: sub
    97: big_map
    61: nil
    106: mutez
    144: view
    20: and
    15: sha256
    145: view
    69: size
    1: storage
    128: bls12_381_g1
    99: option
    48: int
    7: pair
    129: bls12_381_g2
    96: map
    14: blake2b
    141: chest
    113: dug
    121: never
    3: false
    123: voting_power
    72: sender
    44: if
    17: abs
  big_map__update__prim__2_args__no_annots__id_011__pthangz2__michelson__v1__primitives:
    2: code
    115: apply
    76: swap
    27: cons
    33: dup
    111: slice
    59: neg
    41: get
    38: exec
    90: contract
    85: contract
    37: eq
    34: ediv
    133: sapling_empty_state
    89: bool
    87: cast
    81: xor
    140: get_and_update
    66: pair
    47: if_none
    64: now
    120: never
    42: gt
    98: nat
    67: push
    139: join_tickets
    122: unpair
    118: level
    143: open_chest
    116: chain_id
    114: empty_big_map
    54: lsr
    91: int
    5: left
    52: loop
    137: read_ticket
    107: timestamp
    49: lambda
    60: neq
    36: empty_set
    80: update
    146: constant
    126: sha3
    45: if_cons
    12: pack
    8: right
    10: true
    88: rename
    51: left
    68: right
    136: ticket
    84: address
    23: cdr
    109: operation
    63: not
    22: car
    103: signature
    73: self
    93: key_hash
    70: some
    40: ge
    86: isnat
    62: none
    112: dig
    11: unit
    29: create_contract
    71: source
    50: le
    79: unit
    108: unit
    119: self_address
    138: split_ticket
    13: unpack
    125: keccak
    55: lt
    28: create_account
    46: if_left
    43: hash_key
    117: chain_id
    105: bytes
    127: pairing_check
    104: string
    19: amount
    101: pair
    78: set_delegate
    6: none
    35: empty_map
    132: sapling_transaction
    0: parameter
    9: some
    82: iter
    94: lambda
    83: loop_left
    57: mem
    31: dip
    65: or
    95: list
    4: elt
    39: failwith
    58: mul
    26: concat
    21: balance
    102: set
    32: drop
    74: steps_to_quota
    77: transfer_tokens
    25: compare
    131: sapling_state
    142: chest_key
    130: bls12_381_fr
    53: lsl
    92: key
    16: sha512
    30: implicit_account
    18: add
    135: ticket
    100: or
    56: map
    110: address
    124: total_voting_power
    24: check_signature
    134: sapling_verify_update
    75: sub
    97: big_map
    61: nil
    106: mutez
    144: view
    20: and
    15: sha256
    145: view
    69: size
    1: storage
    128: bls12_381_g1
    99: option
    48: int
    7: pair
    129: bls12_381_g2
    96: map
    14: blake2b
    141: chest
    113: dug
    121: never
    3: false
    123: voting_power
    72: sender
    44: if
    17: abs
  big_map__update__prim__1_arg__some_annots__id_011__pthangz2__michelson__v1__primitives:
    2: code
    115: apply
    76: swap
    27: cons
    33: dup
    111: slice
    59: neg
    41: get
    38: exec
    90: contract
    85: contract
    37: eq
    34: ediv
    133: sapling_empty_state
    89: bool
    87: cast
    81: xor
    140: get_and_update
    66: pair
    47: if_none
    64: now
    120: never
    42: gt
    98: nat
    67: push
    139: join_tickets
    122: unpair
    118: level
    143: open_chest
    116: chain_id
    114: empty_big_map
    54: lsr
    91: int
    5: left
    52: loop
    137: read_ticket
    107: timestamp
    49: lambda
    60: neq
    36: empty_set
    80: update
    146: constant
    126: sha3
    45: if_cons
    12: pack
    8: right
    10: true
    88: rename
    51: left
    68: right
    136: ticket
    84: address
    23: cdr
    109: operation
    63: not
    22: car
    103: signature
    73: self
    93: key_hash
    70: some
    40: ge
    86: isnat
    62: none
    112: dig
    11: unit
    29: create_contract
    71: source
    50: le
    79: unit
    108: unit
    119: self_address
    138: split_ticket
    13: unpack
    125: keccak
    55: lt
    28: create_account
    46: if_left
    43: hash_key
    117: chain_id
    105: bytes
    127: pairing_check
    104: string
    19: amount
    101: pair
    78: set_delegate
    6: none
    35: empty_map
    132: sapling_transaction
    0: parameter
    9: some
    82: iter
    94: lambda
    83: loop_left
    57: mem
    31: dip
    65: or
    95: list
    4: elt
    39: failwith
    58: mul
    26: concat
    21: balance
    102: set
    32: drop
    74: steps_to_quota
    77: transfer_tokens
    25: compare
    131: sapling_state
    142: chest_key
    130: bls12_381_fr
    53: lsl
    92: key
    16: sha512
    30: implicit_account
    18: add
    135: ticket
    100: or
    56: map
    110: address
    124: total_voting_power
    24: check_signature
    134: sapling_verify_update
    75: sub
    97: big_map
    61: nil
    106: mutez
    144: view
    20: and
    15: sha256
    145: view
    69: size
    1: storage
    128: bls12_381_g1
    99: option
    48: int
    7: pair
    129: bls12_381_g2
    96: map
    14: blake2b
    141: chest
    113: dug
    121: never
    3: false
    123: voting_power
    72: sender
    44: if
    17: abs
  big_map__update__prim__1_arg__no_annots__id_011__pthangz2__michelson__v1__primitives:
    2: code
    115: apply
    76: swap
    27: cons
    33: dup
    111: slice
    59: neg
    41: get
    38: exec
    90: contract
    85: contract
    37: eq
    34: ediv
    133: sapling_empty_state
    89: bool
    87: cast
    81: xor
    140: get_and_update
    66: pair
    47: if_none
    64: now
    120: never
    42: gt
    98: nat
    67: push
    139: join_tickets
    122: unpair
    118: level
    143: open_chest
    116: chain_id
    114: empty_big_map
    54: lsr
    91: int
    5: left
    52: loop
    137: read_ticket
    107: timestamp
    49: lambda
    60: neq
    36: empty_set
    80: update
    146: constant
    126: sha3
    45: if_cons
    12: pack
    8: right
    10: true
    88: rename
    51: left
    68: right
    136: ticket
    84: address
    23: cdr
    109: operation
    63: not
    22: car
    103: signature
    73: self
    93: key_hash
    70: some
    40: ge
    86: isnat
    62: none
    112: dig
    11: unit
    29: create_contract
    71: source
    50: le
    79: unit
    108: unit
    119: self_address
    138: split_ticket
    13: unpack
    125: keccak
    55: lt
    28: create_account
    46: if_left
    43: hash_key
    117: chain_id
    105: bytes
    127: pairing_check
    104: string
    19: amount
    101: pair
    78: set_delegate
    6: none
    35: empty_map
    132: sapling_transaction
    0: parameter
    9: some
    82: iter
    94: lambda
    83: loop_left
    57: mem
    31: dip
    65: or
    95: list
    4: elt
    39: failwith
    58: mul
    26: concat
    21: balance
    102: set
    32: drop
    74: steps_to_quota
    77: transfer_tokens
    25: compare
    131: sapling_state
    142: chest_key
    130: bls12_381_fr
    53: lsl
    92: key
    16: sha512
    30: implicit_account
    18: add
    135: ticket
    100: or
    56: map
    110: address
    124: total_voting_power
    24: check_signature
    134: sapling_verify_update
    75: sub
    97: big_map
    61: nil
    106: mutez
    144: view
    20: and
    15: sha256
    145: view
    69: size
    1: storage
    128: bls12_381_g1
    99: option
    48: int
    7: pair
    129: bls12_381_g2
    96: map
    14: blake2b
    141: chest
    113: dug
    121: never
    3: false
    123: voting_power
    72: sender
    44: if
    17: abs
  big_map__update__prim__no_args__some_annots__id_011__pthangz2__michelson__v1__primitives:
    2: code
    115: apply
    76: swap
    27: cons
    33: dup
    111: slice
    59: neg
    41: get
    38: exec
    90: contract
    85: contract
    37: eq
    34: ediv
    133: sapling_empty_state
    89: bool
    87: cast
    81: xor
    140: get_and_update
    66: pair
    47: if_none
    64: now
    120: never
    42: gt
    98: nat
    67: push
    139: join_tickets
    122: unpair
    118: level
    143: open_chest
    116: chain_id
    114: empty_big_map
    54: lsr
    91: int
    5: left
    52: loop
    137: read_ticket
    107: timestamp
    49: lambda
    60: neq
    36: empty_set
    80: update
    146: constant
    126: sha3
    45: if_cons
    12: pack
    8: right
    10: true
    88: rename
    51: left
    68: right
    136: ticket
    84: address
    23: cdr
    109: operation
    63: not
    22: car
    103: signature
    73: self
    93: key_hash
    70: some
    40: ge
    86: isnat
    62: none
    112: dig
    11: unit
    29: create_contract
    71: source
    50: le
    79: unit
    108: unit
    119: self_address
    138: split_ticket
    13: unpack
    125: keccak
    55: lt
    28: create_account
    46: if_left
    43: hash_key
    117: chain_id
    105: bytes
    127: pairing_check
    104: string
    19: amount
    101: pair
    78: set_delegate
    6: none
    35: empty_map
    132: sapling_transaction
    0: parameter
    9: some
    82: iter
    94: lambda
    83: loop_left
    57: mem
    31: dip
    65: or
    95: list
    4: elt
    39: failwith
    58: mul
    26: concat
    21: balance
    102: set
    32: drop
    74: steps_to_quota
    77: transfer_tokens
    25: compare
    131: sapling_state
    142: chest_key
    130: bls12_381_fr
    53: lsl
    92: key
    16: sha512
    30: implicit_account
    18: add
    135: ticket
    100: or
    56: map
    110: address
    124: total_voting_power
    24: check_signature
    134: sapling_verify_update
    75: sub
    97: big_map
    61: nil
    106: mutez
    144: view
    20: and
    15: sha256
    145: view
    69: size
    1: storage
    128: bls12_381_g1
    99: option
    48: int
    7: pair
    129: bls12_381_g2
    96: map
    14: blake2b
    141: chest
    113: dug
    121: never
    3: false
    123: voting_power
    72: sender
    44: if
    17: abs
  big_map__update__prim__no_args__no_annots__id_011__pthangz2__michelson__v1__primitives:
    2: code
    115: apply
    76: swap
    27: cons
    33: dup
    111: slice
    59: neg
    41: get
    38: exec
    90: contract
    85: contract
    37: eq
    34: ediv
    133: sapling_empty_state
    89: bool
    87: cast
    81: xor
    140: get_and_update
    66: pair
    47: if_none
    64: now
    120: never
    42: gt
    98: nat
    67: push
    139: join_tickets
    122: unpair
    118: level
    143: open_chest
    116: chain_id
    114: empty_big_map
    54: lsr
    91: int
    5: left
    52: loop
    137: read_ticket
    107: timestamp
    49: lambda
    60: neq
    36: empty_set
    80: update
    146: constant
    126: sha3
    45: if_cons
    12: pack
    8: right
    10: true
    88: rename
    51: left
    68: right
    136: ticket
    84: address
    23: cdr
    109: operation
    63: not
    22: car
    103: signature
    73: self
    93: key_hash
    70: some
    40: ge
    86: isnat
    62: none
    112: dig
    11: unit
    29: create_contract
    71: source
    50: le
    79: unit
    108: unit
    119: self_address
    138: split_ticket
    13: unpack
    125: keccak
    55: lt
    28: create_account
    46: if_left
    43: hash_key
    117: chain_id
    105: bytes
    127: pairing_check
    104: string
    19: amount
    101: pair
    78: set_delegate
    6: none
    35: empty_map
    132: sapling_transaction
    0: parameter
    9: some
    82: iter
    94: lambda
    83: loop_left
    57: mem
    31: dip
    65: or
    95: list
    4: elt
    39: failwith
    58: mul
    26: concat
    21: balance
    102: set
    32: drop
    74: steps_to_quota
    77: transfer_tokens
    25: compare
    131: sapling_state
    142: chest_key
    130: bls12_381_fr
    53: lsl
    92: key
    16: sha512
    30: implicit_account
    18: add
    135: ticket
    100: or
    56: map
    110: address
    124: total_voting_power
    24: check_signature
    134: sapling_verify_update
    75: sub
    97: big_map
    61: nil
    106: mutez
    144: view
    20: and
    15: sha256
    145: view
    69: size
    1: storage
    128: bls12_381_g1
    99: option
    48: int
    7: pair
    129: bls12_381_g2
    96: map
    14: blake2b
    141: chest
    113: dug
    121: never
    3: false
    123: voting_power
    72: sender
    44: if
    17: abs
  micheline__011__pthangz2__michelson_v1__expression_tag:
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
  id_011__pthangz2__lazy_storage_diff_elt_tag:
    0: big_map
    1: sapling_state
seq:
- id: size_of_id_011__pthangz2__lazy_storage_diff
  type: u4
  valid:
    max: 1073741823
- id: id_011__pthangz2__lazy_storage_diff
  type: id_011__pthangz2__lazy_storage_diff_entries
  size: size_of_id_011__pthangz2__lazy_storage_diff
  repeat: eos
