meta:
  id: id_011__pthangz2__delegate__frozen_balance_by_cycles
  endian: be
doc: ! 'Encoding id: 011-PtHangz2.delegate.frozen_balance_by_cycles'
types:
  id_011__pthangz2__delegate__frozen_balance_by_cycles:
    seq:
    - id: id_011__pthangz2__delegate__frozen_balance_by_cycles_entries
      type: id_011__pthangz2__delegate__frozen_balance_by_cycles_entries
      repeat: eos
  id_011__pthangz2__delegate__frozen_balance_by_cycles_entries:
    seq:
    - id: cycle
      type: s4
    - id: deposits
      type: id_011__pthangz2__mumav
    - id: fees
      type: id_011__pthangz2__mumav
    - id: rewards
      type: id_011__pthangz2__mumav
  id_011__pthangz2__mumav:
    seq:
    - id: id_011__pthangz2__mumav
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
- id: len_id_011__pthangz2__delegate__frozen_balance_by_cycles
  type: u4
  valid:
    max: 1073741823
- id: id_011__pthangz2__delegate__frozen_balance_by_cycles
  type: id_011__pthangz2__delegate__frozen_balance_by_cycles
  size: len_id_011__pthangz2__delegate__frozen_balance_by_cycles
