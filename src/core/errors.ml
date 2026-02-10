(* errors.ml — Result codes for TigerOCaml operations *)

(* --- Create account results ---------------------------------------------- *)

type create_account_result =
  | Ok
  | Exists
  | Exists_with_different_flags
  | Exists_with_different_user_data_128
  | Exists_with_different_user_data_64
  | Exists_with_different_user_data_32
  | Exists_with_different_ledger
  | Exists_with_different_code
  | Id_must_not_be_zero
  | Id_must_not_be_max
  | Ledger_must_not_be_zero
  | Code_must_not_be_zero
  | Reserved_must_be_zero
  | Debits_pending_must_be_zero
  | Debits_posted_must_be_zero
  | Credits_pending_must_be_zero
  | Credits_posted_must_be_zero
  | Mutually_exclusive_flags
  | Timestamp_must_be_zero
  | Imported_must_not_set_timestamp_to_zero
  | Closed_must_have_balance_constraint

let create_account_result_to_int = function
  | Ok -> 0
  | Exists -> 1
  | Exists_with_different_flags -> 2
  | Exists_with_different_user_data_128 -> 3
  | Exists_with_different_user_data_64 -> 4
  | Exists_with_different_user_data_32 -> 5
  | Exists_with_different_ledger -> 6
  | Exists_with_different_code -> 7
  | Id_must_not_be_zero -> 8
  | Id_must_not_be_max -> 9
  | Ledger_must_not_be_zero -> 10
  | Code_must_not_be_zero -> 11
  | Reserved_must_be_zero -> 12
  | Debits_pending_must_be_zero -> 13
  | Debits_posted_must_be_zero -> 14
  | Credits_pending_must_be_zero -> 15
  | Credits_posted_must_be_zero -> 16
  | Mutually_exclusive_flags -> 17
  | Timestamp_must_be_zero -> 18
  | Imported_must_not_set_timestamp_to_zero -> 19
  | Closed_must_have_balance_constraint -> 20

let create_account_result_of_int = function
  | 0 -> Some Ok
  | 1 -> Some Exists
  | 2 -> Some Exists_with_different_flags
  | 3 -> Some Exists_with_different_user_data_128
  | 4 -> Some Exists_with_different_user_data_64
  | 5 -> Some Exists_with_different_user_data_32
  | 6 -> Some Exists_with_different_ledger
  | 7 -> Some Exists_with_different_code
  | 8 -> Some Id_must_not_be_zero
  | 9 -> Some Id_must_not_be_max
  | 10 -> Some Ledger_must_not_be_zero
  | 11 -> Some Code_must_not_be_zero
  | 12 -> Some Reserved_must_be_zero
  | 13 -> Some Debits_pending_must_be_zero
  | 14 -> Some Debits_posted_must_be_zero
  | 15 -> Some Credits_pending_must_be_zero
  | 16 -> Some Credits_posted_must_be_zero
  | 17 -> Some Mutually_exclusive_flags
  | 18 -> Some Timestamp_must_be_zero
  | 19 -> Some Imported_must_not_set_timestamp_to_zero
  | 20 -> Some Closed_must_have_balance_constraint
  | _ -> None

