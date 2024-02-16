(** Get the address of the Buffer Contract receiving the
    Liquidity Baking subsidy *)
val get_buffer_address : Raw_context.t -> Contract_hash.t tzresult Lwt.t

(** [on_subsidy_allowed ctxt ~per_block_vote f] updates the toggle EMA according to
    [toggle_vote]. Then the callback function [f] is called if the following
    conditions are met:
    - the updated EMA is below the threshold,
    - the CPMM contract exists.

    The role of the callback function [f] is to send the subsidy to the CPMM,
    see [apply_liquidity_baking_subsidy] in [apply.ml]. *)
val on_subsidy_allowed :
  Raw_context.t ->
  per_block_vote:Per_block_votes_repr.per_block_vote ->
  (Raw_context.t -> Contract_hash.t -> (Raw_context.t * 'a list) tzresult Lwt.t) ->
  (Raw_context.t * 'a list * Per_block_votes_repr.Liquidity_baking_toggle_EMA.t)
  tzresult
  Lwt.t
