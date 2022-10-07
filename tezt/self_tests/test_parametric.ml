let register () =
  let p1 = Parametric.strings ["foo"; "bar"] in
  let p2 = Parametric.ints [1; 2] in
  (* Some parametric tests *)
  let () =
    Parametric.parameterize p1
    @@ Test.register_parametric
         ~__FILE__
         ~title:"Example parametric test"
         ~tags:["my"; "tags"]
    @@ fun string_value ->
    Log.info "My parameter is: %s" string_value ;
    unit
  in
  let () =
    Parametric.(parameterize (tuple2 p1 p2))
    @@ Test.register_parametric
         ~__FILE__
         ~title:"Example parametric test"
         ~tags:["my"; "tags"]
    @@ fun (string_value, int_value) ->
    Log.info "My parameters are: %s and %d" string_value int_value ;
    unit
  in
  let () =
    Parametric.(parameterize (tuple2 p1 p2))
    @@ Test.register_parametric_internal
         ~__FILE__
         ~title:"Example parametric test internal"
         ~tags:["my"; "tags"]
    @@ fun (string_value, int_value) ->
    Log.info "My parameters are: %s and %d" string_value int_value ;
    unit
  in
  (* A normal tests (parametric under the hood) *)
  let () =
    Test.register
      ~__FILE__
      ~title:"Example non-parametric test"
      ~tags:["my"; "tags"]
    @@ fun () ->
    Log.info "My non-parametric test" ;
    unit
  in
  ()