let create_account_result_to_string = function
  | Ok -> "ok"
  | Exists -> "exists"
  | Exists_with_different_flags -> "exists_with_different_flags"
  | Exists_with_different_user_data_128 -> "exists_with_different_user_data_128"
  | Exists_with_different_user_data_64 -> "exists_with_different_user_data_64"
  | Exists_with_different_user_data_32 -> "exists_with_different_user_data_32"
  | Exists_with_different_ledger -> "exists_with_different_ledger"
  | Exists_with_different_code -> "exists_with_different_code"
  | Id_must_not_be_zero -> "id_must_not_be_zero"
  | Id_must_not_be_max -> "id_must_not_be_max"
  | Ledger_must_not_be_zero -> "ledger_must_not_be_zero"
  | Code_must_not_be_zero -> "code_must_not_be_zero"
  | Reserved_must_be_zero -> "reserved_must_be_zero"
  | Debits_pending_must_be_zero -> "debits_pending_must_be_zero"
  | Debits_posted_must_be_zero -> "debits_posted_must_be_zero"
  | Credits_pending_must_be_zero -> "credits_pending_must_be_zero"
  | Credits_posted_must_be_zero -> "credits_posted_must_be_zero"
  | Mutually_exclusive_flags -> "mutually_exclusive_flags"
  | Timestamp_must_be_zero -> "timestamp_must_be_zero"
  | Imported_must_not_set_timestamp_to_zero ->
      "imported_must_not_set_timestamp_to_zero"
  | Closed_must_have_balance_constraint ->
      "closed_must_have_balance_constraint"

(* --- Create transfer results --------------------------------------------- *)

type create_transfer_result =
  | Ok
  | Exists
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
  | Id_must_not_be_zero
  | Id_must_not_be_max
  | Debit_account_id_must_not_be_zero
  | Credit_account_id_must_not_be_zero
  | Accounts_must_be_different
  | Debit_account_not_found
  | Credit_account_not_found
  | Ledger_must_not_be_zero
  | Code_must_not_be_zero
  | Amount_must_not_be_zero
  | Ledger_must_match_debit_account
  | Ledger_must_match_credit_account
  | Pending_id_must_be_zero
  | Pending_transfer_not_found
  | Pending_transfer_already_resolved
  | Timeout_reserved_for_pending
  | Mutually_exclusive_flags
  | Insufficient_debit_balance
  | Insufficient_credit_balance
  | Exceeds_credits
  | Exceeds_debits
  | Debit_account_closed
  | Credit_account_closed
  | Linked_event_failed
  | Timestamp_must_be_zero
  | Imported_must_not_set_timestamp_to_zero

let create_transfer_result_to_int = function
  | Ok -> 0
  | Exists -> 1
  | Exists_with_different_flags -> 2
  | Exists_with_different_debit_account_id -> 3
  | Exists_with_different_credit_account_id -> 4
  | Exists_with_different_amount -> 5
  | Exists_with_different_pending_id -> 6
  | Exists_with_different_user_data_128 -> 7
  | Exists_with_different_user_data_64 -> 8
  | Exists_with_different_user_data_32 -> 9
  | Exists_with_different_timeout -> 10
  | Exists_with_different_code -> 11
  | Id_must_not_be_zero -> 12
  | Id_must_not_be_max -> 13
  | Debit_account_id_must_not_be_zero -> 14
  | Credit_account_id_must_not_be_zero -> 15
  | Accounts_must_be_different -> 16
  | Debit_account_not_found -> 17
  | Credit_account_not_found -> 18
  | Ledger_must_not_be_zero -> 19
  | Code_must_not_be_zero -> 20
  | Amount_must_not_be_zero -> 21
  | Ledger_must_match_debit_account -> 22
  | Ledger_must_match_credit_account -> 23
  | Pending_id_must_be_zero -> 24
  | Pending_transfer_not_found -> 25
  | Pending_transfer_already_resolved -> 26
  | Timeout_reserved_for_pending -> 27
  | Mutually_exclusive_flags -> 28
  | Insufficient_debit_balance -> 29
  | Insufficient_credit_balance -> 30
  | Exceeds_credits -> 31
  | Exceeds_debits -> 32
  | Debit_account_closed -> 33
  | Credit_account_closed -> 34
  | Linked_event_failed -> 35
  | Timestamp_must_be_zero -> 36
  | Imported_must_not_set_timestamp_to_zero -> 37

