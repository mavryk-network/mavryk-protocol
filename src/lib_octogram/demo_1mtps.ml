open Jingoo.Jg_types

type 'uri start_collector = {
  path_collector : 'uri;
  name : string option;
  port : string option;
  row : string;
  column : string;
  log_file : string;
}

type start_collector_r = {name : string; port : int}

type (_, _) Remote_procedure.t +=
  | Start_collector :
      'uri start_collector
      -> (start_collector_r, 'uri) Remote_procedure.t

module Start_collector = struct
  let name = "demo_1mtps.start_collector"

  type 'uri t = 'uri start_collector

  type r = start_collector_r

  let of_remote_procedure :
      type a. (a, 'uri) Remote_procedure.t -> 'uri t option = function
    | Start_collector args -> Some args
    | _ -> None

  let to_remote_procedure args = Start_collector args

  let unify : type a. (a, 'uri) Remote_procedure.t -> (a, r) Remote_procedure.eq
      = function
    | Start_collector _ -> Eq
    | _ -> Neq

  let encoding uri_encoding =
    Data_encoding.(
      conv
        (fun {path_collector; name; port; row; column; log_file} ->
          (path_collector, name, port, row, column, log_file))
        (fun (path_collector, name, port, row, column, log_file) ->
          {path_collector; name; port; row; column; log_file})
        (obj6
           (req "path_collector" uri_encoding)
           (opt "name" string)
           (opt "port" string)
           (req "row" string)
           (req "column" string)
           (req "log_file" string)))

  let r_encoding =
    Data_encoding.(
      conv
        (fun {name; port} -> (name, port))
        (fun (name, port) -> {name; port})
        (obj2 (req "name" string) (req "port" int31)))

  let tvalue_of_r {name; port} = Tobj [("name", Tstr name); ("port", Tint port)]

  let expand ~self ~run {path_collector; name; port; row; column; log_file} =
    let path_collector =
      Remote_procedure.global_uri_of_string ~self ~run path_collector
    in

    let port = Option.map run port in

    let name = Option.map run name in

    let row = run row in

    let column = run column in

    let log_file = run log_file in

    {path_collector; name; port; row; column; log_file}

  let resolve ~self resolver args =
    let path_collector =
      Remote_procedure.file_agent_uri ~self ~resolver args.path_collector
    in

    {args with path_collector}

  let run state args =
    let column = int_of_string args.column in

    let row = int_of_string args.row in

    let port = Option.map int_of_string args.port in

    let* path_collector =
      Http_client.local_path_from_agent_uri
        (Agent_state.http_client state)
        args.path_collector
    in

    let collector =
      Tx_demo_collector.create
        ~path:path_collector
        ?name:args.name
        ?port
        ~row
        ~column
        ~log_file:args.log_file
        ()
    in

    let* () = Tx_demo_collector.run collector in

    (* TODO: proper registering in the state of the agent *)
    return
      {
        name = Tx_demo_collector.name collector;
        port = Tx_demo_collector.port collector;
      }

  let on_completion ~on_new_service:_ ~on_new_metrics_source:_ _r = ()
end

let register_procedures () = Remote_procedure.register (module Start_collector)
