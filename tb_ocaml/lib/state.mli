open Types

type t

val format : path:string -> cluster:U128.t -> unit
val load : string -> t
val save : t -> unit
val current_timestamp : t -> int64
val next_commit : t -> int64
val ensure_expired_and_saved : t -> unit
val with_lock : t -> (unit -> 'a) -> 'a
val register : t -> int64 * int64
val create_accounts_batch : t -> account list -> create_result list
val create_transfers_batch : t -> transfer list -> create_result list
val lookup_accounts_batch : t -> U128.t list -> account list
val lookup_transfers_batch : t -> U128.t list -> transfer list
val query_accounts_batch : t -> query_filter -> account list
val query_transfers_batch : t -> query_filter -> transfer list
val get_account_transfers_batch : t -> account_filter -> transfer list
val get_account_balances_batch : t -> account_filter -> account_balance list
