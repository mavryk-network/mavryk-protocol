# Instruction coverage

This file documents Michelson instruction coverage by tzt tests as of protocol
Nairobi.

## Control structures

### `APPLY`

- [apply_00.mvt](apply_00.mvt)
- [apply_01.mvt](apply_01.mvt)
- [apply_02.mvt](apply_02.mvt)

Does not check the behavior that the values that are not both pushable and
storable cannot be captured.

### `EXEC`

- [exec_00.mvt](exec_00.mvt)
- [exec_01.mvt](exec_01.mvt)
- [exec_02.mvt](exec_02.mvt)
- [exec_03.mvt](exec_03.mvt)

### `FAILWITH`

- [failwith_00.mvt](failwith_00.mvt)

### `IF`

- [if_00.mvt](if_00.mvt)
- [if_01.mvt](if_01.mvt)

These tests do not check that the non-participating end of the stack, if it
exists, is preserved.

### `IF_CONS`

- [ifcons_listint_00.mvt](ifcons_listint_00.mvt)
- [ifcons_listint_01.mvt](ifcons_listint_01.mvt)
- [ifcons_listnat_00.mvt](ifcons_listnat_00.mvt)
- [ifcons_listnat_01.mvt](ifcons_listnat_01.mvt)

These tests do not check that the non-participating end of the stack, if it
exists, is preserved.

### `IF_LEFT`

- [ifleft_orintstring_00.mvt](ifleft_orintstring_00.mvt)
- [ifleft_orstringint_00.mvt](ifleft_orstringint_00.mvt)

These tests do not check that the non-participating end of the stack, if it
exists, is preserved.
### `IF_NONE`

- [ifnone_optionint_00.mvt](ifnone_optionint_00.mvt)
- [ifnone_optionnat_00.mvt](ifnone_optionnat_00.mvt)

These tests do not check that the non-participating end of the stack, if it
exists, is preserved.

### `LAMBDA`

***None***

### `LAMBDA_REC`

***None***

### `LOOP`

- [loop_00.mvt](loop_00.mvt)
- [loop_01.mvt](loop_01.mvt)
- [loop_02.mvt](loop_02.mvt)

### `LOOP_LEFT`

- [loopleft_00.mvt](loopleft_00.mvt)
- [loopleft_01.mvt](loopleft_01.mvt)
- [loopleft_02.mvt](loopleft_02.mvt)
- [loopleft_03.mvt](loopleft_03.mvt)
- [loopleft_04.mvt](loopleft_04.mvt)

### `;`

***None***

Instruction sequencing is indirectly covered by tzts including multiple instructions, but there are no dedicated unit tests.

### `{}`

***None***

## Stack manipulation

### `DIG`

- [dig_00.mvt](dig_00.mvt)
- [dig_01.mvt](dig_01.mvt)
- [dig_02.mvt](dig_02.mvt)
- [dig_03.mvt](dig_03.mvt)
- [dig_04.mvt](dig_04.mvt)

Even numbers are conspicuous by their absence.

### `DIP`

- [dip_00.mvt](dip_00.mvt)
- [dip_01.mvt](dip_01.mvt)
- [dip_02.mvt](dip_02.mvt)

DIP is used in quite a few other tests as an utility, so it's indirectly
covered.

### `DIP n`

- [dipn_00.mvt](dipn_00.mvt)
- [dipn_01.mvt](dipn_01.mvt)
- [dipn_02.mvt](dipn_02.mvt)
- [dipn_03.mvt](dipn_03.mvt)

### `DROP`

- [drop_00.mvt](drop_00.mvt)

Used a few times as an utility in other tzts.

### `DROP n`

- [dropn_00.mvt](dropn_00.mvt)
- [dropn_01.mvt](dropn_01.mvt)
- [dropn_02.mvt](dropn_02.mvt)
- [dropn_03.mvt](dropn_03.mvt)

### `DUG`

- [dugn_00.mvt](dugn_00.mvt)

`DUG 0`, `DUG 1` edge cases are missing.

### `DUP`

- [dup_00.mvt](dup_00.mvt)

### `DUP n`

- [dupn_00.mvt](dupn_00.mvt)
- [dupn_01.mvt](dupn_01.mvt)
- [dupn_02.mvt](dupn_02.mvt)
- [dupn_03.mvt](dupn_03.mvt)
- [dupn_04.mvt](dupn_04.mvt)

### `PUSH`

- [push_int_00.mvt](push_int_00.mvt)
- [push_string_00.mvt](push_string_00.mvt)

`PUSH` is used quite a bit as a utility in other tzts, hence indirectly covered
to some extent. Not all pushable types are tested with `PUSH`, however.

### `SWAP`

- [swap_00.mvt](swap_00.mvt)

## Arithmetic

### `ABS`

- [abs_00.mvt](abs_00.mvt)
- [abs_01.mvt](abs_01.mvt)
- [abs_02.mvt](abs_02.mvt)

### `ADD: nat : nat`

- [add_nat-nat_00.mvt](add_nat-nat_00.mvt)

### `ADD: nat : int`

- [add_nat-int_00.mvt](add_nat-int_00.mvt)

### `ADD: int : nat`

- [add_int-nat_00.mvt](add_int-nat_00.mvt)
- [add_int-nat_01.mvt](add_int-nat_01.mvt)

### `ADD: int : int`

- [add_int-int_00.mvt](add_int-int_00.mvt)

### `ADD: timestamp : int`

- [add_timestamp-int_00.mvt](add_timestamp-int_00.mvt)
- [add_timestamp-int_01.mvt](add_timestamp-int_01.mvt)
- [add_timestamp-int_02.mvt](add_timestamp-int_02.mvt)
- [add_timestamp-int_03.mvt](add_timestamp-int_03.mvt) -- doesn't use `ADD` instruction, only testing `timestamp`

### `ADD: int : timestamp`

- [add_int-timestamp_00.mvt](add_int-timestamp_00.mvt)

### `ADD: mumav : mumav`

- [add_mumav-mumav_00.mvt](add_mumav-mumav_00.mvt)
- [add_mumav-mumav_01.mvt](add_mumav-mumav_01.mvt)

### `ADD: bls12_381_g1 : bls12_381_g1`

***None***

### `ADD: bls12_381_g2 : bls12_381_g2`

***None***

### `ADD: bls12_381_fr : bls12_381_fr`

***None***

### `BYTES: int`

***None***

### `BYTES: nat`

***None***

### `COMPARE`

