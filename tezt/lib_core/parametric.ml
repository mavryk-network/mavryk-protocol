open Base

type 'a param = {
  to_string : 'a -> string;
  name : string option;
  values : 'a list;
  tags : 'a -> string list;
  title_tag : 'a -> string option;
  title_prefix : 'a -> string option;
}

let pair p1 p2 =
  {
    to_string = (fun (v1, v2) -> sf "%s,%s" (p1.to_string v1) (p2.to_string v2));
    name = None;
    values =
      (* todo: error if p1. or p2. values is empty *)
      List.concat_map
        (fun v1 -> List.map (fun v2 -> (v1, v2)) p2.values)
        p1.values;
    tags = (fun (v1, v2) -> p1.tags v1 @ p2.tags v2);
    title_tag =
      (fun (v1, v2) ->
        match (p1.title_tag v1, p2.title_tag v2) with
        | Some t1, Some t2 -> Some (sf "%s,%s" t1 t2)
        | None, Some t | Some t, None -> Some t
        | None, None -> None);
    title_prefix =
      (fun (v1, v2) ->
        match (p1.title_prefix v1, p2.title_prefix v2) with
        | Some t1, Some t2 -> Some (sf "%s,%s" t1 t2)
        | None, Some t | Some t, None -> Some t
        | None, None -> None);
  }

let unit =
  {
    to_string = (fun () -> "()");
    name = None;
    values = [()];
    tags = (fun () -> []);
    title_tag = Fun.const None;
    title_prefix = Fun.const None;
  }

let tuple2 p q = pair p q

let tuple3 p q r = pair p (tuple2 q r)

let tuple4 p q r w = pair p (tuple3 q r w)

let list ?name ~to_string ?(tags = fun v -> [to_string v])
    ?(title_tag = fun v -> Some (to_string v)) ?(title_prefix = fun _ -> None)
    values =
  {name; to_string; title_tag; title_prefix; values; tags}

let strings ?name values = list ?name ~to_string:Fun.id values

let ints ?name values = list ?name ~to_string:string_of_int values

let parameterize (param : 'a param) f = f param

module Lazy = struct
  let list ?name values =
    let to_string (value_tag, _thunk) = value_tag in
    {
      name;
      to_string;
      values;
      tags = (fun v -> [to_string v]);
      title_tag = (fun v -> Some (to_string v));
      title_prefix = Fun.const None;
    }
end

(* This does not compose well with regression tests, as there is no
   mapping between the test's title and the values that are generated.

   If we put values instead of indexes in the titles, we get this
   mapping, but we have to make sure that titles are unique (no
   repeated generated values). Furthermore, it might be tricky to
   ensure that the state of the random generator is "stable". This
   means that the set of tests (the set of title tests), will
   fluctuate, which I do not think is a good idea.
*)

module Arbitrary = struct
  let n = 3

  let arb ?name ~to_string gen =
    let st = Random.State.make [||] in
    let values = List.init n (fun idx -> (idx, gen st)) in
    let to_string (_idx, value) = to_string value in
    {
      name;
      to_string;
      values;
      (* I don't think tags make sense here *)
      tags = (fun _ -> ["arbitrary"]);
      title_tag = (fun (idx, _v) -> Some (sf "#%d" idx));
      title_prefix = Fun.const None;
    }

  let int = arb ~to_string:string_of_int (fun st -> Random.State.int st 10)

  let float =
    arb ~to_string:string_of_float (fun st -> Random.State.float st 10.0)

  (* With this setup, a pair becomes the cross-product of the values
     of the underlying params. This might be unexpected, it is not how
     e.g. QCheck does it.  There, the componetns of the pair is
     individually generated. To resolve this, I think
     we'd have to stratify [arb] into [gen] and [arb] like QCheck does.

     However, at that point, why not use the QCheck generators?
  *)
  let pair (p1 : (int * 'a) param) (p2 : (int * 'b) param) =
    let values =
      List.concat_map
        (fun (_idx1, v1) -> List.map (fun (_idx2, v2) -> (v1, v2)) p2.values)
        p1.values
    in
    let values = List.mapi (fun i v -> (i, v)) values in
    {
      name = None;
      to_string =
        (fun (_idx, (v1, v2)) ->
          (* the zeroes here are unfortunate but required to get the underlying to_string *)
          sf "%s,%s" (p1.to_string (0, v1)) (p2.to_string (0, v2)));
      values;
      (* I don't think tags make sense here *)
      tags = (fun _ -> ["arbitrary"]);
      title_tag = (fun (idx, _v) -> Some (sf "#%d" idx));
      title_prefix = Fun.const None;
    }

  let of_qcheck ?name (qcheck_arb : 'a QCheck.arbitrary) =
    let gen = QCheck.get_gen qcheck_arb in
    let to_string =
      match QCheck.get_print qcheck_arb with
      (* A wart *)
      | None -> fun _ -> ""
      | Some to_string -> to_string
    in
    arb ?name ~to_string gen
end
