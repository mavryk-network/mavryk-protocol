meta:
  id: id_002__ptboreas__mav
  endian: be
doc: ! 'Encoding id: 002-PtBoreas.tez'
types:
  id_002__ptboreas__mumav:
    seq:
    - id: id_002__ptboreas__mumav
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
- id: id_002__ptboreas__mumav
  type: id_002__ptboreas__mumav
