(* errors.ml — Result codes for TigerOCaml operations *)

type create_account_result =
  | Ok
  | Linked_event_failed
  | Linked_event_chain_open
  | Timestamp_must_be_zero
  | Reserved_field
  | Reserved_flag
  | Id_must_not_be_zero
  | Id_must_not_be_int_max
  | Flags_are_mutually_exclusive
  | Debits_pending_must_be_zero
  | Debits_posted_must_be_zero
  | Credits_pending_must_be_zero
  | Credits_posted_must_be_zero
  | Ledger_must_not_be_zero
  | Code_must_not_be_zero
  | Exists_with_different_flags
  | Exists_with_different_user_data_128
  | Exists_with_different_user_data_64
  | Exists_with_different_user_data_32
  | Exists_with_different_ledger
  | Exists_with_different_code
  | Exists
  | Imported_event_expected
  | Imported_event_not_expected
  | Imported_event_timestamp_out_of_range
  | Imported_event_timestamp_must_not_advance
  | Imported_event_timestamp_must_not_regress

let create_account_result_to_u32 = function
  | Ok -> 0l
  | Linked_event_failed -> 1l
  | Linked_event_chain_open -> 2l
  | Timestamp_must_be_zero -> 3l
  | Reserved_field -> 4l
  | Reserved_flag -> 5l
  | Id_must_not_be_zero -> 6l
  | Id_must_not_be_int_max -> 7l
  | Flags_are_mutually_exclusive -> 8l
  | Debits_pending_must_be_zero -> 9l
  | Debits_posted_must_be_zero -> 10l
  | Credits_pending_must_be_zero -> 11l
  | Credits_posted_must_be_zero -> 12l
  | Ledger_must_not_be_zero -> 13l
  | Code_must_not_be_zero -> 14l
  | Exists_with_different_flags -> 15l
  | Exists_with_different_user_data_128 -> 16l
  | Exists_with_different_user_data_64 -> 17l
  | Exists_with_different_user_data_32 -> 18l
  | Exists_with_different_ledger -> 19l
  | Exists_with_different_code -> 20l
  | Exists -> 21l
  | Imported_event_expected -> 22l
  | Imported_event_not_expected -> 23l
  | Imported_event_timestamp_out_of_range -> 24l
  | Imported_event_timestamp_must_not_advance -> 25l
  | Imported_event_timestamp_must_not_regress -> 26l

let create_account_result_of_u32 = function
  | 0l -> Some Ok
  | 1l -> Some Linked_event_failed
  | 2l -> Some Linked_event_chain_open
  | 3l -> Some Timestamp_must_be_zero
  | 4l -> Some Reserved_field
  | 5l -> Some Reserved_flag
  | 6l -> Some Id_must_not_be_zero
  | 7l -> Some Id_must_not_be_int_max
  | 8l -> Some Flags_are_mutually_exclusive
  | 9l -> Some Debits_pending_must_be_zero
  | 10l -> Some Debits_posted_must_be_zero
  | 11l -> Some Credits_pending_must_be_zero
  | 12l -> Some Credits_posted_must_be_zero
  | 13l -> Some Ledger_must_not_be_zero
  | 14l -> Some Code_must_not_be_zero
  | 15l -> Some Exists_with_different_flags
  | 16l -> Some Exists_with_different_user_data_128
  | 17l -> Some Exists_with_different_user_data_64
  | 18l -> Some Exists_with_different_user_data_32
  | 19l -> Some Exists_with_different_ledger
  | 20l -> Some Exists_with_different_code
  | 21l -> Some Exists
  | 22l -> Some Imported_event_expected
  | 23l -> Some Imported_event_not_expected
  | 24l -> Some Imported_event_timestamp_out_of_range
  | 25l -> Some Imported_event_timestamp_must_not_advance
  | 26l -> Some Imported_event_timestamp_must_not_regress
  | _ -> None