- [compare_bool_00.mvt](compare_bool_00.mvt)
- [compare_bool_01.mvt](compare_bool_01.mvt)
- [compare_bool_02.mvt](compare_bool_02.mvt)
- [compare_bool_03.mvt](compare_bool_03.mvt)
- [compare_bytes_00.mvt](compare_bytes_00.mvt)
- [compare_bytes_01.mvt](compare_bytes_01.mvt)
- [compare_bytes_02.mvt](compare_bytes_02.mvt)
- [compare_bytes_03.mvt](compare_bytes_03.mvt)
- [compare_bytes_04.mvt](compare_bytes_04.mvt)
- [compare_int_00.mvt](compare_int_00.mvt)
- [compare_int_01.mvt](compare_int_01.mvt)
- [compare_int_02.mvt](compare_int_02.mvt)
- [compare_int_03.mvt](compare_int_03.mvt)
- [compare_int_04.mvt](compare_int_04.mvt)
- [compare_keyhash_00.mvt](compare_keyhash_00.mvt)
- [compare_keyhash_01.mvt](compare_keyhash_01.mvt)
- [compare_keyhash_02.mvt](compare_keyhash_02.mvt)
- [compare_mumav_00.mvt](compare_mumav_00.mvt)
- [compare_mumav_01.mvt](compare_mumav_01.mvt)
- [compare_mumav_02.mvt](compare_mumav_02.mvt)
- [compare_mumav_03.mvt](compare_mumav_03.mvt)
- [compare_mumav_04.mvt](compare_mumav_04.mvt)
- [compare_mumav_05.mvt](compare_mumav_05.mvt)
- [compare_nat_00.mvt](compare_nat_00.mvt)
- [compare_nat_01.mvt](compare_nat_01.mvt)
- [compare_nat_02.mvt](compare_nat_02.mvt)
- [compare_nat_03.mvt](compare_nat_03.mvt)
- [compare_nat_04.mvt](compare_nat_04.mvt)
- [compare_nat_05.mvt](compare_nat_05.mvt)
- [compare_never_00.mvt](compare_never_00.mvt)
- [compare_pairintint_00.mvt](compare_pairintint_00.mvt)
- [compare_pairintint_01.mvt](compare_pairintint_01.mvt)
- [compare_pairintint_02.mvt](compare_pairintint_02.mvt)
- [compare_pairintint_03.mvt](compare_pairintint_03.mvt)
- [compare_string_00.mvt](compare_string_00.mvt)
- [compare_string_01.mvt](compare_string_01.mvt)
- [compare_string_02.mvt](compare_string_02.mvt)
- [compare_string_03.mvt](compare_string_03.mvt)
- [compare_string_04.mvt](compare_string_04.mvt)
- [compare_timestamp_00.mvt](compare_timestamp_00.mvt)
- [compare_timestamp_01.mvt](compare_timestamp_01.mvt)
- [compare_timestamp_02.mvt](compare_timestamp_02.mvt)
- [compare_timestamp_03.mvt](compare_timestamp_03.mvt)
- [compare_timestamp_04.mvt](compare_timestamp_04.mvt)
- [compare_timestamp_05.mvt](compare_timestamp_05.mvt)

Missing edge cases:

- No comparison of negative integers
- No comparison for `0 int`
- No comparison for `0 mumav`
- No comparison for `0 nat`
- Only zero- or single-character strings are compared

Duplicate files:

- `compare_mumav_03.mvt` is a duplicate of `compare_mumav_00.mvt`
- `compare_nat_03.mvt` is a duplicate of `compare_nat_00.mvt`

Types `COMPARE` isn't tested for:

- `address`
- `chain_id`
- `key`
- `signature`
- `timestamp`
- `unit`
- `or`
- `option`

### `EDIV: nat : nat`

***None***

### `EDIV: nat : int`

***None***

### `EDIV: int : nat`

***None***

### `EDIV: int : int`

- [ediv_int-int_00.mvt](ediv_int-int_00.mvt)
- [ediv_int-int_01.mvt](ediv_int-int_01.mvt)
- [ediv_int-int_02.mvt](ediv_int-int_02.mvt)
- [ediv_int-int_03.mvt](ediv_int-int_03.mvt)

Missing edge cases:

- No division of positive over positive
- No division of negative over negative
- No division of zero over non-zero
- No division of zero over zero
- No division with the result of 1

### `EDIV: mumav : nat`

- [ediv_mumav-nat_00.mvt](ediv_mumav-nat_00.mvt)
- [ediv_mumav-nat_01.mvt](ediv_mumav-nat_01.mvt)
- [ediv_mumav-nat_02.mvt](ediv_mumav-nat_02.mvt)
- [ediv_mumav-nat_03.mvt](ediv_mumav-nat_03.mvt)
- [ediv_mumav-nat_04.mvt](ediv_mumav-nat_04.mvt)
- [ediv_mumav-nat_05.mvt](ediv_mumav-nat_05.mvt)
- [ediv_mumav-nat_06.mvt](ediv_mumav-nat_06.mvt)

### `EDIV: mumav : mumav`

- [ediv_mumav-mumav_00.mvt](ediv_mumav-mumav_00.mvt)
- [ediv_mumav-mumav_01.mvt](ediv_mumav-mumav_01.mvt)
- [ediv_mumav-mumav_02.mvt](ediv_mumav-mumav_02.mvt)
- [ediv_mumav-mumav_03.mvt](ediv_mumav-mumav_03.mvt)

Missing edge cases:

- No division of zero over non-zero
- No division of zero over zero

### `EQ`

- [eq_00.mvt](eq_00.mvt)
- [eq_01.mvt](eq_01.mvt)
- [eq_02.mvt](eq_02.mvt)
- [eq_03.mvt](eq_03.mvt)
- [eq_04.mvt](eq_04.mvt)

### `GE`

- [ge_00.mvt](ge_00.mvt)
- [ge_01.mvt](ge_01.mvt)
- [ge_02.mvt](ge_02.mvt)
- [ge_03.mvt](ge_03.mvt)
- [ge_04.mvt](ge_04.mvt)

### `GT`

- [gt_00.mvt](gt_00.mvt)
- [gt_01.mvt](gt_01.mvt)
- [gt_02.mvt](gt_02.mvt)
- [gt_03.mvt](gt_03.mvt)
- [gt_04.mvt](gt_04.mvt)

### `INT: nat`

- [int_nat_00.mvt](int_nat_00.mvt)
- [int_nat_01.mvt](int_nat_01.mvt)

### `INT: bls12_381_fr`

***None***

### `INT: bytes`

***None***

### `ISNAT`

- [isnat_00.mvt](isnat_00.mvt)
- [isnat_01.mvt](isnat_01.mvt)

Missing edge cases:

- Only tests `0` and `-1`, missing tests for positive integers.

### `LE`

