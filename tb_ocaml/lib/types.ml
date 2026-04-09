open U128

let header_size = 256
let message_size_max = 1 * 1024 * 1024
let message_body_size_max = message_size_max - header_size
let batch_size_limit = message_body_size_max

let command_ping_client = 3
let command_request = 5
let command_reply = 8

let op_register = 2
let op_pulse = 4
let op_deprecated_create_accounts_unbatched = 129
let op_deprecated_create_transfers_unbatched = 130
let op_deprecated_lookup_accounts_unbatched = 131
let op_deprecated_lookup_transfers_unbatched = 132
let op_deprecated_get_account_transfers_unbatched = 133
let op_deprecated_get_account_balances_unbatched = 134
let op_deprecated_query_accounts_unbatched = 135
let op_deprecated_query_transfers_unbatched = 136
let op_get_change_events = 137
let op_deprecated_create_accounts_sparse = 138
let op_deprecated_create_transfers_sparse = 139
let op_lookup_accounts = 140
let op_lookup_transfers = 141
let op_get_account_transfers = 142
let op_get_account_balances = 143
let op_query_accounts = 144
let op_query_transfers = 145
let op_create_accounts = 146
let op_create_transfers = 147

let account_flag_linked = 1
let account_flag_history = 1 lsl 3
let account_flag_imported = 1 lsl 4
let account_flag_closed = 1 lsl 5

let transfer_flag_linked = 1
let transfer_flag_pending = 1 lsl 1
let transfer_flag_post_pending_transfer = 1 lsl 2
let transfer_flag_void_pending_transfer = 1 lsl 3
let transfer_flag_closing_debit = 1 lsl 6
let transfer_flag_closing_credit = 1 lsl 7
let transfer_flag_imported = 1 lsl 8

let account_filter_debits = 1
let account_filter_credits = 1 lsl 1
let account_filter_reversed = 1 lsl 2

let query_filter_reversed = 1

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

type create_result = {
  timestamp : int64;
  status : int32;
}

let account_size = 128
let transfer_size = 128
let id_size = 16
let account_filter_size = 128
let query_filter_size = 64
let account_balance_size = 128
let create_result_size = 16
let create_error_result_size = 8
let register_request_size = 256
let register_result_size = 64

let create_account_created = Int32.minus_one
let create_account_linked_event_failed = 1l
let create_account_linked_event_chain_open = 2l
let create_account_timestamp_must_be_zero = 3l
let create_account_id_must_not_be_zero = 6l
let create_account_exists_with_different_flags = 15l
let create_account_exists_with_different_user_data_128 = 16l
let create_account_exists_with_different_user_data_64 = 17l
let create_account_exists_with_different_user_data_32 = 18l
let create_account_exists_with_different_ledger = 19l
let create_account_exists_with_different_code = 20l
let create_account_exists = 21l
let create_account_imported_event_expected = 22l
let create_account_imported_event_not_expected = 23l
let create_account_imported_event_timestamp_out_of_range = 24l
let create_account_imported_event_timestamp_must_not_advance = 25l
let create_account_ledger_must_not_be_zero = 13l
let create_account_code_must_not_be_zero = 14l
let create_account_imported_event_timestamp_must_not_regress = 26l

let create_transfer_created = Int32.minus_one
let create_transfer_linked_event_failed = 1l
let create_transfer_linked_event_chain_open = 2l
let create_transfer_timestamp_must_be_zero = 3l
let create_transfer_id_must_not_be_zero = 5l
let create_transfer_exists_with_different_flags = 36l
let create_transfer_exists_with_different_debit_account_id = 37l
let create_transfer_exists_with_different_credit_account_id = 38l
let create_transfer_exists_with_different_amount = 39l
let create_transfer_exists_with_different_pending_id = 40l
let create_transfer_exists_with_different_user_data_128 = 41l
let create_transfer_exists_with_different_user_data_64 = 42l
let create_transfer_exists_with_different_user_data_32 = 43l
let create_transfer_exists_with_different_timeout = 44l
let create_transfer_exists_with_different_ledger = 67l
let create_transfer_exists_with_different_code = 45l
let create_transfer_exists = 46l
let create_transfer_debit_account_id_must_not_be_zero = 8l
let create_transfer_credit_account_id_must_not_be_zero = 10l
let create_transfer_accounts_must_be_different = 12l
let create_transfer_pending_id_must_be_zero = 13l
let create_transfer_pending_id_must_not_be_zero = 14l
let create_transfer_closing_transfer_must_be_pending = 64l
let create_transfer_ledger_must_not_be_zero = 19l
let create_transfer_code_must_not_be_zero = 20l
let create_transfer_debit_account_not_found = 21l
let create_transfer_credit_account_not_found = 22l
let create_transfer_accounts_must_have_the_same_ledger = 23l
let create_transfer_transfer_must_have_the_same_ledger_as_accounts = 24l
let create_transfer_pending_transfer_not_found = 25l
let create_transfer_pending_transfer_not_pending = 26l
let create_transfer_pending_transfer_has_different_debit_account_id = 27l
let create_transfer_pending_transfer_has_different_credit_account_id = 28l
let create_transfer_pending_transfer_has_different_ledger = 29l
let create_transfer_pending_transfer_has_different_code = 30l
let create_transfer_exceeds_pending_transfer_amount = 31l
let create_transfer_pending_transfer_has_different_amount = 32l
let create_transfer_pending_transfer_already_posted = 33l
let create_transfer_pending_transfer_already_voided = 34l
let create_transfer_pending_transfer_expired = 35l
let create_transfer_imported_event_expected = 56l
let create_transfer_imported_event_not_expected = 57l
let create_transfer_imported_event_timestamp_out_of_range = 58l
let create_transfer_imported_event_timestamp_must_not_advance = 59l
let create_transfer_imported_event_timestamp_must_not_regress = 60l
let create_transfer_imported_event_timestamp_must_postdate_debit_account = 61l
let create_transfer_imported_event_timestamp_must_postdate_credit_account = 62l
let create_transfer_imported_event_timeout_must_be_zero = 63l
let create_transfer_debit_account_already_closed = 65l
let create_transfer_credit_account_already_closed = 66l

