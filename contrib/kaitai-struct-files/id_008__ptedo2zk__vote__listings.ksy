meta:
  id: id_008__ptedo2zk__vote__listings
  endian: be
doc: ! 'Encoding id: 008-PtEdo2Zk.vote.listings'
types:
  id_008__ptedo2zk__vote__listings_entries:
    seq:
    - id: pkh
      type: public_key_hash
      doc: A Ed25519, Secp256k1, or P256 public key hash
    - id: rolls
      type: s4
  public_key_hash:
    seq:
    - id: public_key_hash_tag
      type: u1
      enum: public_key_hash_tag
    - id: p256__public_key_hash
      size: 20
      if: (public_key_hash_tag == public_key_hash_tag::p256)
enums:
  public_key_hash_tag:
    0: ed25519
    1: secp256k1
    2: p256
seq:
- id: size_of_id_008__ptedo2zk__vote__listings
  type: u4
  valid:
    max: 1073741823
- id: id_008__ptedo2zk__vote__listings
  type: id_008__ptedo2zk__vote__listings_entries
  size: size_of_id_008__ptedo2zk__vote__listings
  repeat: eos