let create_account_result_to_string = function
  | Ok -> "ok"
  | Linked_event_failed -> "linked_event_failed"
  | Linked_event_chain_open -> "linked_event_chain_open"
  | Timestamp_must_be_zero -> "timestamp_must_be_zero"
  | Reserved_field -> "reserved_field"
  | Reserved_flag -> "reserved_flag"
  | Id_must_not_be_zero -> "id_must_not_be_zero"
  | Id_must_not_be_int_max -> "id_must_not_be_int_max"
  | Flags_are_mutually_exclusive -> "flags_are_mutually_exclusive"
  | Debits_pending_must_be_zero -> "debits_pending_must_be_zero"
  | Debits_posted_must_be_zero -> "debits_posted_must_be_zero"
  | Credits_pending_must_be_zero -> "credits_pending_must_be_zero"
  | Credits_posted_must_be_zero -> "credits_posted_must_be_zero"
  | Ledger_must_not_be_zero -> "ledger_must_not_be_zero"
  | Code_must_not_be_zero -> "code_must_not_be_zero"
  | Exists_with_different_flags -> "exists_with_different_flags"
  | Exists_with_different_user_data_128 -> "exists_with_different_user_data_128"
  | Exists_with_different_user_data_64 -> "exists_with_different_user_data_64"
  | Exists_with_different_user_data_32 -> "exists_with_different_user_data_32"
  | Exists_with_different_ledger -> "exists_with_different_ledger"
  | Exists_with_different_code -> "exists_with_different_code"
  | Exists -> "exists"
  | Imported_event_expected -> "imported_event_expected"
  | Imported_event_not_expected -> "imported_event_not_expected"
  | Imported_event_timestamp_out_of_range -> "imported_event_timestamp_out_of_range"
  | Imported_event_timestamp_must_not_advance ->
      "imported_event_timestamp_must_not_advance"
  | Imported_event_timestamp_must_not_regress ->
      "imported_event_timestamp_must_not_regress"

type create_transfer_result =
  | Ok
  | Linked_event_failed
  | Linked_event_chain_open
  | Timestamp_must_be_zero
  | Reserved_flag
  | Id_must_not_be_zero
  | Id_must_not_be_int_max
  | Flags_are_mutually_exclusive
  | Debit_account_id_must_not_be_zero
  | Debit_account_id_must_not_be_int_max
  | Credit_account_id_must_not_be_zero
  | Credit_account_id_must_not_be_int_max
  | Accounts_must_be_different
  | Pending_id_must_be_zero
  | Pending_id_must_not_be_zero
  | Pending_id_must_not_be_int_max
  | Pending_id_must_be_different
  | Timeout_reserved_for_pending_transfer
  | Deprecated_18
  | Ledger_must_not_be_zero
  | Code_must_not_be_zero
  | Debit_account_not_found
  | Credit_account_not_found
  | Accounts_must_have_the_same_ledger
  | Transfer_must_have_the_same_ledger_as_accounts
  | Pending_transfer_not_found
  | Pending_transfer_not_pending
  | Pending_transfer_has_different_debit_account_id
  | Pending_transfer_has_different_credit_account_id
  | Pending_transfer_has_different_ledger
  | Pending_transfer_has_different_code
  | Exceeds_pending_transfer_amount
  | Pending_transfer_has_different_amount
  | Pending_transfer_already_posted
  | Pending_transfer_already_voided
  | Pending_transfer_expired
  | Exists_with_different_flags
  | Exists_with_different_debit_account_id
  | Exists_with_different_credit_account_id
  | Exists_with_different_amount
  | Exists_with_different_pending_id
  | Exists_with_different_user_data_128
  | Exists_with_different_user_data_64
  | Exists_with_different_user_data_32
  | Exists_with_different_timeout
  | Exists_with_different_code
  | Exists
  | Overflows_debits_pending
  | Overflows_credits_pending
  | Overflows_debits_posted
  | Overflows_credits_posted
  | Overflows_debits
  | Overflows_credits
  | Overflows_timeout
  | Exceeds_credits
  | Exceeds_debits
  | Imported_event_expected
  | Imported_event_not_expected
  | Imported_event_timestamp_out_of_range
  | Imported_event_timestamp_must_not_advance
  | Imported_event_timestamp_must_not_regress
  | Imported_event_timestamp_must_postdate_debit_account
  | Imported_event_timestamp_must_postdate_credit_account
  | Imported_event_timeout_must_be_zero
  | Closing_transfer_must_be_pending
  | Debit_account_already_closed
  | Credit_account_already_closed
  | Exists_with_different_ledger
  | Id_already_failed