let amount_max = U128.max_value

let bool_flag flags bit = flags land bit <> 0

let event_size = function
  | op when op = op_deprecated_create_accounts_unbatched -> account_size
  | op when op = op_deprecated_create_transfers_unbatched -> transfer_size
  | op when op = op_deprecated_lookup_accounts_unbatched || op = op_deprecated_lookup_transfers_unbatched ->
      id_size
  | op when op = op_deprecated_get_account_transfers_unbatched || op = op_deprecated_get_account_balances_unbatched ->
      account_filter_size
  | op when op = op_deprecated_query_accounts_unbatched || op = op_deprecated_query_transfers_unbatched ->
      query_filter_size
  | op when op = op_deprecated_create_accounts_sparse -> account_size
  | op when op = op_deprecated_create_transfers_sparse -> transfer_size
  | op when op = op_create_accounts -> account_size
  | op when op = op_create_transfers -> transfer_size
  | op when op = op_lookup_accounts || op = op_lookup_transfers -> id_size
  | op when op = op_get_account_transfers || op = op_get_account_balances -> account_filter_size
  | op when op = op_query_accounts || op = op_query_transfers -> query_filter_size
  | op when op = op_register -> register_request_size
  | _ -> 0

let result_size = function
  | op
    when op = op_deprecated_create_accounts_unbatched
         || op = op_deprecated_create_transfers_unbatched
         || op = op_deprecated_create_accounts_sparse
         || op = op_deprecated_create_transfers_sparse ->
      create_error_result_size
  | op when op = op_deprecated_lookup_accounts_unbatched || op = op_deprecated_query_accounts_unbatched ->
      account_size
  | op
    when op = op_deprecated_lookup_transfers_unbatched
         || op = op_deprecated_get_account_transfers_unbatched
         || op = op_deprecated_query_transfers_unbatched ->
      transfer_size
  | op when op = op_deprecated_get_account_balances_unbatched -> account_balance_size
  | op
    when op = op_deprecated_create_accounts_sparse
         || op = op_deprecated_create_transfers_sparse ->
      create_error_result_size
  | op when op = op_create_accounts || op = op_create_transfers -> create_result_size
  | op when op = op_lookup_accounts || op = op_query_accounts -> account_size
  | op when op = op_lookup_transfers || op = op_get_account_transfers || op = op_query_transfers ->
      transfer_size
  | op when op = op_get_account_balances -> account_balance_size
  | op when op = op_register -> register_result_size
  | _ -> 0

let is_multi_batch = function
  | op
    when op = op_deprecated_create_accounts_sparse
         || op = op_deprecated_create_transfers_sparse || op = op_create_accounts
         || op = op_create_transfers || op = op_lookup_accounts
         || op = op_lookup_transfers || op = op_get_account_transfers
         || op = op_get_account_balances || op = op_query_accounts || op = op_query_transfers ->
      true
  | _ -> false

let account_status_name = function
  | s when s = create_account_created -> "tigerbeetle.CreateAccountStatus.created"
  | s when s = create_account_exists -> "tigerbeetle.CreateAccountStatus.exists"
  | s when s = create_account_linked_event_chain_open ->
      "tigerbeetle.CreateAccountStatus.linked_event_chain_open"
  | s when s = create_account_timestamp_must_be_zero ->
      "tigerbeetle.CreateAccountStatus.timestamp_must_be_zero"
  | s when s = create_account_linked_event_failed ->
      "tigerbeetle.CreateAccountStatus.linked_event_failed"
  | s when s = create_account_exists_with_different_flags ->
      "tigerbeetle.CreateAccountStatus.exists_with_different_flags"
  | _ -> "tigerbeetle.CreateAccountStatus.unknown"

