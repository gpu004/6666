(** Error and result codes for TigerOCaml operations.

    Each variant maps to a stable integer code for the wire format. *)

(** {1 Create account results} *)

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

val create_account_result_to_int : create_account_result -> int
val create_account_result_of_int : int -> create_account_result option
val create_account_result_to_string : create_account_result -> string

(** {1 Create transfer results} *)

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

val create_transfer_result_to_int : create_transfer_result -> int
val create_transfer_result_of_int : int -> create_transfer_result option
val create_transfer_result_to_string : create_transfer_result -> string
