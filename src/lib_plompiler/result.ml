(*****************************************************************************)
(*                                                                           *)
(* MIT License                                                               *)
(* Copyright (c) 2022 Nomadic Labs <contact@nomadic-labs.com>                *)
(*                                                                           *)
(* Permission is hereby granted, free of charge, to any person obtaining a   *)
(* copy of this software and associated documentation files (the "Software"),*)
(* to deal in the Software without restriction, including without limitation *)
(* the rights to use, copy, modify, merge, publish, distribute, sublicense,  *)
(* and/or sell copies of the Software, and to permit persons to whom the     *)
(* Software is furnished to do so, subject to the following conditions:      *)
(*                                                                           *)
(* The above copyright notice and this permission notice shall be included   *)
(* in all copies or substantial portions of the Software.                    *)
(*                                                                           *)
(* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR*)
(* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  *)
(* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL   *)
(* THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER*)
(* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING   *)
(* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER       *)
(* DEALINGS IN THE SOFTWARE.                                                 *)
(*                                                                           *)
(*****************************************************************************)

(** "Pure value" backend for Plompiler.
    It actually implements a simple state monad to keep track
    of implicit checks.
*)

include Lang_core

type scalar = X of S.t

type input_kind = [`InputCom | `Public | `Private]

type trace_kind = [input_kind | `NoInput]

type 'a repr =
  | U : unit repr
  | S : scalar -> scalar repr
  | B : bool -> bool repr
  | P : 'a repr * 'b repr -> ('a * 'b) repr
  | L : 'a repr list -> 'a list repr

type state = bool repr list

type 'a t = state -> state * 'a

let ret x s = (s, x)

let ( let* ) m f s =
  let s, o = m s in
  f o s

let ( >* ) m f =
  let* U = m in
  f

let ( <$> ) m f =
  let* m in
  ret (f m)

let rec mapM f ls =
  match ls with
  | [] -> ret @@ []
  | l :: ls ->
      let* o = f l in
      let* rest = mapM f ls in
      ret @@ (o :: rest)

let with_bool_check : bool repr t -> unit repr t =
 fun check s ->
  let s, b = check s in
  (b :: s, U)

module Input = struct
  type 'a implicit_check = 'a repr -> unit repr t

  type 'a t' = 'a repr

  type 'a input = 'a t' * 'a implicit_check

  type 'a t = 'a input

  let default_check _ = ret U

  let s x : scalar t' = S (X x)

  let scalar x = (s x, default_check)

  let to_scalar (S (X x), _) = x

  let bool b = (B b, default_check)

  let to_bool (B b, _) = b

  let unit = (U, default_check)

  let pair : 'a t -> 'b t -> ('a * 'b) t =
   fun (a, check_a) (b, check_b) ->
    (P (a, b), fun (P (ar, br)) -> check_a ar >* check_b br)

  let to_pair (P (a, b), _) = ((a, default_check), (b, default_check))

  let list : 'a t list -> 'a list t =
   fun l ->
    ( L (List.map fst l),
      fun (L lr) ->
        let* _l =
          mapM (fun ((_, asssertion), r) -> asssertion r) (List.combine l lr)
        in
        ret U )

  let to_list (L l, _) = List.map (fun i -> (i, default_check)) l

  let with_implicit_bool_check bc (i, a) =
    (i, fun repr -> a repr >* with_bool_check (bc repr))

  let with_assertion na (i, a) = (i, fun repr -> a repr >* na repr)
end

let rec encode : type a. a Input.t' -> S.t list =
 fun input ->
  match input with
  | U -> []
  | S (X s) -> [s]
  | B b -> if b then [S.one] else [S.zero]
  | P (l, r) -> encode l @ encode r
  | L l -> List.concat_map encode l

let serialize i = Array.of_list @@ encode (fst i)

