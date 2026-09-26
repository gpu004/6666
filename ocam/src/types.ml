(** Wire-level record and status types shared by the ledger core. *)

type account_flags =
  { linked : bool
  ; debits_must_not_exceed_credits : bool
  ; credits_must_not_exceed_debits : bool
  ; history : bool
  ; imported : bool
  ; closed : bool
  }

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
  | Account_imported_event_expected
  | Account_imported_event_not_expected
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
  | Account_imported_timestamp_must_not_advance
  | Account_imported_timestamp_must_not_regress

type create_transfer_status =
  | Transfer_created
  | Transfer_exists
  | Transfer_linked_event_failed
  | Transfer_linked_event_chain_open
  | Transfer_imported_event_expected
  | Transfer_imported_event_not_expected
  | Transfer_timestamp_must_be_zero
  | Transfer_id_must_not_be_zero
  | Transfer_id_must_not_be_int_max
  | Transfer_id_already_failed
  | Transfer_exists_with_different_request
  | Transfer_flags_are_mutually_exclusive
  | Transfer_debit_account_id_must_not_be_zero
  | Transfer_debit_account_id_must_not_be_int_max
  | Transfer_credit_account_id_must_not_be_zero
  | Transfer_credit_account_id_must_not_be_int_max
  | Transfer_accounts_must_be_different
  | Transfer_pending_id_must_be_zero
  | Transfer_pending_id_must_not_be_zero
  | Transfer_pending_id_must_not_be_int_max
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
  | Transfer_imported_timestamp_must_not_advance
  | Transfer_imported_timestamp_must_not_regress
  | Transfer_imported_timeout_must_be_zero

type 'status create_result =
  { timestamp : int64
  ; status : 'status
  }

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