- [le_00.mvt](le_00.mvt)
- [le_01.mvt](le_01.mvt)
- [le_02.mvt](le_02.mvt)
- [le_03.mvt](le_03.mvt)
- [le_04.mvt](le_04.mvt)

### `LSL: nat : nat`

- [lsl_00.mvt](lsl_00.mvt)
- [lsl_01.mvt](lsl_01.mvt)
- [lsl_02.mvt](lsl_02.mvt)
- [lsl_03.mvt](lsl_03.mvt)
- [lsl_04.mvt](lsl_04.mvt)
- [lsl_05.mvt](lsl_05.mvt)
- [lsl_06.mvt](lsl_06.mvt)

Missing edge cases:

- No zero shift test for non-zero argument

### `LSL: bytes : nat`

***None***

### `LSR: nat : nat`

- [lsr_00.mvt](lsr_00.mvt)
- [lsr_01.mvt](lsr_01.mvt)
- [lsr_02.mvt](lsr_02.mvt)
- [lsr_03.mvt](lsr_03.mvt)
- [lsr_04.mvt](lsr_04.mvt)
- [lsr_05.mvt](lsr_05.mvt)

Missing edge cases:

- No zero shift test for non-zero argument

### `LSR: bytes : nat`

***None***

### `LT`

- [lt_00.mvt](lt_00.mvt)
- [lt_01.mvt](lt_01.mvt)
- [lt_02.mvt](lt_02.mvt)
- [lt_03.mvt](lt_03.mvt)
- [lt_04.mvt](lt_04.mvt)

### `MUL: nat : nat`

- [mul_nat-nat_00.mvt](mul_nat-nat_00.mvt)

Missing edge cases:

- No multiplication by zero (both from left and right)

### `MUL: nat : int`

- [mul_nat-int_00.mvt](mul_nat-int_00.mvt)

Missing edge cases:

- No multiplication by zero (both from left and right)
- No multiplication by positive int

### `MUL: int : nat`

- [mul_int-nat_00.mvt](mul_int-nat_00.mvt)

Missing edge cases:

- No multiplication by zero (both from left and right)
- No multiplication by negative int

### `MUL: int : int`

- [mul_int-int_00.mvt](mul_int-int_00.mvt)

Missing edge cases:

- No multiplication by zero (both from left and right)
- No multiplication of two negatives
- No multiplication of two positives
- No multiplication of negative by positive

### `MUL: mumav : nat`

- [mul_mumav-nat_00.mvt](mul_mumav-nat_00.mvt)
- [mul_mumav-nat_01.mvt](mul_mumav-nat_01.mvt)

Missing edge cases:

- No multiplication by zero (both from left and right)

### `MUL: nat : mumav`

- [mul_nat-mumav_00.mvt](mul_nat-mumav_00.mvt)
- [mul_nat-mumav_01.mvt](mul_nat-mumav_01.mvt)

Missing edge cases:

- No multiplication by zero (both from left and right)

### `MUL: bls12_381_g1 : bls12_381_fr`

***None***

### `MUL: bls12_381_g2 : bls12_381_fr`

***None***

### `MUL: bls12_381_fr : bls12_381_fr`

***None***

### `MUL: nat : bls12_381_fr`

***None***

### `MUL: int : bls12_381_fr`

***None***

### `MUL: bls12_381_fr : nat`

***None***

### `MUL: bls12_381_fr : int`

***None***

### `NAT`

***None***

### `NEG: nat`

- [neg_nat_00.mvt](neg_nat_00.mvt)
- [neg_nat_01.mvt](neg_nat_01.mvt)

### `NEG: int`

- [neg_int_00.mvt](neg_int_00.mvt)
- [neg_int_01.mvt](neg_int_01.mvt)
- [neg_int_02.mvt](neg_int_02.mvt)

### `NEG: bls12_381_g1`

***None***

### `NEG: bls12_381_g2`

***None***

### `NEG: bls12_381_fr`

***None***

### `NEQ`

- [neq_00.mvt](neq_00.mvt)
- [neq_01.mvt](neq_01.mvt)
- [neq_02.mvt](neq_02.mvt)
- [neq_03.mvt](neq_03.mvt)
- [neq_04.mvt](neq_04.mvt)

### `SUB: nat : nat`

***None***

### `SUB: nat : int`

***None***

### `SUB: int : nat`

***None***

### `SUB: int : int`

- [sub_int-int_00.mvt](sub_int-int_00.mvt)
- [sub_int-int_01.mvt](sub_int-int_01.mvt)

Missing edge cases:

- No subtraction of 0
- No subtraction from 0
- No subtraction of negative integers

### `SUB: timestamp : int`

- [sub_timestamp-int_00.mvt](sub_timestamp-int_00.mvt)
- [sub_timestamp-int_01.mvt](sub_timestamp-int_01.mvt)
- [sub_timestamp-int_02.mvt](sub_timestamp-int_02.mvt)
- [sub_timestamp-int_03.mvt](sub_timestamp-int_03.mvt)
- [sub_timestamp-int_04.mvt](sub_timestamp-int_04.mvt)

Missing edge cases:

- No subtraction of zero
- No subtraction from zero

### `SUB: timestamp : timestamp`

- [sub_timestamp-timestamp_00.mvt](sub_timestamp-timestamp_00.mvt)
- [sub_timestamp-timestamp_01.mvt](sub_timestamp-timestamp_01.mvt)
- [sub_timestamp-timestamp_02.mvt](sub_timestamp-timestamp_02.mvt)
- [sub_timestamp-timestamp_03.mvt](sub_timestamp-timestamp_03.mvt)

Missing edge cases:

- No test for realistic timestamps producing negative difference

### `SUB_MUMAV`

***None***, but there are tests for the deprecated `SUB: mumav : mumav`:

- [sub_mumav-mumav_00.mvt](sub_mumav-mumav_00.mvt)
- [sub_mumav-mumav_01.mvt](sub_mumav-mumav_01.mvt)

## Boolean operations

### `AND bool:bool`

- [and_bool-bool_00.mvt](and_bool-bool_00.mvt)
- [and_bool-bool_01.mvt](and_bool-bool_01.mvt)
- [and_bool-bool_02.mvt](and_bool-bool_02.mvt)
- [and_bool-bool_03.mvt](and_bool-bool_03.mvt)

### `AND nat:nat`

- [and_nat-nat_00.mvt](and_nat-nat_00.mvt)
- [and_nat-nat_01.mvt](and_nat-nat_01.mvt)
- [and_nat-nat_02.mvt](and_nat-nat_02.mvt)

Missing edge cases:

- One argument is `0` (both from left and right)
- Result is `0` with non-zero arguments

### `AND int:nat`

