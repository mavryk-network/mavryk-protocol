module Parameters = struct
  type persistent_state = {
    mutable pending_ready : unit option Lwt.u list;
    port : int;
    column : int;
    row : int;
    log_file : string;
  }

  type session_state = {mutable ready : bool}

  let base_default_name = "tx-demo-collector"

  let default_colors = Log.Color.[|FG.green|]
end

open Parameters
include Daemon.Make (Parameters)

let wait collector =
  match collector.status with
  | Not_running ->
      Test.fail
        "%s is not running, cannot wait for it to terminate"
        (name collector)
  | Running {process; _} -> Process.wait process

let wait_for_promise ?timeout ?where collector name promise =
  let promise = Lwt.map Result.ok promise in

  let* result =
    match timeout with
    | None -> promise
    | Some timeout ->
        Lwt.pick
          [promise; (let* () = Lwt_unix.sleep timeout in

                     Lwt.return_error ())]
  in

  match result with
  | Ok (Some x) -> return x
  | Ok None ->
      raise
        (Terminated_before_event {daemon = collector.name; event = name; where})
  | Error () ->
      Format.ksprintf
        failwith
        "Timeout waiting for event %s of %s"
        name
        collector.name

let trigger_ready collector value =
  let pending = collector.persistent_state.pending_ready in

  collector.persistent_state.pending_ready <- [] ;

  List.iter (fun pending -> Lwt.wakeup_later pending value) pending

let set_ready collector =
  (match collector.status with
  | Not_running -> ()
  | Running status -> status.session_state.ready <- true) ;

  trigger_ready collector (Some ())

let wait_for_ready collector =
  match collector.status with
  | Running {session_state = {ready = true; _}; _} -> unit
  | Not_running | Running {session_state = {ready = false; _}; _} ->
      let promise, resolver = Lwt.task () in

      collector.persistent_state.pending_ready <-
        resolver :: collector.persistent_state.pending_ready ;

      wait_for_promise collector "Collector is ready" promise

let handle_raw_stdout collector line =
  if line =~ rex "Ready to receive new connection" then set_ready collector

let on_stdout collector handler =
  collector.stdout_handlers <- handler :: collector.stdout_handlers

let create ?name ?port ?path ?color ?event_pipe ~log_file ~column ~row () =
  let port = match port with Some port -> port | None -> Port.fresh () in

  let path = Option.value ~default:"./tx-demo-collector" path in

  let collector =
    create
      ~path
      ?name
      ?color
      ?event_pipe
      {pending_ready = []; column; row; log_file; port}
  in

  on_stdout collector (handle_raw_stdout collector) ;

  collector

let port collector = collector.persistent_state.port

let run ?event_level ?event_sections_levels collector =
  if collector.status <> Not_running then Test.fail "Collector is not running" ;

  let on_terminate _ =
    trigger_ready collector None ;

    unit
  in

  run
    ?event_level
    ?event_sections_levels
    collector
    {ready = false}
    ~on_terminate
    [
      "--log-path";
      collector.persistent_state.log_file;
      "--row";
      string_of_int collector.persistent_state.row;
      "--column";
      string_of_int collector.persistent_state.column;
      "--port";
      string_of_int collector.persistent_state.port;
    ]
