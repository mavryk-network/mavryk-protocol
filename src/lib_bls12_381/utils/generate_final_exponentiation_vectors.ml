let () =
  let p = Mavryk_bls12_381.Fq12.random () in
  let res = Mavryk_bls12_381.Pairing.final_exponentiation_exn p in
  Printf.printf
    "p = %s\nResult: %s\n"
    (Hex.show (Hex.of_bytes (Mavryk_bls12_381.Fq12.to_bytes p)))
    (Hex.show (Hex.of_bytes (Mavryk_bls12_381.GT.to_bytes res)))