let create_transfer_result_to_u32 = function
  | Ok -> 0l
  | Linked_event_failed -> 1l
  | Linked_event_chain_open -> 2l
  | Timestamp_must_be_zero -> 3l
  | Reserved_flag -> 4l
  | Id_must_not_be_zero -> 5l
  | Id_must_not_be_int_max -> 6l
  | Flags_are_mutually_exclusive -> 7l
  | Debit_account_id_must_not_be_zero -> 8l
  | Debit_account_id_must_not_be_int_max -> 9l
  | Credit_account_id_must_not_be_zero -> 10l
  | Credit_account_id_must_not_be_int_max -> 11l
  | Accounts_must_be_different -> 12l
  | Pending_id_must_be_zero -> 13l
  | Pending_id_must_not_be_zero -> 14l
  | Pending_id_must_not_be_int_max -> 15l
  | Pending_id_must_be_different -> 16l
  | Timeout_reserved_for_pending_transfer -> 17l
  | Deprecated_18 -> 18l
  | Ledger_must_not_be_zero -> 19l
  | Code_must_not_be_zero -> 20l
  | Debit_account_not_found -> 21l
  | Credit_account_not_found -> 22l
  | Accounts_must_have_the_same_ledger -> 23l
  | Transfer_must_have_the_same_ledger_as_accounts -> 24l
  | Pending_transfer_not_found -> 25l
  | Pending_transfer_not_pending -> 26l
  | Pending_transfer_has_different_debit_account_id -> 27l
  | Pending_transfer_has_different_credit_account_id -> 28l
  | Pending_transfer_has_different_ledger -> 29l
  | Pending_transfer_has_different_code -> 30l
  | Exceeds_pending_transfer_amount -> 31l
  | Pending_transfer_has_different_amount -> 32l
  | Pending_transfer_already_posted -> 33l
  | Pending_transfer_already_voided -> 34l
  | Pending_transfer_expired -> 35l
  | Exists_with_different_flags -> 36l
  | Exists_with_different_debit_account_id -> 37l
  | Exists_with_different_credit_account_id -> 38l
  | Exists_with_different_amount -> 39l
  | Exists_with_different_pending_id -> 40l
  | Exists_with_different_user_data_128 -> 41l
  | Exists_with_different_user_data_64 -> 42l
  | Exists_with_different_user_data_32 -> 43l
  | Exists_with_different_timeout -> 44l
  | Exists_with_different_code -> 45l
  | Exists -> 46l
  | Overflows_debits_pending -> 47l
  | Overflows_credits_pending -> 48l
  | Overflows_debits_posted -> 49l
  | Overflows_credits_posted -> 50l
  | Overflows_debits -> 51l
  | Overflows_credits -> 52l
  | Overflows_timeout -> 53l
  | Exceeds_credits -> 54l
  | Exceeds_debits -> 55l
  | Imported_event_expected -> 56l
  | Imported_event_not_expected -> 57l
  | Imported_event_timestamp_out_of_range -> 58l
  | Imported_event_timestamp_must_not_advance -> 59l
  | Imported_event_timestamp_must_not_regress -> 60l
  | Imported_event_timestamp_must_postdate_debit_account -> 61l
  | Imported_event_timestamp_must_postdate_credit_account -> 62l
  | Imported_event_timeout_must_be_zero -> 63l
  | Closing_transfer_must_be_pending -> 64l
  | Debit_account_already_closed -> 65l
  | Credit_account_already_closed -> 66l
  | Exists_with_different_ledger -> 67l
  | Id_already_failed -> 68l

