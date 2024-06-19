let _ =
  let x = Some 1 in
  Mavryk_time_measurement_runtime.Default.Time_measurement.duration
    ("pattern_matching", [])
    (fun () -> match x with | Some a -> a | None -> 2)
