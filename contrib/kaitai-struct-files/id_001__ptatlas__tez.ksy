meta:
  id: id_001__ptatlas__tez
  endian: be
doc: ! 'Encoding id: 001-PtAtLas.tez'
types:
  id_001__ptatlas__mumav:
    seq:
    - id: id_001__ptatlas__mumav
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
- id: id_001__ptatlas__mumav
  type: id_001__ptatlas__mumav
