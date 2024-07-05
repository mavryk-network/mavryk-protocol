val init :
  Raw_context.t ->
  typecheck:
    (Raw_context.t ->
    Script_repr.t ->
    ((Script_repr.t * Lazy_storage_diff.diffs option) * Raw_context.t) tzresult
    Lwt.t) ->
  (Raw_context.t * Migration_repr.origination_result list) tzresult Lwt.t
