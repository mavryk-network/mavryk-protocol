open Error_monad

val read_dir :
  string ->
  (Mavryk_crypto.Hashed.Protocol_hash.t option * Protocol.t) tzresult Lwt.t

val write_dir :
  string ->
  ?hash:Mavryk_crypto.Hashed.Protocol_hash.t ->
  Protocol.t ->
  unit tzresult Lwt.t
