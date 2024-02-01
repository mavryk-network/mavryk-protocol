meta:
  id: id_018__proxford__tez
  endian: be
doc: ! 'Encoding id: 018-Proxford.tez'
types:
  id_018__proxford__mumav:
    seq:
    - id: id_018__proxford__mumav
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
- id: id_018__proxford__mumav
  type: id_018__proxford__mumav
