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
