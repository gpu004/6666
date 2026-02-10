(** Core domain types for TigerOCaml. *)

type error =
  | Invalid_u16 of int
  | Invalid_u32 of int64
  | Invalid_u64 of int64
  | Id_must_not_be_zero
  | Id_must_not_be_int_max
  | Ledger_must_not_be_zero
  | Timestamp_must_not_be_negative
  | Padding_must_be_zero
  | Flags_are_mutually_exclusive

type u16 = int
type u32 = int32
type u64 = int64
type u128 = { hi : int64; lo : int64 }

val u128_zero : u128
val u128_max : u128
val u128_equal : u128 -> u128 -> bool
val u128_compare : u128 -> u128 -> int
val u128_of_int : int -> u128
val u128_to_string : u128 -> string

(** Primitive wrappers (opaque). *)
type account_id
type transfer_id
type ledger_id
type amount
type timestamp

val account_id_of_u128 : u128 -> (account_id, error) result
val transfer_id_of_u128 : u128 -> (transfer_id, error) result
val ledger_id_of_u32 : u32 -> (ledger_id, error) result
val amount_of_u128 : u128 -> (amount, error) result
val timestamp_of_u64 : u64 -> (timestamp, error) result

val account_id_to_u128 : account_id -> u128
val transfer_id_to_u128 : transfer_id -> u128
val ledger_id_to_u32 : ledger_id -> u32
val amount_to_u128 : amount -> u128
val timestamp_to_u64 : timestamp -> u64

type account_flags = {
  linked : bool;
  debits_must_not_exceed_credits : bool;
  credits_must_not_exceed_debits : bool;
  history : bool;
  imported : bool;
  closed : bool;
  padding : int;
}

val account_flags_default : account_flags
val account_flags_make :
  linked:bool ->
  debits_must_not_exceed_credits:bool ->
  credits_must_not_exceed_debits:bool ->
  history:bool -> imported:bool -> closed:bool -> (account_flags, error) result
val account_flags_to_u16 : account_flags -> u16
val account_flags_of_u16 : u16 -> (account_flags, error) result

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
  padding : int;
}

val transfer_flags_default : transfer_flags
val transfer_flags_make :
  linked:bool ->
  pending:bool ->
  post_pending_transfer:bool ->
  void_pending_transfer:bool ->
  balancing_debit:bool ->
  balancing_credit:bool ->
  closing_debit:bool -> closing_credit:bool -> imported:bool ->
  (transfer_flags, error) result
val transfer_flags_to_u16 : transfer_flags -> u16
val transfer_flags_of_u16 : u16 -> (transfer_flags, error) result

type transfer_pending_status = None | Pending | Posted | Voided | Expired

val transfer_pending_status_to_u8 : transfer_pending_status -> int
val transfer_pending_status_of_u8 : int -> transfer_pending_status option

type account = {
  id : account_id;
  debits_pending : u128;
  debits_posted : u128;
  credits_pending : u128;
  credits_posted : u128;
  user_data_128 : u128;
  user_data_64 : u64;
  user_data_32 : u32;
  reserved : u32;
  ledger : ledger_id;
  code : u16;
  flags : account_flags;
  timestamp : u64;
}

val account_make :
  id:account_id ->
  debits_pending:u128 ->
  debits_posted:u128 ->
  credits_pending:u128 ->
  credits_posted:u128 ->
  user_data_128:u128 ->
  user_data_64:u64 ->
  user_data_32:u32 ->
  reserved:u32 ->
  ledger:ledger_id -> code:u16 -> flags:account_flags -> timestamp:u64 ->
  (account, error) result

type transfer = {
  id : transfer_id;
  debit_account_id : account_id;
  credit_account_id : account_id;
  amount : amount;
  pending_id : u128;
  user_data_128 : u128;
  user_data_64 : u64;
  user_data_32 : u32;
  timeout : u32;
  ledger : ledger_id;
  code : u16;
  flags : transfer_flags;
  timestamp : u64;
}

val transfer_make :
  id:transfer_id ->
  debit_account_id:account_id ->
  credit_account_id:account_id ->
  amount:amount ->
  pending_id:u128 ->
  user_data_128:u128 ->
  user_data_64:u64 ->
  user_data_32:u32 ->
  timeout:u32 ->
  ledger:ledger_id -> code:u16 -> flags:transfer_flags -> timestamp:u64 ->
  (transfer, error) result

type account_balance = {
  debits_pending : u128;
  debits_posted : u128;
  credits_pending : u128;
  credits_posted : u128;
  timestamp : u64;
  reserved : bytes;
}

val account_balance_make :
  debits_pending:u128 ->
  debits_posted:u128 ->
  credits_pending:u128 ->
  credits_posted:u128 -> timestamp:u64 -> reserved:bytes ->
  (account_balance, error) result

type create_accounts_result = { index : u32; result : Errors.create_account_result }
type create_transfers_result = { index : u32; result : Errors.create_transfer_result }

type account_filter_flags = {
  debits : bool;
  credits : bool;
  reversed : bool;
  padding : int;
}

val account_filter_flags_default : account_filter_flags
val account_filter_flags_to_u32 : account_filter_flags -> u32
val account_filter_flags_of_u32 : u32 -> (account_filter_flags, error) result

type account_filter = {
  account_id : u128;
  user_data_128 : u128;
  user_data_64 : u64;
  user_data_32 : u32;
  code : u16;
  reserved : bytes;
  timestamp_min : u64;
  timestamp_max : u64;
  limit : u32;
  flags : account_filter_flags;
}

