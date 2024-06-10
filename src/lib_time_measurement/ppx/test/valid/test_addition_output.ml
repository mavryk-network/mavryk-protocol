let _ =
  Mavryk_time_measurement_runtime.Default.Time_measurement.duration
    ("addition", []) (fun () -> 1 + 3)