- [and_int-nat_00.mvt](and_int-nat_00.mvt)
- [and_int-nat_01.mvt](and_int-nat_01.mvt)
- [and_int-nat_02.mvt](and_int-nat_02.mvt)
- [and_int-nat_03.mvt](and_int-nat_03.mvt)
- [and_int-nat_04.mvt](and_int-nat_04.mvt)
- [and_int-nat_05.mvt](and_int-nat_05.mvt)
- [and_int-nat_06.mvt](and_int-nat_06.mvt)

### `AND: bytes:bytes`

- [and_bytes-bytes_00.mvt](and_bytes-bytes_00.mvt)
- [and_bytes-bytes_01.mvt](and_bytes-bytes_01.mvt)
- [and_bytes-bytes_02.mvt](and_bytes-bytes_02.mvt)
- [and_bytes-bytes_03.mvt](and_bytes-bytes_03.mvt)
- [and_bytes-bytes_04.mvt](and_bytes-bytes_04.mvt)
- [and_bytes-bytes_05.mvt](and_bytes-bytes_05.mvt)
- [and_bytes-bytes_06.mvt](and_bytes-bytes_06.mvt)

### `NOT: bool`

- [not_bool_00.mvt](not_bool_00.mvt)
- [not_bool_01.mvt](not_bool_01.mvt)

### `NOT: nat`

- [not_nat_00.mvt](not_nat_00.mvt)
- [not_nat_01.mvt](not_nat_01.mvt)
- [not_nat_02.mvt](not_nat_02.mvt)

### `NOT: int`

- [not_int_00.mvt](not_int_00.mvt)
- [not_nat_03.mvt](not_nat_03.mvt)
- [not_nat_04.mvt](not_nat_04.mvt)
- [not_nat_05.mvt](not_nat_05.mvt)
- [not_nat_06.mvt](not_nat_06.mvt)
- [not_nat_07.mvt](not_nat_07.mvt)

Files do not follow naming convention.

### `NOT: bytes`

- [not_bytes_00.mvt](not_bytes_00.mvt)
- [not_bytes_01.mvt](not_bytes_01.mvt)
- [not_bytes_02.mvt](not_bytes_02.mvt)
- [not_bytes_03.mvt](not_bytes_03.mvt)
- [not_bytes_04.mvt](not_bytes_04.mvt)
- [not_bytes_05.mvt](not_bytes_05.mvt)

### `OR bool:bool`

- [or_bool-bool_00.mvt](or_bool-bool_00.mvt)
- [or_bool-bool_01.mvt](or_bool-bool_01.mvt)
- [or_bool-bool_02.mvt](or_bool-bool_02.mvt)
- [or_bool-bool_03.mvt](or_bool-bool_03.mvt)

### `OR nat:nat`

- [or_nat-nat_00.mvt](or_nat-nat_00.mvt)
- [or_nat-nat_01.mvt](or_nat-nat_01.mvt)
- [or_nat-nat_02.mvt](or_nat-nat_02.mvt)
- [or_nat-nat_03.mvt](or_nat-nat_03.mvt)
- [or_nat-nat_04.mvt](or_nat-nat_04.mvt)
- [or_nat-nat_05.mvt](or_nat-nat_05.mvt)
- [or_nat-nat_06.mvt](or_nat-nat_06.mvt)

### `OR bytes`

- [or_bytes-bytes_00.mvt](or_bytes-bytes_00.mvt)
- [or_bytes-bytes_01.mvt](or_bytes-bytes_01.mvt)
- [or_bytes-bytes_02.mvt](or_bytes-bytes_02.mvt)
- [or_bytes-bytes_03.mvt](or_bytes-bytes_03.mvt)
- [or_bytes-bytes_04.mvt](or_bytes-bytes_04.mvt)
- [or_bytes-bytes_05.mvt](or_bytes-bytes_05.mvt)
- [or_bytes-bytes_06.mvt](or_bytes-bytes_06.mvt)

### `XOR: bool:bool`

- [xor_bool-bool_00.mvt](xor_bool-bool_00.mvt)
- [xor_bool-bool_01.mvt](xor_bool-bool_01.mvt)
- [xor_bool-bool_02.mvt](xor_bool-bool_02.mvt)
- [xor_bool-bool_03.mvt](xor_bool-bool_03.mvt)

### `XOR: nat:nat`

- [xor_nat-nat_00.mvt](xor_nat-nat_00.mvt)
- [xor_nat-nat_01.mvt](xor_nat-nat_01.mvt)
- [xor_nat-nat_02.mvt](xor_nat-nat_02.mvt)
- [xor_nat-nat_03.mvt](xor_nat-nat_03.mvt)
- [xor_nat-nat_04.mvt](xor_nat-nat_04.mvt)
- [xor_nat-nat_05.mvt](xor_nat-nat_05.mvt)
- [xor_nat-nat_06.mvt](xor_nat-nat_06.mvt)

### `XOR: bytes:bytes`

- [xor_bytes-bytes_00.mvt](xor_bytes-bytes_00.mvt)
- [xor_bytes-bytes_01.mvt](xor_bytes-bytes_01.mvt)
- [xor_bytes-bytes_02.mvt](xor_bytes-bytes_02.mvt)
- [xor_bytes-bytes_03.mvt](xor_bytes-bytes_03.mvt)
- [xor_bytes-bytes_04.mvt](xor_bytes-bytes_04.mvt)
- [xor_bytes-bytes_05.mvt](xor_bytes-bytes_05.mvt)
- [xor_bytes-bytes_06.mvt](xor_bytes-bytes_06.mvt)

## Data structure manipulation

### `CAR`

- [car_00.mvt](car_00.mvt)
- [car_01.mvt](car_01.mvt)

### `CDR`

- [cdr_00.mvt](cdr_00.mvt)
- [cdr_01.mvt](cdr_01.mvt)

### `CONCAT: string : string`

- [concat_string_00.mvt](concat_string_00.mvt)
- [concat_string_01.mvt](concat_string_01.mvt)
- [concat_string_02.mvt](concat_string_02.mvt)

### `CONCAT: list string`

- [concat_liststring_00.mvt](concat_liststring_00.mvt)
- [concat_liststring_01.mvt](concat_liststring_01.mvt)
- [concat_liststring_02.mvt](concat_liststring_02.mvt)
- [concat_liststring_03.mvt](concat_liststring_03.mvt)
- [concat_liststring_04.mvt](concat_liststring_04.mvt)

### `CONCAT: bytes : bytes`

- [concat_bytes_00.mvt](concat_bytes_00.mvt)
- [concat_bytes_01.mvt](concat_bytes_01.mvt)

### `CONCAT: list bytes`

