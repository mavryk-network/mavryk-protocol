let () = Random.self_init ()

let () =
  let a = Mavryk_bls12_381.Fr.zero in
  let b = Mavryk_bls12_381.Fr.one in
  let c = Mavryk_bls12_381.Fr.random () in
  let res = Mavryk_bls12_381.Fr.add a b in
  Printf.printf "Reachable words = %d\n" (Obj.reachable_words (Obj.repr a)) ;
  Printf.printf "Reachable words = %d\n" (Obj.reachable_words (Obj.repr c)) ;
  Printf.printf
    "a = %s\n"
    Hex.(show (of_bytes (Mavryk_bls12_381.Fr.to_bytes a))) ;
  Printf.printf
    "b = %s\n"
    Hex.(show (of_bytes (Mavryk_bls12_381.Fr.to_bytes b))) ;
  Printf.printf
    "a + b = %s\n"
    Hex.(show (of_bytes (Mavryk_bls12_381.Fr.to_bytes res)))
