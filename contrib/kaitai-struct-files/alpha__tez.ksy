meta:
  id: alpha__tez
  endian: be
doc: ! 'Encoding id: alpha.tez'
types:
  alpha__mumav:
    seq:
    - id: alpha__mumav
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
- id: alpha__mumav
  type: alpha__mumav