let create_transfer_result_of_u32 = function
  | 0l -> Some Ok
  | 1l -> Some Linked_event_failed
  | 2l -> Some Linked_event_chain_open
  | 3l -> Some Timestamp_must_be_zero
  | 4l -> Some Reserved_flag
  | 5l -> Some Id_must_not_be_zero
  | 6l -> Some Id_must_not_be_int_max
  | 7l -> Some Flags_are_mutually_exclusive
  | 8l -> Some Debit_account_id_must_not_be_zero
  | 9l -> Some Debit_account_id_must_not_be_int_max
  | 10l -> Some Credit_account_id_must_not_be_zero
  | 11l -> Some Credit_account_id_must_not_be_int_max
  | 12l -> Some Accounts_must_be_different
  | 13l -> Some Pending_id_must_be_zero
  | 14l -> Some Pending_id_must_not_be_zero
  | 15l -> Some Pending_id_must_not_be_int_max
  | 16l -> Some Pending_id_must_be_different
  | 17l -> Some Timeout_reserved_for_pending_transfer
  | 18l -> Some Deprecated_18
  | 19l -> Some Ledger_must_not_be_zero
  | 20l -> Some Code_must_not_be_zero
  | 21l -> Some Debit_account_not_found
  | 22l -> Some Credit_account_not_found
  | 23l -> Some Accounts_must_have_the_same_ledger
  | 24l -> Some Transfer_must_have_the_same_ledger_as_accounts
  | 25l -> Some Pending_transfer_not_found
  | 26l -> Some Pending_transfer_not_pending
  | 27l -> Some Pending_transfer_has_different_debit_account_id
  | 28l -> Some Pending_transfer_has_different_credit_account_id
  | 29l -> Some Pending_transfer_has_different_ledger
  | 30l -> Some Pending_transfer_has_different_code
  | 31l -> Some Exceeds_pending_transfer_amount
  | 32l -> Some Pending_transfer_has_different_amount
  | 33l -> Some Pending_transfer_already_posted
  | 34l -> Some Pending_transfer_already_voided
  | 35l -> Some Pending_transfer_expired
  | 36l -> Some Exists_with_different_flags
  | 37l -> Some Exists_with_different_debit_account_id
  | 38l -> Some Exists_with_different_credit_account_id
  | 39l -> Some Exists_with_different_amount
  | 40l -> Some Exists_with_different_pending_id
  | 41l -> Some Exists_with_different_user_data_128
  | 42l -> Some Exists_with_different_user_data_64
  | 43l -> Some Exists_with_different_user_data_32
  | 44l -> Some Exists_with_different_timeout
  | 45l -> Some Exists_with_different_code
  | 46l -> Some Exists
  | 47l -> Some Overflows_debits_pending
  | 48l -> Some Overflows_credits_pending
  | 49l -> Some Overflows_debits_posted
  | 50l -> Some Overflows_credits_posted
  | 51l -> Some Overflows_debits
  | 52l -> Some Overflows_credits
  | 53l -> Some Overflows_timeout
  | 54l -> Some Exceeds_credits
  | 55l -> Some Exceeds_debits
  | 56l -> Some Imported_event_expected
  | 57l -> Some Imported_event_not_expected
  | 58l -> Some Imported_event_timestamp_out_of_range
  | 59l -> Some Imported_event_timestamp_must_not_advance
  | 60l -> Some Imported_event_timestamp_must_not_regress
  | 61l -> Some Imported_event_timestamp_must_postdate_debit_account
  | 62l -> Some Imported_event_timestamp_must_postdate_credit_account
  | 63l -> Some Imported_event_timeout_must_be_zero
  | 64l -> Some Closing_transfer_must_be_pending
  | 65l -> Some Debit_account_already_closed
  | 66l -> Some Credit_account_already_closed
  | 67l -> Some Exists_with_different_ledger
  | 68l -> Some Id_already_failed
  | _ -> None