- [concat_listbytes_00.mvt](concat_listbytes_00.mvt)
- [concat_listbytes_01.mvt](concat_listbytes_01.mvt)
- [concat_listbytes_02.mvt](concat_listbytes_02.mvt)

### `CONS`

- [cons_int_00.mvt](cons_int_00.mvt)
- [cons_int_01.mvt](cons_int_01.mvt)
- [cons_int_02.mvt](cons_int_02.mvt)
- [cons_string_00.mvt](cons_string_00.mvt)

### `EMPTY_BIG_MAP`

- [emptybigmap_nat-nat_00.mvt](emptybigmap_nat-nat_00.mvt)

### `EMPTY_MAP`

- [emptymap_nat-nat_00.mvt](emptymap_nat-nat_00.mvt)
- [emptymap_string-string_00.mvt](emptymap_string-string_00.mvt)

### `EMPTY_SET`

- [emptyset_nat_00.mvt](emptyset_nat_00.mvt)

### `GET: kty : map kty vty`

- [get_mapintint_00.mvt](get_mapintint_00.mvt)
- [get_mapintint_01.mvt](get_mapintint_01.mvt)
- [get_mapstringstring_00.mvt](get_mapstringstring_00.mvt)
- [get_mapstringstring_01.mvt](get_mapstringstring_01.mvt)
- [get_mapstringstring_02.mvt](get_mapstringstring_02.mvt)

### `GET: kty : big_map kty vty`

- [get_bigmapstringstring_00.mvt](get_bigmapstringstring_00.mvt)
- [get_bigmapstringstring_01.mvt](get_bigmapstringstring_01.mvt)
- [get_bigmapstringstring_02.mvt](get_bigmapstringstring_02.mvt)

### `GET n`

***None***

### `GET_AND_UPDATE: kty : option vty : map kty vty`

***None***

### `GET_AND_UPDATE: kty : option vty : big_map kty vty`

***None***

### `ITER: list ty`

- [iter_listint_00.mvt](iter_listint_00.mvt)
- [iter_listint_01.mvt](iter_listint_01.mvt)
- [iter_listint_02.mvt](iter_listint_02.mvt)
- [iter_listint_03.mvt](iter_listint_03.mvt)
- [iter_liststring_00.mvt](iter_liststring_00.mvt)
- [iter_liststring_01.mvt](iter_liststring_01.mvt)

### `ITER: set cty`

- [iter_setint_00.mvt](iter_setint_00.mvt)
- [iter_setint_01.mvt](iter_setint_01.mvt)
- [iter_setint_02.mvt](iter_setint_02.mvt)
- [iter_setstring_00.mvt](iter_setstring_00.mvt)
- [iter_setstring_01.mvt](iter_setstring_01.mvt)
- [iter_setstring_02.mvt](iter_setstring_02.mvt)

### `ITER: map kty vty`

- [iter_mapintint_00.mvt](iter_mapintint_00.mvt)
- [iter_mapintint_01.mvt](iter_mapintint_01.mvt)
- [iter_mapintint_02.mvt](iter_mapintint_02.mvt)
- [iter_mapintint_03.mvt](iter_mapintint_03.mvt)
- [iter_mapintint_04.mvt](iter_mapintint_04.mvt)
- [iter_mapstringstring_00.mvt](iter_mapstringstring_00.mvt)

### `LEFT`

- [left_int-nat_00.mvt](left_int-nat_00.mvt)

### `MAP: list ty`

- [map_listint_00.mvt](map_listint_00.mvt)
- [map_listint_01.mvt](map_listint_01.mvt)
- [map_listint_02.mvt](map_listint_02.mvt)
- [map_listint_03.mvt](map_listint_03.mvt)
- [map_listint_04.mvt](map_listint_04.mvt)
- [map_listint_05.mvt](map_listint_05.mvt)
- [map_listint_06.mvt](map_listint_06.mvt)
- [map_liststring_00.mvt](map_liststring_00.mvt)
- [map_liststring_01.mvt](map_liststring_01.mvt)
- [map_liststring_02.mvt](map_liststring_02.mvt)
- [map_liststring_04.mvt](map_liststring_04.mvt)
- [map_liststring_05.mvt](map_liststring_05.mvt)
- [map_liststring_06.mvt](map_liststring_06.mvt)
- [map_liststring_07.mvt](map_liststring_07.mvt)
- [map_liststring_08.mvt](map_liststring_08.mvt)

### `MAP: option ty`

***None***

### `MAP: map kty ty1`

- [map_mapintint_00.mvt](map_mapintint_00.mvt)
- [map_mapintint_01.mvt](map_mapintint_01.mvt)
- [map_mapintstring_00.mvt](map_mapintstring_00.mvt)
- [map_mapintstring_01.mvt](map_mapintstring_01.mvt)
- [map_mapstringnat_00.mvt](map_mapstringnat_00.mvt)
- [map_mapstringnat_01.mvt](map_mapstringnat_01.mvt)
- [map_mapstringnat_02.mvt](map_mapstringnat_02.mvt)

### `MEM: cty : set cty`

- [mem_setint_00.mvt](mem_setint_00.mvt)
- [mem_setint_01.mvt](mem_setint_01.mvt)
- [mem_setstring_00.mvt](mem_setstring_00.mvt)
- [mem_setstring_01.mvt](mem_setstring_01.mvt)
- [mem_setstring_02.mvt](mem_setstring_02.mvt)

### `MEM: kty : map kty vty`

- [mem_mapintint_00.mvt](mem_mapintint_00.mvt)
- [mem_mapnatnat_00.mvt](mem_mapnatnat_00.mvt)
- [mem_mapnatnat_01.mvt](mem_mapnatnat_01.mvt)
- [mem_mapnatnat_02.mvt](mem_mapnatnat_02.mvt)
- [mem_mapnatnat_03.mvt](mem_mapnatnat_03.mvt)
- [mem_mapnatnat_04.mvt](mem_mapnatnat_04.mvt)
- [mem_mapnatnat_05.mvt](mem_mapnatnat_05.mvt)
- [mem_mapstringnat_00.mvt](mem_mapstringnat_00.mvt)
- [mem_mapstringnat_01.mvt](mem_mapstringnat_01.mvt)
- [mem_mapstringnat_02.mvt](mem_mapstringnat_02.mvt)
- [mem_mapstringnat_03.mvt](mem_mapstringnat_03.mvt)
- [mem_mapstringnat_04.mvt](mem_mapstringnat_04.mvt)
- [mem_mapstringnat_05.mvt](mem_mapstringnat_05.mvt)

### `MEM: kty : big_map kty vty`

