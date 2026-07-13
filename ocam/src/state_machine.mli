(** Deterministic TigerBeetle ledger core.

    The module deliberately has no Async or storage dependency. Replication assigns
    timestamps and calls these functions in commit order; an adapter can then persist
    the returned state through the unchanged Zig LSM/VSR implementation. *)

module U128 : sig
  (** An unsigned, fixed-width 128-bit value.

      This is used for IDs and monetary amounts. Arithmetic reports overflow or
      underflow rather than wrapping. *)
  type t

  (** The value [0]. *)
  val zero : t

  (** The largest representable unsigned 128-bit value. *)
  val max_value : t

  (** [of_int n] converts non-negative [n], rejecting negative input. *)
  val of_int : int -> t

  (** Builds a value from its unsigned high and low 64-bit words. *)
  val of_int64_pair : hi:int64 -> lo:int64 -> t

  (** Returns the unsigned high and low 64-bit words. *)
  val to_int64_pair : t -> int64 * int64

  (** Unsigned numeric comparison. *)
  val compare : t -> t -> int

  (** Unsigned numeric equality. *)
  val equal : t -> t -> bool

  (** Adds two values, reporting [`Overflow] instead of wrapping. *)
  val add : t -> t -> (t, [ `Overflow ]) result

  (** Subtracts two values, reporting [`Underflow] when the result is negative. *)
  val sub : t -> t -> (t, [ `Underflow ]) result

  (** The smaller of two unsigned values. *)
  val min : t -> t -> t

  (** Decimal output for values fitting in 64 bits, hexadecimal otherwise. *)
  val to_string : t -> string
end

(** Account behavior flags. [linked] controls atomic batches; [imported]
    changes timestamp validation; [closed] is set by a successful closing
    transfer and prevents later transfers involving the account. *)
type account_flags =
  { linked : bool
  ; debits_must_not_exceed_credits : bool
  ; credits_must_not_exceed_debits : bool
  ; history : bool
  ; imported : bool
  ; closed : bool
  }

(** Transfer behavior flags. [post_pending_transfer] and
    [void_pending_transfer] cannot both be selected; each resolves an existing
    pending transfer. *)
type transfer_flags =
  { linked : bool
  ; pending : bool
  ; post_pending_transfer : bool
  ; void_pending_transfer : bool
  ; balancing_debit : bool
  ; balancing_credit : bool
  ; closing_debit : bool
  ; closing_credit : bool
  ; imported : bool
  }

(** An account request and the stored account representation. Account creation
    requires zero balance fields; successful transfers update those fields. *)
type account =
  { id : U128.t
  ; debits_pending : U128.t
  ; debits_posted : U128.t
  ; credits_pending : U128.t
  ; credits_posted : U128.t
  ; user_data_128 : U128.t
  ; user_data_64 : int64
  ; user_data_32 : int32
  ; ledger : int32
  ; code : int
  ; flags : account_flags
  ; timestamp : int64
  }

(** A transfer request and the stored transfer representation. Non-imported
    requests must have [timestamp = 0L]; the create operation assigns it. *)
type transfer =
  { id : U128.t
  ; debit_account_id : U128.t
  ; credit_account_id : U128.t
  ; amount : U128.t
  ; pending_id : U128.t
  ; user_data_128 : U128.t
  ; user_data_64 : int64
  ; user_data_32 : int32
  ; timeout : int32
  ; ledger : int32
  ; code : int
  ; flags : transfer_flags
  ; timestamp : int64
  }

(** Lifecycle state of a pending transfer. *)
type pending_status =
  | Pending
  | Posted
  | Voided
  | Expired

type create_account_status =
  | Account_created
  | Account_exists
  | Account_linked_event_failed
  | Account_linked_event_chain_open
  | Account_timestamp_must_be_zero
  | Account_id_must_not_be_zero
  | Account_id_must_not_be_int_max
  | Account_exists_with_different_flags
  | Account_exists_with_different_user_data_128
  | Account_exists_with_different_user_data_64
  | Account_exists_with_different_user_data_32
  | Account_exists_with_different_ledger
  | Account_exists_with_different_code
  | Account_flags_are_mutually_exclusive
  | Account_debits_pending_must_be_zero
  | Account_debits_posted_must_be_zero
  | Account_credits_pending_must_be_zero
  | Account_credits_posted_must_be_zero
  | Account_ledger_must_not_be_zero
  | Account_code_must_not_be_zero
  | Account_imported_timestamp_out_of_range
  | Account_imported_timestamp_must_not_regress

