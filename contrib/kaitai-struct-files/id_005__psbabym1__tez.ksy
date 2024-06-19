meta:
  id: id_005__psbabym1__tez
  endian: be
doc: ! 'Encoding id: 005-PsBabyM1.tez'
types:
  id_005__psbabym1__mumav:
    seq:
    - id: id_005__psbabym1__mumav
      type: n
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
seq:
- id: id_005__psbabym1__mumav
  type: id_005__psbabym1__mumav
