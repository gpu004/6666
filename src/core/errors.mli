(** Error and result codes for TigerOCaml operations. *)

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

val create_account_result_to_u32 : create_account_result -> int32
val create_account_result_of_u32 : int32 -> create_account_result option
val create_account_result_to_string : create_account_result -> string

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

val create_transfer_result_to_u32 : create_transfer_result -> int32
val create_transfer_result_of_u32 : int32 -> create_transfer_result option
val create_transfer_result_to_string : create_transfer_result -> string

(* Compatibility aliases used by older tests/modules. *)
val create_account_result_to_int : create_account_result -> int
val create_account_result_of_int : int -> create_account_result option
val create_transfer_result_to_int : create_transfer_result -> int
val create_transfer_result_of_int : int -> create_transfer_result option
