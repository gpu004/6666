(** Persistent ledger state and core business rules.

    The intent is to keep mutation and persistence inside this module while the
    rest of the codebase consumes typed batch-oriented operations. *)

open Types

type t

(** Format a new empty data file for the given cluster. *)

val format : path:string -> cluster:U128.t -> unit
val load : string -> t
val save : t -> unit
val current_timestamp : t -> int64
val next_commit : t -> int64
val ensure_expired_and_saved : t -> unit
val with_lock : t -> (unit -> 'a) -> 'a
val register : t -> int64 * int64

(** Apply a batch of account creations and return one result per input event.

    Example:

    {[
      let results =
        State.create_accounts_batch state
          [ { account with id = U128.of_int 1; ledger = 1l; code = 10 } ]
    ]}

    The blackbox smoke path exercises this same function through the server. *)

val create_accounts_batch : t -> account list -> create_result list

(** Apply a batch of transfers, including pending/post/void rules. This is one
    of the densest validation surfaces in the prototype. *)

val create_transfers_batch : t -> transfer list -> create_result list
val lookup_accounts_batch : t -> U128.t list -> account list
val lookup_transfers_batch : t -> U128.t list -> transfer list

(** Query accounts by the compatibility filter.

    Example:

    {[
      let matches = State.query_accounts_batch state filter
    ]}

    The filter codec round-trips used for this surface are mirrored in
    [tests/unit_tests.ml]. *)

val query_accounts_batch : t -> query_filter -> account list
val query_transfers_batch : t -> query_filter -> transfer list
val get_account_transfers_batch : t -> account_filter -> transfer list
val get_account_balances_batch : t -> account_filter -> account_balance list