let create_transfer_result_to_string = function
  | Ok -> "ok"
  | Linked_event_failed -> "linked_event_failed"
  | Linked_event_chain_open -> "linked_event_chain_open"
  | Timestamp_must_be_zero -> "timestamp_must_be_zero"
  | Reserved_flag -> "reserved_flag"
  | Id_must_not_be_zero -> "id_must_not_be_zero"
  | Id_must_not_be_int_max -> "id_must_not_be_int_max"
  | Flags_are_mutually_exclusive -> "flags_are_mutually_exclusive"
  | Debit_account_id_must_not_be_zero -> "debit_account_id_must_not_be_zero"
  | Debit_account_id_must_not_be_int_max ->
      "debit_account_id_must_not_be_int_max"
  | Credit_account_id_must_not_be_zero -> "credit_account_id_must_not_be_zero"
  | Credit_account_id_must_not_be_int_max ->
      "credit_account_id_must_not_be_int_max"
  | Accounts_must_be_different -> "accounts_must_be_different"
  | Pending_id_must_be_zero -> "pending_id_must_be_zero"
  | Pending_id_must_not_be_zero -> "pending_id_must_not_be_zero"
  | Pending_id_must_not_be_int_max -> "pending_id_must_not_be_int_max"
  | Pending_id_must_be_different -> "pending_id_must_be_different"
  | Timeout_reserved_for_pending_transfer ->
      "timeout_reserved_for_pending_transfer"
  | Deprecated_18 -> "deprecated_18"
  | Ledger_must_not_be_zero -> "ledger_must_not_be_zero"
  | Code_must_not_be_zero -> "code_must_not_be_zero"
  | Debit_account_not_found -> "debit_account_not_found"
  | Credit_account_not_found -> "credit_account_not_found"
  | Accounts_must_have_the_same_ledger -> "accounts_must_have_the_same_ledger"
  | Transfer_must_have_the_same_ledger_as_accounts ->
      "transfer_must_have_the_same_ledger_as_accounts"
  | Pending_transfer_not_found -> "pending_transfer_not_found"
  | Pending_transfer_not_pending -> "pending_transfer_not_pending"
  | Pending_transfer_has_different_debit_account_id ->
      "pending_transfer_has_different_debit_account_id"
  | Pending_transfer_has_different_credit_account_id ->
      "pending_transfer_has_different_credit_account_id"
  | Pending_transfer_has_different_ledger ->
      "pending_transfer_has_different_ledger"
  | Pending_transfer_has_different_code -> "pending_transfer_has_different_code"
  | Exceeds_pending_transfer_amount -> "exceeds_pending_transfer_amount"
  | Pending_transfer_has_different_amount ->
      "pending_transfer_has_different_amount"
  | Pending_transfer_already_posted -> "pending_transfer_already_posted"
  | Pending_transfer_already_voided -> "pending_transfer_already_voided"
  | Pending_transfer_expired -> "pending_transfer_expired"
  | Exists_with_different_flags -> "exists_with_different_flags"
  | Exists_with_different_debit_account_id ->
      "exists_with_different_debit_account_id"
  | Exists_with_different_credit_account_id ->
      "exists_with_different_credit_account_id"
  | Exists_with_different_amount -> "exists_with_different_amount"
  | Exists_with_different_pending_id -> "exists_with_different_pending_id"
  | Exists_with_different_user_data_128 -> "exists_with_different_user_data_128"
  | Exists_with_different_user_data_64 -> "exists_with_different_user_data_64"
  | Exists_with_different_user_data_32 -> "exists_with_different_user_data_32"
  | Exists_with_different_timeout -> "exists_with_different_timeout"
  | Exists_with_different_code -> "exists_with_different_code"
  | Exists -> "exists"
  | Overflows_debits_pending -> "overflows_debits_pending"
  | Overflows_credits_pending -> "overflows_credits_pending"
  | Overflows_debits_posted -> "overflows_debits_posted"
  | Overflows_credits_posted -> "overflows_credits_posted"
  | Overflows_debits -> "overflows_debits"
  | Overflows_credits -> "overflows_credits"
  | Overflows_timeout -> "overflows_timeout"
  | Exceeds_credits -> "exceeds_credits"
  | Exceeds_debits -> "exceeds_debits"
  | Imported_event_expected -> "imported_event_expected"
  | Imported_event_not_expected -> "imported_event_not_expected"
  | Imported_event_timestamp_out_of_range ->
      "imported_event_timestamp_out_of_range"
  | Imported_event_timestamp_must_not_advance ->
      "imported_event_timestamp_must_not_advance"
  | Imported_event_timestamp_must_not_regress ->
      "imported_event_timestamp_must_not_regress"
  | Imported_event_timestamp_must_postdate_debit_account ->
      "imported_event_timestamp_must_postdate_debit_account"
  | Imported_event_timestamp_must_postdate_credit_account ->
      "imported_event_timestamp_must_postdate_credit_account"
  | Imported_event_timeout_must_be_zero -> "imported_event_timeout_must_be_zero"
  | Closing_transfer_must_be_pending -> "closing_transfer_must_be_pending"
  | Debit_account_already_closed -> "debit_account_already_closed"
  | Credit_account_already_closed -> "credit_account_already_closed"
  | Exists_with_different_ledger -> "exists_with_different_ledger"
  | Id_already_failed -> "id_already_failed"

let create_account_result_to_int r = Int32.to_int (create_account_result_to_u32 r)
let create_account_result_of_int i = create_account_result_of_u32 (Int32.of_int i)
let create_transfer_result_to_int r = Int32.to_int (create_transfer_result_to_u32 r)
let create_transfer_result_of_int i = create_transfer_result_of_u32 (Int32.of_int i)