let create_transfer_result_of_int = function
  | 0 -> Some Ok
  | 1 -> Some Exists
  | 2 -> Some Exists_with_different_flags
  | 3 -> Some Exists_with_different_debit_account_id
  | 4 -> Some Exists_with_different_credit_account_id
  | 5 -> Some Exists_with_different_amount
  | 6 -> Some Exists_with_different_pending_id
  | 7 -> Some Exists_with_different_user_data_128
  | 8 -> Some Exists_with_different_user_data_64
  | 9 -> Some Exists_with_different_user_data_32
  | 10 -> Some Exists_with_different_timeout
  | 11 -> Some Exists_with_different_code
  | 12 -> Some Id_must_not_be_zero
  | 13 -> Some Id_must_not_be_max
  | 14 -> Some Debit_account_id_must_not_be_zero
  | 15 -> Some Credit_account_id_must_not_be_zero
  | 16 -> Some Accounts_must_be_different
  | 17 -> Some Debit_account_not_found
  | 18 -> Some Credit_account_not_found
  | 19 -> Some Ledger_must_not_be_zero
  | 20 -> Some Code_must_not_be_zero
  | 21 -> Some Amount_must_not_be_zero
  | 22 -> Some Ledger_must_match_debit_account
  | 23 -> Some Ledger_must_match_credit_account
  | 24 -> Some Pending_id_must_be_zero
  | 25 -> Some Pending_transfer_not_found
  | 26 -> Some Pending_transfer_already_resolved
  | 27 -> Some Timeout_reserved_for_pending
  | 28 -> Some Mutually_exclusive_flags
  | 29 -> Some Insufficient_debit_balance
  | 30 -> Some Insufficient_credit_balance
  | 31 -> Some Exceeds_credits
  | 32 -> Some Exceeds_debits
  | 33 -> Some Debit_account_closed
  | 34 -> Some Credit_account_closed
  | 35 -> Some Linked_event_failed
  | 36 -> Some Timestamp_must_be_zero
  | 37 -> Some Imported_must_not_set_timestamp_to_zero
  | _ -> None

let create_transfer_result_to_string = function
  | Ok -> "ok"
  | Exists -> "exists"
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
  | Id_must_not_be_zero -> "id_must_not_be_zero"
  | Id_must_not_be_max -> "id_must_not_be_max"
  | Debit_account_id_must_not_be_zero -> "debit_account_id_must_not_be_zero"
  | Credit_account_id_must_not_be_zero -> "credit_account_id_must_not_be_zero"
  | Accounts_must_be_different -> "accounts_must_be_different"
  | Debit_account_not_found -> "debit_account_not_found"
  | Credit_account_not_found -> "credit_account_not_found"
  | Ledger_must_not_be_zero -> "ledger_must_not_be_zero"
  | Code_must_not_be_zero -> "code_must_not_be_zero"
  | Amount_must_not_be_zero -> "amount_must_not_be_zero"
  | Ledger_must_match_debit_account -> "ledger_must_match_debit_account"
  | Ledger_must_match_credit_account -> "ledger_must_match_credit_account"
  | Pending_id_must_be_zero -> "pending_id_must_be_zero"
  | Pending_transfer_not_found -> "pending_transfer_not_found"
  | Pending_transfer_already_resolved -> "pending_transfer_already_resolved"
  | Timeout_reserved_for_pending -> "timeout_reserved_for_pending"
  | Mutually_exclusive_flags -> "mutually_exclusive_flags"
  | Insufficient_debit_balance -> "insufficient_debit_balance"
  | Insufficient_credit_balance -> "insufficient_credit_balance"
  | Exceeds_credits -> "exceeds_credits"
  | Exceeds_debits -> "exceeds_debits"
  | Debit_account_closed -> "debit_account_closed"
  | Credit_account_closed -> "credit_account_closed"
  | Linked_event_failed -> "linked_event_failed"
  | Timestamp_must_be_zero -> "timestamp_must_be_zero"
  | Imported_must_not_set_timestamp_to_zero ->
      "imported_must_not_set_timestamp_to_zero"