- [mem_bigmapnatnat_00.mvt](mem_bigmapnatnat_00.mvt)
- [mem_bigmapnatnat_01.mvt](mem_bigmapnatnat_01.mvt)
- [mem_bigmapnatnat_02.mvt](mem_bigmapnatnat_02.mvt)
- [mem_bigmapnatnat_03.mvt](mem_bigmapnatnat_03.mvt)
- [mem_bigmapnatnat_04.mvt](mem_bigmapnatnat_04.mvt)
- [mem_bigmapnatnat_05.mvt](mem_bigmapnatnat_05.mvt)
- [mem_bigmapstringnat_00.mvt](mem_bigmapstringnat_00.mvt)
- [mem_bigmapstringnat_01.mvt](mem_bigmapstringnat_01.mvt)
- [mem_bigmapstringnat_02.mvt](mem_bigmapstringnat_02.mvt)
- [mem_bigmapstringnat_03.mvt](mem_bigmapstringnat_03.mvt)
- [mem_bigmapstringnat_04.mvt](mem_bigmapstringnat_04.mvt)
- [mem_bigmapstringnat_05.mvt](mem_bigmapstringnat_05.mvt)

### `NEVER`

- [never_00.mvt](never_00.mvt)

### `NIL`

- [nil_nat_00.mvt](nil_nat_00.mvt)

### `NONE`

- [none_int_00.mvt](none_int_00.mvt)
- [none_pair-nat-string.mvt](none_pair-nat-string.mvt)

### `PACK`

- `pack_*.mvt`
- [packunpack_address_00.mvt](packunpack_address_00.mvt)
- [packunpack_bool_00.mvt](packunpack_bool_00.mvt)
- [packunpack_bytes_00.mvt](packunpack_bytes_00.mvt)
- [packunpack_int_00.mvt](packunpack_int_00.mvt)
- [packunpack_keyhash_00.mvt](packunpack_keyhash_00.mvt)
- [packunpack_mumav_00.mvt](packunpack_mumav_00.mvt)
- [packunpack_nat_00.mvt](packunpack_nat_00.mvt)
- [packunpack_string_00.mvt](packunpack_string_00.mvt)
- [packunpack_timestamp_00.mvt](packunpack_timestamp_00.mvt)

Only few value types are covered.

Among tests on values serialization:
- Addresses with entrypoints are not covered.

### `PAIR`

- [pair_int-int_00.mvt](pair_int-int_00.mvt)
- [pair_nat-string_00.mvt](pair_nat-string_00.mvt)
- [pair_pair-nat-string-pair-string-nat_00.mvt](pair_pair-nat-string-pair-string-nat_00.mvt)

### `PAIR n`

***None***

### `RIGHT`

- [right_nat-int_00.mvt](right_nat-int_00.mvt)

### `SIZE: set cty`

- [size_setint_00.mvt](size_setint_00.mvt)
- [size_setint_01.mvt](size_setint_01.mvt)
- [size_setint_02.mvt](size_setint_02.mvt)
- [size_setint_03.mvt](size_setint_03.mvt)
- [size_setstring_00.mvt](size_setstring_00.mvt)

### `SIZE: map kty vty`

- [size_mapintint_00.mvt](size_mapintint_00.mvt)
- [size_mapstringnat_00.mvt](size_mapstringnat_00.mvt)
- [size_mapstringnat_01.mvt](size_mapstringnat_01.mvt)
- [size_mapstringnat_02.mvt](size_mapstringnat_02.mvt)
- [size_mapstringnat_03.mvt](size_mapstringnat_03.mvt)

### `SIZE: list ty`

- [size_listint_00.mvt](size_listint_00.mvt)
- [size_listint_01.mvt](size_listint_01.mvt)
- [size_listint_02.mvt](size_listint_02.mvt)
- [size_listint_03.mvt](size_listint_03.mvt)

### `SIZE: string`

- [size_string_00.mvt](size_string_00.mvt)

### `SIZE: bytes`

- [size_bytes_00.mvt](size_bytes_00.mvt)

### `SLICE: nat : nat : string`

- [slice_string_00.mvt](slice_string_00.mvt)
- [slice_string_01.mvt](slice_string_01.mvt)
- [slice_string_02.mvt](slice_string_02.mvt)
- [slice_string_03.mvt](slice_string_03.mvt)
- [slice_string_04.mvt](slice_string_04.mvt)
- [slice_string_05.mvt](slice_string_05.mvt)

### `SLICE: nat : nat : bytes`

- [slice_bytes_00.mvt](slice_bytes_00.mvt)
- [slice_bytes_01.mvt](slice_bytes_01.mvt)
- [slice_bytes_02.mvt](slice_bytes_02.mvt)
- [slice_bytes_03.mvt](slice_bytes_03.mvt)
- [slice_bytes_04.mvt](slice_bytes_04.mvt)

### `SOME`

- [some_int_00.mvt](some_int_00.mvt)
- [some_pairintint_00.mvt](some_pairintint_00.mvt)
- [some_string_00.mvt](some_string_00.mvt)

### `UNIT`

- [unit_00.mvt](unit_00.mvt)

### `UNPACK`

- [packunpack_address_00.mvt](packunpack_address_00.mvt)
- [packunpack_bool_00.mvt](packunpack_bool_00.mvt)
- [packunpack_bytes_00.mvt](packunpack_bytes_00.mvt)
- [packunpack_int_00.mvt](packunpack_int_00.mvt)
- [packunpack_keyhash_00.mvt](packunpack_keyhash_00.mvt)
- [packunpack_mumav_00.mvt](packunpack_mumav_00.mvt)
- [packunpack_nat_00.mvt](packunpack_nat_00.mvt)
- [packunpack_string_00.mvt](packunpack_string_00.mvt)
- [packunpack_timestamp_00.mvt](packunpack_timestamp_00.mvt)

Tested only with conjunction with `PACK`

### `UNPAIR`

- [unpair_pairstringstring_00.mvt](unpair_pairstringstring_00.mvt)

### `UPDATE: cty : bool : set cty`

- [update_setint_00.mvt](update_setint_00.mvt)
- [update_setint_01.mvt](update_setint_01.mvt)
- [update_setint_02.mvt](update_setint_02.mvt)

### `UPDATE: kty : option vty : map kty vty`

- [update_mapintint_00.mvt](update_mapintint_00.mvt)
- [update_mapintint_01.mvt](update_mapintint_01.mvt)

### `UPDATE: kty : option vty : big_map kty vty`