let transfer_status_name = function
  | s when s = create_transfer_created -> "tigerbeetle.CreateTransferStatus.created"
  | s when s = create_transfer_exists -> "tigerbeetle.CreateTransferStatus.exists"
  | s when s = create_transfer_linked_event_chain_open ->
      "tigerbeetle.CreateTransferStatus.linked_event_chain_open"
  | s when s = create_transfer_timestamp_must_be_zero ->
      "tigerbeetle.CreateTransferStatus.timestamp_must_be_zero"
  | s when s = create_transfer_linked_event_failed ->
      "tigerbeetle.CreateTransferStatus.linked_event_failed"
  | s when s = create_transfer_exists_with_different_flags ->
      "tigerbeetle.CreateTransferStatus.exists_with_different_flags"
  | s when s = create_transfer_pending_transfer_not_found ->
      "tigerbeetle.CreateTransferStatus.pending_transfer_not_found"
  | s when s = create_transfer_pending_transfer_not_pending ->
      "tigerbeetle.CreateTransferStatus.pending_transfer_not_pending"
  | s when s = create_transfer_pending_transfer_has_different_debit_account_id ->
      "tigerbeetle.CreateTransferStatus.pending_transfer_has_different_debit_account_id"
  | s when s = create_transfer_pending_transfer_has_different_credit_account_id ->
      "tigerbeetle.CreateTransferStatus.pending_transfer_has_different_credit_account_id"
  | s when s = create_transfer_pending_transfer_has_different_ledger ->
      "tigerbeetle.CreateTransferStatus.pending_transfer_has_different_ledger"
  | s when s = create_transfer_pending_transfer_has_different_code ->
      "tigerbeetle.CreateTransferStatus.pending_transfer_has_different_code"
  | s when s = create_transfer_exceeds_pending_transfer_amount ->
      "tigerbeetle.CreateTransferStatus.exceeds_pending_transfer_amount"
  | s when s = create_transfer_pending_transfer_has_different_amount ->
      "tigerbeetle.CreateTransferStatus.pending_transfer_has_different_amount"
  | s when s = create_transfer_pending_transfer_already_posted ->
      "tigerbeetle.CreateTransferStatus.pending_transfer_already_posted"
  | s when s = create_transfer_pending_transfer_already_voided ->
      "tigerbeetle.CreateTransferStatus.pending_transfer_already_voided"
  | s when s = create_transfer_pending_transfer_expired ->
      "tigerbeetle.CreateTransferStatus.pending_transfer_expired"
  | s when s = create_transfer_closing_transfer_must_be_pending ->
      "tigerbeetle.CreateTransferStatus.closing_transfer_must_be_pending"
  | s when s = create_transfer_debit_account_not_found ->
      "tigerbeetle.CreateTransferStatus.debit_account_not_found"
  | s when s = create_transfer_credit_account_not_found ->
      "tigerbeetle.CreateTransferStatus.credit_account_not_found"
  | s when s = create_transfer_accounts_must_have_the_same_ledger ->
      "tigerbeetle.CreateTransferStatus.accounts_must_have_the_same_ledger"
  | s when s = create_transfer_transfer_must_have_the_same_ledger_as_accounts ->
      "tigerbeetle.CreateTransferStatus.transfer_must_have_the_same_ledger_as_accounts"
  | s when s = create_transfer_debit_account_already_closed ->
      "tigerbeetle.CreateTransferStatus.debit_account_already_closed"
  | s when s = create_transfer_credit_account_already_closed ->
      "tigerbeetle.CreateTransferStatus.credit_account_already_closed"
  | s when s = create_transfer_exists_with_different_ledger ->
      "tigerbeetle.CreateTransferStatus.exists_with_different_ledger"
  | _ -> "tigerbeetle.CreateTransferStatus.unknown"

let account_flag_names flags =
  let out = ref [] in
  if bool_flag flags account_flag_linked then out := "linked" :: !out;
  if bool_flag flags account_flag_history then out := "history" :: !out;
  if bool_flag flags account_flag_imported then out := "imported" :: !out;
  if bool_flag flags account_flag_closed then out := "closed" :: !out;
  List.rev !out

let transfer_flag_names flags =
  let out = ref [] in
  if bool_flag flags transfer_flag_linked then out := "linked" :: !out;
  if bool_flag flags transfer_flag_pending then out := "pending" :: !out;
  if bool_flag flags transfer_flag_post_pending_transfer then
    out := "post_pending_transfer" :: !out;
  if bool_flag flags transfer_flag_void_pending_transfer then
    out := "void_pending_transfer" :: !out;
  if bool_flag flags transfer_flag_closing_debit then out := "closing_debit" :: !out;
  if bool_flag flags transfer_flag_closing_credit then out := "closing_credit" :: !out;
  if bool_flag flags transfer_flag_imported then out := "imported" :: !out;
  List.rev !out