type create_transfer_status =
  | Transfer_created
  | Transfer_exists
  | Transfer_linked_event_failed
  | Transfer_linked_event_chain_open
  | Transfer_timestamp_must_be_zero
  | Transfer_id_must_not_be_zero
  | Transfer_id_must_not_be_int_max
  | Transfer_id_already_failed
  | Transfer_exists_with_different_request
  | Transfer_flags_are_mutually_exclusive
  | Transfer_debit_account_id_must_not_be_zero
  | Transfer_credit_account_id_must_not_be_zero
  | Transfer_accounts_must_be_different
  | Transfer_pending_id_must_be_zero
  | Transfer_pending_id_must_not_be_zero
  | Transfer_pending_id_must_be_different
  | Transfer_timeout_reserved_for_pending_transfer
  | Transfer_closing_transfer_must_be_pending
  | Transfer_ledger_must_not_be_zero
  | Transfer_code_must_not_be_zero
  | Transfer_debit_account_not_found
  | Transfer_credit_account_not_found
  | Transfer_accounts_must_have_same_ledger
  | Transfer_must_have_same_ledger_as_accounts
  | Transfer_pending_transfer_not_found
  | Transfer_pending_transfer_not_pending
  | Transfer_pending_transfer_has_different_accounts
  | Transfer_pending_transfer_has_different_ledger
  | Transfer_pending_transfer_has_different_code
  | Transfer_exceeds_pending_transfer_amount
  | Transfer_pending_transfer_has_different_amount
  | Transfer_pending_transfer_already_posted
  | Transfer_pending_transfer_already_voided
  | Transfer_pending_transfer_expired
  | Transfer_account_already_closed
  | Transfer_overflows_balance
  | Transfer_overflows_timeout
  | Transfer_exceeds_credits
  | Transfer_exceeds_debits
  | Transfer_imported_timestamp_out_of_range
  | Transfer_imported_timestamp_must_not_regress
  | Transfer_imported_timeout_must_be_zero

(** One result for one create request. Successful requests have their assigned
    timestamp; failed requests normally have timestamp zero. *)
type 'status create_result =
  { timestamp : int64
  ; status : 'status
  }

(** Filters for account and transfer queries. Zero metadata, ledger, and code
    fields are wildcards. A zero timestamp bound is unbounded. *)
type query_filter =
  { user_data_128 : U128.t
  ; user_data_64 : int64
  ; user_data_32 : int32
  ; ledger : int32
  ; code : int
  ; timestamp_min : int64
  ; timestamp_max : int64
  ; limit : int
  ; reversed : bool
  }

(** Filters for transfer and balance reads scoped to an account. *)
type account_filter =
  { account_id : U128.t
  ; user_data_128 : U128.t
  ; user_data_64 : int64
  ; user_data_32 : int32
  ; code : int
  ; timestamp_min : int64
  ; timestamp_max : int64
  ; limit : int
  ; debits : bool
  ; credits : bool
  ; reversed : bool
  }

type t

(** Creates an empty in-memory ledger state. *)
val empty : unit -> t

(** The latest timestamp of a successful state-changing operation. *)
val commit_timestamp : t -> int64

(** Validates and stores account requests in batch order.

    Consecutive linked requests are atomic. Each result corresponds to one
    request in [account list]. *)
val create_accounts
  :  t
  -> timestamp:int64
  -> account list
  -> create_account_status create_result list

(** Validates and applies transfer requests in batch order.

    Normal transfers update posted balances; pending transfers update pending
    balances. Consecutive linked requests are atomic. *)
val create_transfers
  :  t
  -> timestamp:int64
  -> transfer list
  -> create_transfer_status create_result list

(** Expires pending transfers whose timeout has elapsed at [timestamp], returning
    the number expired. *)
val expire_pending_transfers : t -> timestamp:int64 -> int

(** Returns found accounts in the order of requested IDs, omitting unknown IDs. *)
val lookup_accounts : t -> U128.t list -> account list

(** Returns found transfers in the order of requested IDs, omitting unknown IDs. *)
val lookup_transfers : t -> U128.t list -> transfer list

(** Filters accounts, sorts them by timestamp, then applies [filter.limit]. *)
val query_accounts : t -> query_filter -> account list

(** Filters transfers, sorts them by timestamp, then applies [filter.limit]. *)
val query_transfers : t -> query_filter -> transfer list

(** Returns transfers for an account's requested debit and/or credit side. *)
val get_account_transfers : t -> account_filter -> transfer list

(** Returns per-transfer balance snapshots for an account created with [flags.history].
    Transfer metadata, direction, timestamp, ordering, and limit fields are applied. *)
val get_account_balances : t -> account_filter -> account list