- [update_bigmapstringstring_00.mvt](update_bigmapstringstring_00.mvt)
- [update_bigmapstringstring_01.mvt](update_bigmapstringstring_01.mvt)
- [update_bigmapstringstring_02.mvt](update_bigmapstringstring_02.mvt)
- [update_bigmapstringstring_03.mvt](update_bigmapstringstring_03.mvt)
- [update_bigmapstringstring_04.mvt](update_bigmapstringstring_04.mvt)
- [update_bigmapstringstring_05.mvt](update_bigmapstringstring_05.mvt)
- [update_bigmapstringstring_06.mvt](update_bigmapstringstring_06.mvt)
- [update_bigmapstringstring_07.mvt](update_bigmapstringstring_07.mvt)

### `UPDATE n`

***None***

## Ticket manipulation

### `JOIN_TICKETS`

- [join_tickets_00.mvt](join_tickets_00.mvt)
- [join_tickets_01.mvt](join_tickets_01.mvt)
- [join_tickets_02.mvt](join_tickets_02.mvt)
- [join_tickets_03.mvt](join_tickets_03.mvt)

### `READ_TICKET`

- [read_ticket_00.mvt](read_ticket_00.mvt)

### `SPLIT_TICKET`

- [split_ticket_00.mvt](split_ticket_00.mvt)
- [split_ticket_01.mvt](split_ticket_01.mvt)
- [split_ticket_02.mvt](split_ticket_02.mvt)
- [split_ticket_03.mvt](split_ticket_03.mvt)
- [split_ticket_04.mvt](split_ticket_04.mvt)

### `TICKET`

- [ticket_00.mvt](ticket_00.mvt)
- [ticket_01.mvt](ticket_01.mvt)

## Cryptographic operations

Not covered

### `BLAKE2B`

- [blake2b_00.mvt](blake2b_00.mvt)
- [blake2b_01.mvt](blake2b_01.mvt)

### `CHECK_SIGNATURE`

- [checksignature_00.mvt](checksignature_00.mvt)
- [checksignature_01.mvt](checksignature_01.mvt)

Does not check different types of key.

### `HASH_KEY`

***None***

### `KECCAK`

- [keccak_00.mvt](keccak_00.mvt)
- [keccak_01.mvt](keccak_01.mvt)

### `PAIRING_CHECK`

***None***

### `SAPLING_EMPTY_STATE ms`

***None***

### `SAPLING_VERIFY_UPDATE`

***None***

### `SHA256`

- [sha256_00.mvt](sha256_00.mvt)
- [sha256_01.mvt](sha256_01.mvt)

### `SHA3`

- [sha3_00.mvt](sha3_00.mvt)
- [sha3_01.mvt](sha3_01.mvt)

### `SHA512`

- [sha512_00.mvt](sha512_00.mvt)
- [sha512_01.mvt](sha512_01.mvt)

## Blockchain operations

### `ADDRESS`

- [address_00.mvt](address_00.mvt)
- [address_01.mvt](address_01.mvt) -- on implicit contract
- [address_02.mvt](address_02.mvt)

### `AMOUNT`

- [amount_00.mvt](amount_00.mvt)

### `BALANCE`

- [balance_00.mvt](balance_00.mvt)

### `CHAIN_ID`

- [chain_id_00.mvt](chain_id_00.mvt)
- [chain_id_01.mvt](chain_id_01.mvt)

### `CONTRACT`

Note: invariants are taken from the table in <https://mavryk-network.gitlab.io/michelson-reference/#instr-CONTRACT> section, copied below for posterity.

- [contract_00.mvt](contract_00.mvt) -- valid_contract_type "addr" t holds
- [contract_01.mvt](contract_01.mvt) -- no_contract "addr" holds
- [contract_02.mvt](contract_02.mvt) -- invalid_contract_type "addr" t holds
- [contract_03.mvt](contract_03.mvt) -- valid_contract_type "addr" t holds
- [contract_04.mvt](contract_04.mvt) -- valid_contract_type "addr" t holds on implicit contract
- [contract_05.mvt](contract_05.mvt) -- no_contract "addr" holds

No tests with entrypoints (the cases represented by rows 3, 4, 5, 6, 7, 9, 10 from the table are not covered)

```
+---------------+---------------------+------------------------------------------+-------------------------------------------------+
| input address | instruction         | output contract                          | predicate                                       |
+---------------+---------------------+------------------------------------------+-------------------------------------------------+
| "addr"        | CONTRACT t          | None if addr does not exist              | no_contract "addr" holds                        |
+---------------+---------------------+------------------------------------------+-------------------------------------------------+
| "addr"        | CONTRACT t          | None if addr exists, but has a default   | invalid_contract_type "addr" t holds            |
|               |                     | entrypoint not of type t, or has no      |                                                 |
|               |                     | default entrypoint and parameter is not  |                                                 |
|               |                     | of type t                                |                                                 |
+---------------+---------------------+------------------------------------------+-------------------------------------------------+
| "addr%name"   | CONTRACT t          | None if addr does not exist, or exists   | no_contract "addr%name" holds                   |
|               |                     | but does not have a "name" entrypoint    |                                                 |
+---------------+---------------------+                                          |                                                 |
| "addr"        | CONTRACT %name t    |                                          |                                                 |
|               |                     |                                          |                                                 |
+---------------+---------------------+------------------------------------------+-------------------------------------------------+
| "addr%name"   | CONTRACT t          | None if addr exists, but has an          | invalid_contract_type "addr%name" t holds       |
|               |                     | entrypoint %name not of type t           |                                                 |
+---------------+---------------------+                                          |                                                 |
| "addr"        | CONTRACT %name t    |                                          |                                                 |
+---------------+---------------------+------------------------------------------+-------------------------------------------------+
| "addr%name1"  | CONTRACT %name2 t   | None                                     | entrypoint_ambiguity "addr%name1" "name2" holds |
+---------------+---------------------+------------------------------------------+-------------------------------------------------+
| "addr"        | CONTRACT t          | (Some "addr") if contract exists, has a  | valid_contract_type "addr" t holds              |
|               |                     | default entrypoint of type t, or has no  |                                                 |
|               |                     | default entrypoint and parameter type t  |                                                 |
+---------------+---------------------+------------------------------------------+-------------------------------------------------+
| "addr%name"   | CONTRACT t          | (Some "addr%name") if addr exists and    | valid_contract_type "addr%name" t holds         |
+---------------+---------------------+ has an entrypoint %name of type t        |                                                 |
| "addr"        | CONTRACT %name t    |                                          |                                                 |
+---------------+---------------------+------------------------------------------+-------------------------------------------------+
```

### `CREATE_CONTRACT`

- [createcontract_00.mvt](createcontract_00.mvt)
- [createcontract_01.mvt](createcontract_01.mvt)

### `EMIT`

***None***

### `IMPLICIT_ACCOUNT`

