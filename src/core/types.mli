(** Core domain types for TigerOCaml.

    All primitive types use abstract constructors that enforce TigerBeetle's
    validation rules at construction time. Invalid values cannot be represented. *)

(** {1 Primitive wrappers} *)

(** 128-bit unsigned integer, represented as a pair of [int64] (hi, lo). *)
type uint128 = { hi : int64; lo : int64 }

val uint128_zero : uint128
val uint128_max : uint128
val uint128_equal : uint128 -> uint128 -> bool
val uint128_compare : uint128 -> uint128 -> int
val uint128_of_int : int -> uint128
val uint128_to_string : uint128 -> string

(** {2 Domain-specific id types}

    Ids must not be [0] or [2^128 - 1]. *)

type id
(** Opaque 128-bit identifier (for accounts, transfers, etc.). *)

val id_of_uint128 : uint128 -> (id, string) result
val id_to_uint128 : id -> uint128
val id_equal : id -> id -> bool
val id_compare : id -> id -> int
val id_to_string : id -> string

(** {2 Ledger and code} *)

type ledger
(** Non-zero [uint32] ledger identifier. *)

val ledger_of_int32 : int32 -> (ledger, string) result
val ledger_to_int32 : ledger -> int32
val ledger_equal : ledger -> ledger -> bool

type code
(** Non-zero [uint16] application-defined code. *)

val code_of_int : int -> (code, string) result
val code_to_int : code -> int
val code_equal : code -> code -> bool

(** {2 Amount and timestamp} *)

type amount = uint128
(** 128-bit unsigned amount at caller-defined asset scale. *)

type timestamp = int64
(** Nanosecond-precision timestamp assigned by the cluster.
    [0L] means "not yet assigned" for non-imported events. *)

(** {1 Flags} *)

type account_flags = {
  linked : bool;
  debits_must_not_exceed_credits : bool;
  credits_must_not_exceed_debits : bool;
  history : bool;
  imported : bool;
  closed : bool;
}

val account_flags_default : account_flags
val account_flags_to_int : account_flags -> int
val account_flags_of_int : int -> account_flags

type transfer_flags = {
  linked : bool;
  pending : bool;
  post_pending_transfer : bool;
  void_pending_transfer : bool;
  balancing_debit : bool;
  balancing_credit : bool;
  closing_debit : bool;
  closing_credit : bool;
  imported : bool;
}

val transfer_flags_default : transfer_flags
val transfer_flags_to_int : transfer_flags -> int
val transfer_flags_of_int : int -> transfer_flags

(** {1 Domain records} *)

type account = {
  id : id;
  debits_pending : uint128;
  debits_posted : uint128;
  credits_pending : uint128;
  credits_posted : uint128;
  user_data_128 : uint128;
  user_data_64 : int64;
  user_data_32 : int32;
  reserved : int;
  ledger : ledger;
  code : code;
  flags : account_flags;
  timestamp : timestamp;
}

type transfer = {
  id : id;
  debit_account_id : id;
  credit_account_id : id;
  amount : amount;
  pending_id : uint128;
  user_data_128 : uint128;
  user_data_64 : int64;
  user_data_32 : int32;
  timeout : int32;
  ledger : ledger;
  code : code;
  flags : transfer_flags;
  timestamp : timestamp;
}

(** {1 Query filters} *)

type account_filter = {
  account_id : id;
  timestamp_min : timestamp;
  timestamp_max : timestamp;
  limit : int32;
  flags : int32;
}

type query_filter = {
  user_data_128 : uint128;
  user_data_64 : int64;
  user_data_32 : int32;
  ledger : int32;
  code : int;
  timestamp_min : timestamp;
  timestamp_max : timestamp;
  limit : int32;
  flags : int32;
}