(* Note: this doesn't match [Circuit]'s concept of physical equality,
   as we don't have wires here. *)
let rec eq : type a. a repr -> a repr -> bool =
 fun a b ->
  match (a, b) with
  | S (X a), S (X b) -> S.eq a b
  | B a, B b -> a = b
  | P (al, ar), P (bl, br) -> eq al bl && eq ar br
  | L l1, L l2 -> List.for_all2 eq l1 l2
  | U, U -> true

let input : type a. ?kind:input_kind -> a Input.t -> a repr t =
 fun ?(kind = `Private) (input, check) ->
  ignore kind ;
  check input >* ret input

let new_input_com : unit repr t = fun s -> (s, U)

type 'b open_input_com = 'b t

let begin_input_com : 'b -> 'b open_input_com = fun b -> new_input_com >* ret b

let ( |: ) :
    type c d. (c repr -> d) open_input_com -> c Input.t -> d open_input_com =
 fun v i s ->
  let s, f = v s in
  let s, r = (input ~kind:`InputCom i) s in
  (s, f r)

let end_input_com : 'a open_input_com -> 'a t = Fun.id

let to_list l = L l

let of_list (L l) = l

let of_pair (P (l, r)) = (l, r)

let pair l r = P (l, r)

let unit = U

let to_s s = S (X s)

let of_s (S (X s)) = s

let map2 f x y = X (f x y)

let rec foldM f e l =
  match l with
  | [] -> ret e
  | x :: xs ->
      let* y = f e x in
      foldM f y xs

let scalar_of_bool (B b) = if b then S (X S.one) else S (X S.zero)

let unsafe_bool_of_scalar (S (X s)) = if S.(eq s one) then B true else B false

module Num = struct
  type nonrec scalar = scalar

  type nonrec 'a repr = 'a repr

  type nonrec 'a t = 'a t

  let range_check ~nb_bits (S (X x)) s =
    assert (Z.compare (S.to_z x) Z.(one lsl nb_bits) < 0) ;
    (s, U)

  let assert_nonzero sx =
    let x = of_s sx in
    assert (not S.(x = zero)) ;
    ret U

  let is_zero (S (X x)) = ret @@ B S.(x = zero)

  let is_not_zero (S (X x)) = ret @@ B (not S.(x = zero))

  let custom ?(qc = S.zero) ?(ql = S.zero) ?(qr = S.zero) ?(qo = S.mone)
      ?(qm = S.zero) ?(qx2b = S.zero) ?(qx5a = S.zero) sl sr =
    let l, r = (of_s sl, of_s sr) in
    let o =
      S.(
        ((ql * l) + (qr * r)
        + (qm * l * r)
        + qc
        + (qx2b * r * r)
        + (qx5a * l * l * l * l * l))
        / negate qo)
    in
    ret @@ S (X o)

  let assert_custom ?(qc = S.zero) ?(ql = S.zero) ?(qr = S.zero) ?(qo = S.zero)
      ?(qm = S.zero) sl sr so =
    let l, r, o = (of_s sl, of_s sr, of_s so) in
    let o = S.((ql * l) + (qr * r) + (qo * o) + (qm * l * r) + qc) in
    assert (S.(o = zero)) ;
    ret U

  let assert_bool (S (X l)) =
    assert (S.(l = zero || l = one)) ;
    ret U

  let add ?(qc = S.zero) ?(ql = S.one) ?(qr = S.one) sl sr =
    let l, r = (of_s sl, of_s sr) in
    let o = S.((ql * l) + (qr * r) + qc) in
    ret @@ S (X o)

  let sub sl sr =
    let l, r = (of_s sl, of_s sr) in
    ret @@ S (map2 S.sub l r)

  let mul ?(qm = S.one) sl sr =
    let l, r = (of_s sl, of_s sr) in
    let lr = S.mul l r in
    ret @@ S (map2 S.mul qm lr)

  let add_constant ?(ql = S.one) k sl =
    let l = of_s sl in
    let o = S.(k + (ql * l)) in
    ret @@ S (X o)

  let div ?(den_coeff = S.one) sl sr =
    let l, r = (of_s sl, of_s sr) in
    assert (not S.(is_zero r)) ;
    assert (not S.(is_zero den_coeff)) ;
    let qmr = S.mul den_coeff r in
    ret @@ S (map2 S.div_exn l qmr)

  let pow5 sl =
    let l = of_s sl in
    ret @@ S (X S.(pow l (Z.of_int 5)))

  let constant : S.t -> scalar repr t = fun s -> ret (S (X s))

  let zero = constant S.zero

  let one = constant S.one
end

module Bool = struct
  type nonrec scalar = scalar

  type nonrec 'a repr = 'a repr

  type nonrec 'a t = 'a t

  let s_of_b b = if b then X S.one else X S.zero

  let assert_true (B b) =
    assert b ;
    ret U

  let assert_false (B b) =
    assert (not b) ;
    ret U

  let constant : bool -> bool repr t = fun b -> ret (B b)

  let band (B l) (B r) = ret @@ B (l && r)

  let xor (B l) (B r) =
    let o =
      match (l, r) with
      | true, true -> false
      | false, true -> true
      | true, false -> true
      | false, false -> false
    in
    ret @@ B o

  let bor (B l) (B r) = ret @@ B (l || r)

  let bnot (B b) = ret @@ B (not b)

  let ifthenelse (B b) l r = if b then ret l else ret r

  let swap (B b) l r = if b then ret @@ pair r l else ret @@ pair l r

  let band_list l : bool repr t =
    ret @@ List.fold_left (fun (B a) (B b) -> B (a && b)) (B true) l

  module Internal = struct
    let bor_lookup (B l) (B r) = bor (B l) (B r)

    let xor_lookup (B l) (B r) = xor (B l) (B r)

    let band_lookup (B l) (B r) = band (B l) (B r)

    let bnot_lookup (B b) = bnot (B b)
  end
end

module Limb (N : sig
  val nb_bits : int
end) =
struct
  let nb_bits =
    (* As we use the Int functions (logxor, logand, etc.) to compute
       the lookup table, the nb_bits is limited to int_size / 2. *)
    assert (N.nb_bits <= 8) ;
    N.nb_bits

  let xor_lookup (S (X l)) (S (X r)) =
    ret @@ to_s @@ S.of_int
    @@ Int.logxor (Z.to_int (S.to_z l)) (Z.to_int (S.to_z r))

  let band_lookup (S (X l)) (S (X r)) =
    ret @@ to_s @@ S.of_int
    @@ Int.logand (Z.to_int (S.to_z l)) (Z.to_int (S.to_z r))

  let bnot_lookup (S (X l)) =
    let mask = (1 lsl nb_bits) - 1 in
    ret @@ to_s @@ S.of_int @@ Int.(logand (lognot (Z.to_int (S.to_z l))) mask)

  let rotate_right_lookup (S (X l)) (S (X r)) i =
    assert (i < nb_bits) ;
    ret @@ to_s
    @@ S.of_int
         (Csir.rotate_right
            ~nb_bits
            (Z.to_int (S.to_z l))
            (Z.to_int (S.to_z r))
            i)
end

let point x y = P (S (X x), S (X y))

let of_point (P (S (X x), S (X y))) = (x, y)

module Ecc = struct
  let weierstrass_add p1 p2 =
    let module W = Mec.Curve.Jubjub.AffineWeierstrass in
    let x1, y1 = of_point p1 in
    let x2, y2 = of_point p2 in
    let s_to_base s = W.Base.of_z (S.to_z s) in
    let s_of_base s = S.of_z (W.Base.to_z s) in
    let p1 = W.from_coordinates_exn ~x:(s_to_base x1) ~y:(s_to_base y1) in
    let p2 = W.from_coordinates_exn ~x:(s_to_base x2) ~y:(s_to_base y2) in
    let p3 = W.add p1 p2 in
    ret
    @@ point
         (s_of_base @@ W.get_x_coordinate p3)
         (s_of_base @@ W.get_y_coordinate p3)

  let edwards_add p1 p2 =
    let module W = Mec.Curve.Jubjub.AffineEdwards in
    let x1, y1 = of_point p1 in
    let x2, y2 = of_point p2 in
    let s_to_base s = W.Base.of_z (S.to_z s) in
    let s_of_base s = S.of_z (W.Base.to_z s) in
    let p1 = W.from_coordinates_exn ~u:(s_to_base x1) ~v:(s_to_base y1) in
    let p2 = W.from_coordinates_exn ~u:(s_to_base x2) ~v:(s_to_base y2) in
    let p3 = W.add p1 p2 in
    ret
    @@ point
         (s_of_base @@ W.get_u_coordinate p3)
         (s_of_base @@ W.get_v_coordinate p3)

  let edwards_cond_add p1 p2 (B b) =
    let module W = Mec.Curve.Jubjub.AffineEdwards in
    let x1, y1 = of_point p1 in
    let x2, y2 = of_point p2 in
    let s_to_base s = W.Base.of_z (S.to_z s) in
    let s_of_base s = S.of_z (W.Base.to_z s) in
    let p1 = W.from_coordinates_exn ~u:(s_to_base x1) ~v:(s_to_base y1) in
    let p2 = W.from_coordinates_exn ~u:(s_to_base x2) ~v:(s_to_base y2) in
    let p3 = W.add p1 p2 in
    let out = if b then p3 else p1 in
    ret
    @@ point
         (s_of_base @@ W.get_u_coordinate out)
         (s_of_base @@ W.get_v_coordinate out)
end

module Mod_arith = struct
  let add ?(subtraction = false) ~label:_ ~modulus ~nb_limbs:_ ~base ~moduli:_
      ~qm_bound:_ ~ts_bounds:_ x y =
    let xs = List.map (fun s -> of_s s |> S.to_z) (of_list x) in
    let ys = List.map (fun s -> of_s s |> S.to_z) (of_list y) in
    let zs =
      if subtraction then Utils.mod_sub_limbs ~modulus ~base xs ys
      else Utils.mod_add_limbs ~modulus ~base xs ys
    in
    let z = List.map (fun z -> S.of_z z |> to_s) zs |> to_list in
    ret z

  let mul ?(division = false) ~label:_ ~modulus ~nb_limbs:_ ~base ~moduli:_
      ~qm_bound:_ ~ts_bounds:_ x y =
    let xs = List.map (fun s -> of_s s |> S.to_z) (of_list x) in
    let ys = List.map (fun s -> of_s s |> S.to_z) (of_list y) in
    let zs =
      if division then Utils.mod_div_limbs ~modulus ~base xs ys
      else Utils.mod_mul_limbs ~modulus ~base xs ys
    in
    let z = List.map (fun z -> S.of_z z |> to_s) zs |> to_list in
    ret z

  let assert_non_zero ~label:_ ~modulus ~is_prime:_ ~nb_limbs:_ ~base ~moduli:_
      ~qm_bound:_ ~ts_bounds:_ x =
    let xs = List.map (fun s -> of_s s |> S.to_z) (of_list x) in
    let x = Utils.z_of_limbs ~base xs in
    assert (not Z.(rem x modulus = zero)) ;
    ret unit

  let is_zero ~label:_ ~modulus ~is_prime:_ ~nb_limbs:_ ~base ~moduli:_
      ~qm_bound:_ ~ts_bounds:_ x =
    let xs = List.map (fun s -> of_s s |> S.to_z) (of_list x) in
    let x = Utils.z_of_limbs ~base xs in
    ret @@ B Z.(rem x modulus = zero)
end

module Poseidon = struct
  module VS = Linear_algebra.Make_VectorSpace (S)

  let poseidon128_full_round ~matrix ~k (x0, x1, x2) =
    let pow5 x = S.pow (of_s x) (Z.of_int 5) in
    let x_vec = [|Array.map pow5 [|x0; x1; x2|]|] |> VS.transpose in
    let y_vec = VS.mul matrix x_vec in
    let y0 = S.add k.(0) @@ y_vec.(0).(0) in
    let y1 = S.add k.(1) @@ y_vec.(1).(0) in
    let y2 = S.add k.(2) @@ y_vec.(2).(0) in
    ret @@ to_list [S (X y0); S (X y1); S (X y2)]

  let poseidon128_four_partial_rounds ~matrix ~ks (x0, x1, x2) =
    let k0 = VS.filter_cols (Int.equal 0) ks in
    let k1 = VS.filter_cols (Int.equal 1) ks in
    let k2 = VS.filter_cols (Int.equal 2) ks in
    let k3 = VS.filter_cols (Int.equal 3) ks in
    let ppow5 v = [|v.(0); v.(1); [|S.pow v.(2).(0) (Z.of_int 5)|]|] in
    let x_vec = [|[|of_s x0; of_s x1; of_s x2|]|] |> VS.transpose in
    let a_vec = VS.(add (mul matrix @@ ppow5 x_vec) k0) in
    let b_vec = VS.(add (mul matrix @@ ppow5 a_vec) k1) in
    let c_vec = VS.(add (mul matrix @@ ppow5 b_vec) k2) in
    let y_vec = VS.(add (mul matrix @@ ppow5 c_vec) k3) in
    ret
    @@ to_list [S (X y_vec.(0).(0)); S (X y_vec.(1).(0)); S (X y_vec.(2).(0))]
end

module Anemoi = struct
  module AnemoiPerm = Bls12_381_hash.Permutation.Anemoi

  let beta =
    S.of_string (Mavryk_bls12_381.Fr.to_string AnemoiPerm.Parameters.beta)

  let gamma =
    S.of_string (Mavryk_bls12_381.Fr.to_string AnemoiPerm.Parameters.gamma)

  let g = S.of_string (Mavryk_bls12_381.Fr.to_string AnemoiPerm.Parameters.g)

  let delta =
    S.of_string (Mavryk_bls12_381.Fr.to_string AnemoiPerm.Parameters.delta)

  let alpha_inv =
    S.of_string (Mavryk_bls12_381.Fr.to_string AnemoiPerm.Parameters.alpha_inv)

  let anemoi_round ~kx ~ky (x0, y0) =
    let x0 = of_s x0 in
    let y0 = of_s y0 in
    let g2_p_1 = S.((g * g) + one) in
    let w_5 = S.(sub x0 ((beta * y0 * y0) + gamma)) in
    (* (1/5) *)
    let w = S.(pow w_5 (to_z alpha_inv)) in
    let v = S.sub y0 w in
    let u = S.(w_5 + ((beta * v * v) + delta)) in
    let x1 = S.(u + kx + (g * (v + ky))) in
    let y1 = S.((g * (u + kx)) + (g2_p_1 * (v + ky))) in
    ret @@ pair (S (X x1)) (S (X y1))

  let anemoi_double_round ~kx1 ~ky1 ~kx2 ~ky2 (x0, y0) =
    let* res1 = anemoi_round ~kx:kx1 ~ky:ky1 (x0, y0) in
    let x1, y1 = of_pair res1 in
    let* res2 = anemoi_round ~kx:kx2 ~ky:ky2 (x1, y1) in
    let x2, y2 = of_pair res2 in
    ret @@ pair x2 y2

  let anemoi_custom = anemoi_double_round
end

let hd (L l) = match l with [] -> assert false | x :: _ -> ret x

let assert_equal l r =
  assert (eq l r) ;
  ret U

let equal : type a. a repr -> a repr -> bool repr t =
 fun l r -> ret @@ B (eq l r)

let scalar_of_limbs ~nb_bits b =
  let sb = of_list b in
  let powers =
    let nb_limbs = List.length sb in
    let base = 1 lsl nb_bits |> Z.of_int in
    List.init nb_limbs (fun i -> S.of_z @@ Z.pow base i)
  in
  foldM
    (fun acc (qr, w) -> Num.add ~qr acc w)
    (List.hd sb)
    List.(tl @@ combine powers sb)

let bits_of_scalar ?(shift = Z.zero) ~nb_bits sx =
  let x = of_s sx |> S.to_z in
  let x = Z.add shift x in
  let sx = S (X (S.of_z x)) in
  let binary_decomposition = Utils.bool_list_of_z ~nb_bits x in
  let bits = L (List.map (fun x -> B x) binary_decomposition) in
  let* sum =
    let sbits = List.map scalar_of_bool (of_list bits) in
    scalar_of_limbs ~nb_bits:1 (to_list sbits)
  in
  with_bool_check (equal sx sum) >* ret bits

let limbs_of_scalar ?(shift = Z.zero) ~total_nb_bits ~nb_bits sx =
  let x = of_s sx |> S.to_z in
  let x = Z.add shift x in
  let binary_decomposition = Utils.bool_list_of_z ~nb_bits:total_nb_bits x in
  let nb_decomposition =
    Utils.limbs_of_bool_list ~nb_bits binary_decomposition
  in
  let limbs = L (List.map (fun x -> to_s @@ S.of_int x) nb_decomposition) in
  let sx = S (X (S.of_z x)) in
  let* sum = scalar_of_limbs ~nb_bits limbs in
  with_bool_check (equal sx sum) >* ret limbs

let of_b (B x) = x

let get_checks_wire : bool repr t =
 fun s -> ([], B (List.for_all (fun (B x) -> x) s))

let init_state = []

let with_label ~label t =
  ignore label ;
  t

let rec repr_to_string : type a. a repr -> string = function
  | U -> "()"
  | S (X s) -> S.string_of_scalar s
  | B b -> if b then "T" else "F"
  | P (a, b) -> "(" ^ repr_to_string a ^ "," ^ repr_to_string b ^ ")"
  | L (B _ :: _ as bs) ->
      (* special case to print bytes in hex *)
      let bs = List.map (fun (B b) -> if b then true else false) bs in
      let bs = Utils.of_bitlist ~le:false bs in
      Utils.hex_of_bytes bs
  | L l -> String.concat ";" (List.map repr_to_string l)

let debug s x =
  Format.printf "%s: %s\n%!" s (repr_to_string x) ;
  ret unit

let get_result : 'a repr t -> 'a Input.t =
 fun m ->
  let s, r = m init_state in
  let c = List.fold_left (fun a b -> a && b) true (List.map of_b s) in
  assert c ;
  (r, Input.default_check)