- [implicitaccount_00.mvt](implicitaccount_00.mvt)

### `LEVEL`

***None***

TZT format doesn't have the necessary field(s) to set the return value of `LEVEL` instruction

### `MIN_BLOCK_TIME`

***None***

TZT format doesn't have the necessary field(s) to set the return value of
`MIN_BLOCK_TIME` instruction

### `NOW`

- [now_00.mvt](now_00.mvt)

### `SELF`

- [self_00.mvt](self_00.mvt)

### `SELF_ADDRESS`

***None***

### `SENDER`

- [sender_00.mvt](sender_00.mvt)

It would be nice to add test where the result of `SOURCE` isn't equal to the result of `SENDER`

### `SET_DELEGATE`

- [setdelegate_00.mvt](setdelegate_00.mvt)

No test with `None` parameter

### `SOURCE`

- [source_00.mvt](source_00.mvt)

### `TOTAL_VOTING_POWER`

***None***

TZT format doesn't have the necessary field(s) to set the return value of
`TOTAL_VOTING_POWER` instruction

### `TRANSFER_TOKENS`

- [transfertokens_00.mvt](transfertokens_00.mvt)
- [transfertokens_01.mvt](transfertokens_01.mvt)

### `VIEW`

***None***

### `VOTING_POWER`

***None***

TZT format doesn't have the necessary field(s) to set the return value of
`VOTING_POWER` instruction

## Missing tests summary

There are no tests for ill-typed code.

Instructions with no tests:

- `{}`
- `ADD: bls12_381_fr : bls12_381_fr`
- `ADD: bls12_381_g1 : bls12_381_g1`
- `ADD: bls12_381_g2 : bls12_381_g2`
- `AND: bytes:bytes`
- `BYTES: int`
- `BYTES: nat`
- `CHECK_SIGNATURE`
- `COMPARE: address : address`
- `COMPARE: chain_id : chain_id`
- `COMPARE: key : key`
- `COMPARE: option _ : option _`
- `COMPARE: or _ _ : or _ _`
- `COMPARE: signature : signature`
- `COMPARE: timestamp : timestamp`
- `COMPARE: unit : unit`
- `DUP n`
- `DUP`
- `EDIV: int : nat`
- `EDIV: nat : int`
- `EDIV: nat : nat`
- `EMIT`
- `GET n`
- `GET_AND_UPDATE: kty : option vty : big_map kty vty`
- `GET_AND_UPDATE: kty : option vty : map kty vty`
- `HASH_KEY`
- `INT: bls12_381_fr`
- `INT: bytes`
- `JOIN_TICKETS`
- `LAMBDA_REC`
- `LAMBDA`
- `LEVEL`
- `LSL: bytes : nat`
- `LSR: bytes : nat`
- `MAP: option ty`
- `MIN_BLOCK_TIME`
- `MUL: bls12_381_fr : bls12_381_fr`
- `MUL: bls12_381_fr : int`
- `MUL: bls12_381_fr : nat`
- `MUL: bls12_381_g1 : bls12_381_fr`
- `MUL: bls12_381_g2 : bls12_381_fr`
- `MUL: int : bls12_381_fr`
- `MUL: nat : bls12_381_fr`
- `NAT`
- `NEG: bls12_381_fr`
- `NEG: bls12_381_g1`
- `NEG: bls12_381_g2`
- `NOT: bytes`
- `OR bytes`
- `PAIR n`
- `PAIRING_CHECK`
- `READ_TICKET`
- `SAPLING_EMPTY_STATE ms`
- `SAPLING_VERIFY_UPDATE`
- `SELF_ADDRESS`
- `SPLIT_TICKET`
- `SUB_MUMAV`
- `SUB: int : nat`
- `SUB: nat : int`
- `SUB: nat : nat`
- `SWAP`
- `TICKET`
- `TOTAL_VOTING_POWER`
- `UPDATE n`
- `VIEW`
- `VOTING_POWER`
- `XOR: bytes:bytes`

Instructions with missing edge cases:

- `AND int:nat` 0 & x
- `AND int:nat` positive & x
- `AND int:nat` result `0` with non-zero arguments
- `AND int:nat` x & 0
- `AND nat:nat` 0 & x
- `AND nat:nat` result `0` with non-zero arguments
- `AND nat:nat` x & 0
- `COMPARE: int : int` with 0
- `COMPARE: int : int` with negative argument(s)
- `COMPARE: mumav : mumav` with 0
- `COMPARE: nat : nat` with 0
- `COMPARE: string : string` with strings longer than 1 character
- `CONTRACT` with entrypoints
- `DIG n` for even n (e.g. n = 2)
- `DIP n` for n = 0
- `DIP n` for n = 1
- `DROP n` for n = 1
- `DUG n` for n = 0
- `DUG n` for n = 1
- `EDIV: int : int` negative / negative
- `EDIV: int : int` positive / positive
- `EDIV: int : int` with result 1
- `EDIV: int : int` zero / non-zero
- `EDIV: int : int` zero / zero
- `EDIV: mumav : mumav` zero / non-zero
- `EDIV: mumav : mumav` zero / zero
- `IF_CONS` -- check that stack tail is preserved
- `IF_LEFT` -- check that stack tail is preserved
- `IF_NONE` -- check that stack tail is preserved
- `IF` -- check that stack tail is preserved
- `ISNAT` for positive argument
- `LSL: nat : nat` zero shift for non-zero argument
- `LSR: nat : nat` zero shift for non-zero argument
- `MUL: int : int` 0 * x
- `MUL: int : int` negative * negative
- `MUL: int : int` negative * positive
- `MUL: int : int` positive * positive
- `MUL: int : int` x * 0
- `MUL: int : nat` 0 * x
- `MUL: int : nat` negative * x
- `MUL: int : nat` x * 0
- `MUL: mumav : nat` 0 * x
- `MUL: mumav : nat` x * 0
- `MUL: nat : int` 0 * x
- `MUL: nat : int` x * 0
- `MUL: nat : int` x * positive
- `MUL: nat : mumav` 0 * x
- `MUL: nat : mumav` x * 0
- `MUL: nat : nat` 0 * x
- `MUL: nat : nat` x * 0
- `PACK` standalone tests (without `UNPACK`)
- `PUSH` for more pushable types
- `SENDER` when sender != source
- `SET_DELEGATE` with `None`
- `SUB: int : int` 0 - x
- `SUB: int : int` x - 0
- `SUB: int : int` x - negative
- `SUB: timestamp : int` 0 - x
- `SUB: timestamp : int` x - 0
- `SUB: timestamp : timestamp` realistic timestamps with negative difference
- `UNPACK` standalone tests (without `PACK`)
