open Base

type 'a param = {
  to_string : 'a -> string;
  name : string option;
  values : 'a list;
  tags : 'a -> string list;
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
  }

let tuple2 p q = pair p q

let tuple3 p q r = pair p (tuple2 q r)

let tuple4 p q r w = pair p (tuple3 q r w)

let list ?name ~to_string values =
  {name; to_string; tags = (fun v -> [to_string v]); values}

let strings ?name values = list ?name ~to_string:Fun.id values

let ints ?name values = list ?name ~to_string:string_of_int values

let register :
    __FILE__:string ->
    title:string ->
    tags:string list ->
    ('a -> unit Lwt.t) ->
    'a param ->
    unit =
 fun ~__FILE__ ~title ~tags f param ->
  match param.values with
  | [] ->
      failwith
        (sf
           "test %s in %s was registered with an empty parameterization"
           title
           __FILE__)
  | values ->
      (Fun.flip List.iter) values @@ fun value ->
      let tags = tags @ param.tags value in
      let title = title ^ " [" ^ param.to_string value ^ "]" in
      Test.register ~__FILE__ ~title ~tags (fun () -> f value)

let parameterize (param : 'a param) f = f param

let register_internal :
    __FILE__:string ->
    title:string ->
    tags:string list ->
    ('a -> unit Lwt.t) ->
    'a param ->
    unit =
 fun ~__FILE__ ~title ~tags f param ->
  Test.register ~__FILE__ ~title ~tags (fun () ->
      (Fun.flip Lwt_list.iter_s) param.values @@ fun value ->
      Log.info
        "Running test %s with parameters [%s]"
        title
        (param.to_string value) ;
      f value)
