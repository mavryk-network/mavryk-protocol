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
  (* Test with lazy parameters *)
  let () =
    (* Temporary files cannot be created outside of tests. If you want
       to paramtrize your test by such a value, it can be created in a
       lazy parameter *)
    Parametric.(
      parameterize
        (Lazy.list
           ~name:"temp-file"
           [
             ("temp_file1", fun () -> Temp.file "foo");
             ("temp_file2", fun () -> Temp.file "bar");
           ]))
    @@ Test.register_parametric
         ~__FILE__
         ~title:"Example non-parametric test"
         ~tags:["my"; "tags"]
         (* The test does not really need [_temp_value_name], it's another wart *)
         (fun (_temp_value_name, temp_file) ->
           (* It is unfortunate by the thunk has to force inside the test function.
              It could be circumvented by creating [Test.register_lazy_parametric]
              but would create another set of register functions :( *)
           let temp_file = temp_file () in
           Log.info "My parametric test using the lazy temp-file %S" temp_file ;
           unit)
  in
  (* Test with arbitrary parameters *)
  let () =
    Parametric.(parameterize Arbitrary.int)
    @@ Test.register_parametric
         ~__FILE__
         ~title:"Example test with arbitrary values"
         ~tags:["my"; "tags"]
         (* Again the [_idx] tag here is a wart that could be solved in the same manner as above ... *)
         (fun (_idx, arb_int_value) ->
           Log.info "My arbitrary test, value %d" arb_int_value ;
           unit)
  in
  let () =
    Parametric.(parameterize (Arbitrary.of_qcheck QCheck.int))
    @@ Test.register_parametric
         ~__FILE__
         ~title:"Example test with arbitrary values from a QCheck generator"
         ~tags:["my"; "tags"]
         (* Again the [_idx] tag here is a wart that could be solved in the same manner as above ... *)
         (fun (_idx, arb_int_value) ->
           Log.info "My arbitrary test, value %d" arb_int_value ;
           unit)
  in
  let () =
    Parametric.(parameterize Arbitrary.(pair int float))
    @@ Test.register_parametric
         ~__FILE__
         ~title:"Example test with pairs of arbitrary values"
         ~tags:["my"; "tags"]
         (* Again the [_idx] tag here is a wart that could be solved in the same manner as above ... *)
         (fun (_idx, (arb_int_value, arb_float_value)) ->
           Log.info
             "My arbitrary test, value %d and %f"
             arb_int_value
             arb_float_value ;
           unit)
  in

  ()