val account_filter_make :
  account_id:u128 ->
  user_data_128:u128 ->
  user_data_64:u64 ->
  user_data_32:u32 ->
  code:u16 ->
  reserved:bytes ->
  timestamp_min:u64 -> timestamp_max:u64 -> limit:u32 ->
  flags:account_filter_flags -> (account_filter, error) result

type query_filter_flags = {
  reversed : bool;
  padding : int;
}

val query_filter_flags_default : query_filter_flags
val query_filter_flags_to_u32 : query_filter_flags -> u32
val query_filter_flags_of_u32 : u32 -> (query_filter_flags, error) result

type query_filter = {
  user_data_128 : u128;
  user_data_64 : u64;
  user_data_32 : u32;
  ledger : u32;
  code : u16;
  reserved : bytes;
  timestamp_min : u64;
  timestamp_max : u64;
  limit : u32;
  flags : query_filter_flags;
}

val query_filter_make :
  user_data_128:u128 ->
  user_data_64:u64 ->
  user_data_32:u32 ->
  ledger:u32 ->
  code:u16 ->
  reserved:bytes ->
  timestamp_min:u64 -> timestamp_max:u64 -> limit:u32 -> flags:query_filter_flags ->
  (query_filter, error) result

type change_event_type =
  | Single_phase
  | Two_phase_pending
  | Two_phase_posted
  | Two_phase_voided
  | Two_phase_expired

val change_event_type_to_u8 : change_event_type -> int
val change_event_type_of_u8 : int -> change_event_type option

type change_event = {
  transfer_id : u128;
  transfer_amount : u128;
  transfer_pending_id : u128;
  transfer_user_data_128 : u128;
  transfer_user_data_64 : u64;
  transfer_user_data_32 : u32;
  transfer_timeout : u32;
  transfer_code : u16;
  transfer_flags : transfer_flags;
  ledger : u32;
  event_type : change_event_type;
  reserved : bytes;
  debit_account_id : u128;
  debit_account_debits_pending : u128;
  debit_account_debits_posted : u128;
  debit_account_credits_pending : u128;
  debit_account_credits_posted : u128;
  debit_account_user_data_128 : u128;
  debit_account_user_data_64 : u64;
  debit_account_user_data_32 : u32;
  debit_account_code : u16;
  debit_account_flags : account_flags;
  credit_account_id : u128;
  credit_account_debits_pending : u128;
  credit_account_debits_posted : u128;
  credit_account_credits_pending : u128;
  credit_account_credits_posted : u128;
  credit_account_user_data_128 : u128;
  credit_account_user_data_64 : u64;
  credit_account_user_data_32 : u32;
  credit_account_code : u16;
  credit_account_flags : account_flags;
  timestamp : u64;
  transfer_timestamp : u64;
  debit_account_timestamp : u64;
  credit_account_timestamp : u64;
}

val change_event_make :
  transfer_id:u128 ->
  transfer_amount:u128 ->
  transfer_pending_id:u128 ->
  transfer_user_data_128:u128 ->
  transfer_user_data_64:u64 ->
  transfer_user_data_32:u32 ->
  transfer_timeout:u32 ->
  transfer_code:u16 ->
  transfer_flags:transfer_flags ->
  ledger:u32 ->
  event_type:change_event_type ->
  reserved:bytes ->
  debit_account_id:u128 ->
  debit_account_debits_pending:u128 ->
  debit_account_debits_posted:u128 ->
  debit_account_credits_pending:u128 ->
  debit_account_credits_posted:u128 ->
  debit_account_user_data_128:u128 ->
  debit_account_user_data_64:u64 ->
  debit_account_user_data_32:u32 ->
  debit_account_code:u16 ->
  debit_account_flags:account_flags ->
  credit_account_id:u128 ->
  credit_account_debits_pending:u128 ->
  credit_account_debits_posted:u128 ->
  credit_account_credits_pending:u128 ->
  credit_account_credits_posted:u128 ->
  credit_account_user_data_128:u128 ->
  credit_account_user_data_64:u64 ->
  credit_account_user_data_32:u32 ->
  credit_account_code:u16 ->
  credit_account_flags:account_flags ->
  timestamp:u64 ->
  transfer_timestamp:u64 -> debit_account_timestamp:u64 -> credit_account_timestamp:u64 ->
  (change_event, error) result

type change_events_filter = {
  timestamp_min : u64;
  timestamp_max : u64;
  limit : u32;
  reserved : bytes;
}

val change_events_filter_make :
  timestamp_min:u64 -> timestamp_max:u64 -> limit:u32 -> reserved:bytes ->
  (change_events_filter, error) result

(* Compatibility aliases used by older modules. *)
type uint128 = u128
val uint128_zero : uint128
val uint128_max : uint128
val uint128_equal : uint128 -> uint128 -> bool
val uint128_compare : uint128 -> uint128 -> int
val uint128_of_int : int -> uint128
val uint128_to_string : uint128 -> string

type id = account_id
val id_of_uint128 : uint128 -> (id, string) result
val id_to_uint128 : id -> uint128
val id_equal : id -> id -> bool
val id_compare : id -> id -> int
val id_to_string : id -> string

type ledger = ledger_id
val ledger_of_int32 : int32 -> (ledger, string) result
val ledger_to_int32 : ledger -> int32
val ledger_equal : ledger -> ledger -> bool

type code = u16
val code_of_int : int -> (code, string) result
val code_to_int : code -> int
val code_equal : code -> code -> bool

val account_flags_to_int : account_flags -> int
val account_flags_of_int : int -> account_flags
val transfer_flags_to_int : transfer_flags -> int
val transfer_flags_of_int : int -> transfer_flags
