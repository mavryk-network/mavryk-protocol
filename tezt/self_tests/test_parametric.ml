let register () =
  let open Parametric in
  let p1 = strings ["foo"; "bar"] in
  let p2 = ints [1; 2] in
  let () =
    parameterize p1
    @@ register ~__FILE__ ~title:"Example parametric test" ~tags:["my"; "tags"]
    @@ fun string_value ->
    Log.info "My parameter is: %s" string_value ;
    unit
  in
  let () =
    parameterize (tuple2 p1 p2)
    @@ register ~__FILE__ ~title:"Example parametric test" ~tags:["my"; "tags"]
    @@ fun (string_value, int_value) ->
    Log.info "My parameters are: %s and %d" string_value int_value ;
    unit
  in
  let () =
    parameterize (tuple2 p1 p2)
    @@ register_internal
         ~__FILE__
         ~title:"Example parametric test internal"
         ~tags:["my"; "tags"]
    @@ fun (string_value, int_value) ->
    Log.info "My parameters are: %s and %d" string_value int_value ;
    unit
  in
  ()
