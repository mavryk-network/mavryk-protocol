let register () =
  let string_param = Parametric.strings ["foo"; "bar"] in
  let int_param = Parametric.ints [1; 2] in
  (* Some parametric tests *)
  let () =
    Parametric.parameterize string_param
    @@ Test.register_parametric
         ~__FILE__
         ~title:"Example parametric test"
         ~tags:["my"; "tags"]
    @@ fun string_value ->
    Log.info "My parameter is: %s" string_value ;
    unit
  in
  let () =
    Parametric.(parameterize (tuple2 string_param int_param))
    @@ Test.register_parametric
         ~__FILE__
         ~title:"Example parametric test"
         ~tags:["my"; "tags"]
    @@ fun (string_value, int_value) ->
    Log.info "My parameters are: %s and %d" string_value int_value ;
    unit
  in
  let () =
    Parametric.(parameterize (tuple2 string_param int_param))
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
  (* Protocol tests *)
  let () =
    Protocol.register_test
      ~__FILE__
      ~title:"Example non-parametric test"
      ~tags:["my"; "tags"]
      (fun proto ->
        Log.info
          "My non-parametric test using protocol %s"
          (Protocol.name proto) ;
        unit)
      Protocol.all
  in
  (* Protocol test with parameters *)
  let () =
    Parametric.(parameterize (tuple2 string_param int_param))
    @@ Protocol.register_parametric
         ~__FILE__
         ~title:"Example non-parametric test"
         ~tags:["my"; "tags"]
         (fun (proto, (string_value, int_value)) ->
           Log.info
             "My non-parametric test using protocol %s, param %s and %d"
             (Protocol.name proto)
             string_value
             int_value ;
           unit)
         Protocol.all
  in
  ()
