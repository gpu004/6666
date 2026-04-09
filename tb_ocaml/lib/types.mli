type account = {
  id : U128.t;
  debits_pending : U128.t;
  debits_posted : U128.t;
  credits_pending : U128.t;
  credits_posted : U128.t;
  user_data_128 : U128.t;
  user_data_64 : int64;
  user_data_32 : int32;
  ledger : int32;
  code : int;
  flags : int;
  timestamp : int64;
}

type transfer = {
  id : U128.t;
  debit_account_id : U128.t;
  credit_account_id : U128.t;
  amount : U128.t;
  pending_id : U128.t;
  user_data_128 : U128.t;
  user_data_64 : int64;
  user_data_32 : int32;
  timeout : int32;
  ledger : int32;
  code : int;
  flags : int;
  timestamp : int64;
}

type account_filter = {
  account_id : U128.t;
  user_data_128 : U128.t;
  user_data_64 : int64;
  user_data_32 : int32;
  code : int;
  timestamp_min : int64;
  timestamp_max : int64;
  limit : int32;
  flags : int32;
}

type query_filter = {
  user_data_128 : U128.t;
  user_data_64 : int64;
  user_data_32 : int32;
  ledger : int32;
  code : int;
  timestamp_min : int64;
  timestamp_max : int64;
  limit : int32;
  flags : int32;
}

type account_balance = {
  debits_pending : U128.t;
  debits_posted : U128.t;
  credits_pending : U128.t;
  credits_posted : U128.t;
  timestamp : int64;
}

type create_result = { timestamp : int64; status : int32 }

val header_size : int
val message_size_max : int
val message_body_size_max : int
val batch_size_limit : int
val command_ping_client : int
val command_request : int
val command_reply : int
val op_register : int
val op_pulse : int
val op_deprecated_create_accounts_unbatched : int
val op_deprecated_create_transfers_unbatched : int
val op_deprecated_lookup_accounts_unbatched : int
val op_deprecated_lookup_transfers_unbatched : int
val op_deprecated_get_account_transfers_unbatched : int
val op_deprecated_get_account_balances_unbatched : int
val op_deprecated_query_accounts_unbatched : int
val op_deprecated_query_transfers_unbatched : int
val op_get_change_events : int
val op_deprecated_create_accounts_sparse : int
val op_deprecated_create_transfers_sparse : int
val op_lookup_accounts : int
val op_lookup_transfers : int
val op_get_account_transfers : int
val op_get_account_balances : int
val op_query_accounts : int
val op_query_transfers : int
val op_create_accounts : int
val op_create_transfers : int
val account_flag_linked : int
val account_flag_history : int
val account_flag_imported : int
val account_flag_closed : int
val transfer_flag_linked : int
val transfer_flag_pending : int
val transfer_flag_post_pending_transfer : int
val transfer_flag_void_pending_transfer : int
val transfer_flag_closing_debit : int
val transfer_flag_closing_credit : int
val transfer_flag_imported : int
val account_filter_debits : int
val account_filter_credits : int
val account_filter_reversed : int
val query_filter_reversed : int
val account_size : int
val transfer_size : int
val id_size : int
val account_filter_size : int
val query_filter_size : int
val account_balance_size : int
val create_result_size : int
val create_error_result_size : int
val register_request_size : int
val register_result_size : int
val create_account_created : int32
val create_account_linked_event_failed : int32
val create_account_linked_event_chain_open : int32
val create_account_timestamp_must_be_zero : int32
val create_account_id_must_not_be_zero : int32
val create_account_exists_with_different_flags : int32
val create_account_exists_with_different_user_data_128 : int32
val create_account_exists_with_different_user_data_64 : int32
val create_account_exists_with_different_user_data_32 : int32
val create_account_exists_with_different_ledger : int32
val create_account_exists_with_different_code : int32
val create_account_exists : int32
val create_account_imported_event_expected : int32
val create_account_imported_event_not_expected : int32
val create_account_imported_event_timestamp_out_of_range : int32
val create_account_imported_event_timestamp_must_not_advance : int32
val create_account_ledger_must_not_be_zero : int32
val create_account_code_must_not_be_zero : int32
val create_account_imported_event_timestamp_must_not_regress : int32
val create_transfer_created : int32
val create_transfer_linked_event_failed : int32
val create_transfer_linked_event_chain_open : int32
val create_transfer_timestamp_must_be_zero : int32
val create_transfer_id_must_not_be_zero : int32
val create_transfer_exists_with_different_flags : int32
val create_transfer_exists_with_different_debit_account_id : int32
val create_transfer_exists_with_different_credit_account_id : int32
val create_transfer_exists_with_different_amount : int32
val create_transfer_exists_with_different_pending_id : int32
val create_transfer_exists_with_different_user_data_128 : int32
val create_transfer_exists_with_different_user_data_64 : int32
val create_transfer_exists_with_different_user_data_32 : int32
val create_transfer_exists_with_different_timeout : int32
val create_transfer_exists_with_different_ledger : int32
val create_transfer_exists_with_different_code : int32
val create_transfer_exists : int32
val create_transfer_debit_account_id_must_not_be_zero : int32
val create_transfer_credit_account_id_must_not_be_zero : int32
val create_transfer_accounts_must_be_different : int32
val create_transfer_pending_id_must_be_zero : int32
val create_transfer_pending_id_must_not_be_zero : int32
val create_transfer_closing_transfer_must_be_pending : int32
val create_transfer_ledger_must_not_be_zero : int32
val create_transfer_code_must_not_be_zero : int32
val create_transfer_debit_account_not_found : int32
val create_transfer_credit_account_not_found : int32
val create_transfer_accounts_must_have_the_same_ledger : int32
val create_transfer_transfer_must_have_the_same_ledger_as_accounts : int32
val create_transfer_pending_transfer_not_found : int32
val create_transfer_pending_transfer_not_pending : int32
val create_transfer_pending_transfer_has_different_debit_account_id : int32
val create_transfer_pending_transfer_has_different_credit_account_id : int32
val create_transfer_pending_transfer_has_different_ledger : int32
val create_transfer_pending_transfer_has_different_code : int32
val create_transfer_exceeds_pending_transfer_amount : int32
val create_transfer_pending_transfer_has_different_amount : int32
val create_transfer_pending_transfer_already_posted : int32
val create_transfer_pending_transfer_already_voided : int32
val create_transfer_pending_transfer_expired : int32
val create_transfer_imported_event_expected : int32
val create_transfer_imported_event_not_expected : int32
val create_transfer_imported_event_timestamp_out_of_range : int32
val create_transfer_imported_event_timestamp_must_not_advance : int32
val create_transfer_imported_event_timestamp_must_not_regress : int32
val create_transfer_imported_event_timestamp_must_postdate_debit_account : int32

val create_transfer_imported_event_timestamp_must_postdate_credit_account :
  int32

val create_transfer_imported_event_timeout_must_be_zero : int32
val create_transfer_debit_account_already_closed : int32
val create_transfer_credit_account_already_closed : int32
val amount_max : U128.t
val bool_flag : int -> int -> bool
val event_size : int -> int
val result_size : int -> int
val is_multi_batch : int -> bool
val account_status_name : int32 -> string
val transfer_status_name : int32 -> string
val account_flag_names : int -> string list
val transfer_flag_names : int -> string list
