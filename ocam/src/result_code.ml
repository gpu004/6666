open Types

let created_code = 0xffff_ffff

type 'status mapping =
  | Exact of 'status * int
  | Coarse of 'status * int list

let account_mappings : create_account_status mapping list =
  [ Exact (Account_created, created_code)
  ; Exact (Account_linked_event_failed, 1)
  ; Exact (Account_linked_event_chain_open, 2)
  ; Exact (Account_timestamp_must_be_zero, 3)
  ; Exact (Account_id_must_not_be_zero, 6)
  ; Exact (Account_id_must_not_be_int_max, 7)
  ; Exact (Account_flags_are_mutually_exclusive, 8)
  ; Exact (Account_debits_pending_must_be_zero, 9)
  ; Exact (Account_debits_posted_must_be_zero, 10)
  ; Exact (Account_credits_pending_must_be_zero, 11)
  ; Exact (Account_credits_posted_must_be_zero, 12)
  ; Exact (Account_ledger_must_not_be_zero, 13)
  ; Exact (Account_code_must_not_be_zero, 14)
  ; Exact (Account_exists_with_different_flags, 15)
  ; Exact (Account_exists_with_different_user_data_128, 16)
  ; Exact (Account_exists_with_different_user_data_64, 17)
  ; Exact (Account_exists_with_different_user_data_32, 18)
  ; Exact (Account_exists_with_different_ledger, 19)
  ; Exact (Account_exists_with_different_code, 20)
  ; Exact (Account_exists, 21)
  ; Exact (Account_imported_event_expected, 22)
  ; Exact (Account_imported_event_not_expected, 23)
  ; Exact (Account_imported_timestamp_out_of_range, 24)
  ; Exact (Account_imported_timestamp_must_not_advance, 25)
  ; Exact (Account_imported_timestamp_must_not_regress, 26)
  ]
;;

let transfer_mappings : create_transfer_status mapping list =
  [ Exact (Transfer_created, created_code)
  ; Exact (Transfer_linked_event_failed, 1)
  ; Exact (Transfer_linked_event_chain_open, 2)
  ; Exact (Transfer_timestamp_must_be_zero, 3)
  ; Exact (Transfer_id_must_not_be_zero, 5)
  ; Exact (Transfer_id_must_not_be_int_max, 6)
  ; Exact (Transfer_flags_are_mutually_exclusive, 7)
  ; Exact (Transfer_debit_account_id_must_not_be_zero, 8)
  ; Exact (Transfer_debit_account_id_must_not_be_int_max, 9)
  ; Exact (Transfer_credit_account_id_must_not_be_zero, 10)
  ; Exact (Transfer_credit_account_id_must_not_be_int_max, 11)
  ; Exact (Transfer_accounts_must_be_different, 12)
  ; Exact (Transfer_pending_id_must_be_zero, 13)
  ; Exact (Transfer_pending_id_must_not_be_zero, 14)
  ; Exact (Transfer_pending_id_must_not_be_int_max, 15)
  ; Exact (Transfer_pending_id_must_be_different, 16)
  ; Exact (Transfer_timeout_reserved_for_pending_transfer, 17)
  ; Exact (Transfer_ledger_must_not_be_zero, 19)
  ; Exact (Transfer_code_must_not_be_zero, 20)
  ; Exact (Transfer_debit_account_not_found, 21)
  ; Exact (Transfer_credit_account_not_found, 22)
  ; Exact (Transfer_accounts_must_have_same_ledger, 23)
  ; Exact (Transfer_must_have_same_ledger_as_accounts, 24)
  ; Exact (Transfer_pending_transfer_not_found, 25)
  ; Exact (Transfer_pending_transfer_not_pending, 26)
  ; Coarse (Transfer_pending_transfer_has_different_accounts, [ 27; 28 ])
  ; Exact (Transfer_pending_transfer_has_different_ledger, 29)
  ; Exact (Transfer_pending_transfer_has_different_code, 30)
  ; Exact (Transfer_exceeds_pending_transfer_amount, 31)
  ; Exact (Transfer_pending_transfer_has_different_amount, 32)
  ; Exact (Transfer_pending_transfer_already_posted, 33)
  ; Exact (Transfer_pending_transfer_already_voided, 34)
  ; Exact (Transfer_pending_transfer_expired, 35)
  ; Coarse (Transfer_exists_with_different_request, [ 36; 37; 38; 39; 40; 44; 45; 67 ])
  ; Exact (Transfer_exists, 46)
  ; Coarse (Transfer_overflows_balance, [ 47; 48; 49; 50; 51; 52 ])
  ; Exact (Transfer_overflows_timeout, 53)
  ; Exact (Transfer_exceeds_credits, 54)
  ; Exact (Transfer_exceeds_debits, 55)
  ; Exact (Transfer_imported_event_expected, 56)
  ; Exact (Transfer_imported_event_not_expected, 57)
  ; Exact (Transfer_imported_timestamp_out_of_range, 58)
  ; Exact (Transfer_imported_timestamp_must_not_advance, 59)
  ; Exact (Transfer_imported_timestamp_must_not_regress, 60)
  ; Exact (Transfer_imported_timeout_must_be_zero, 63)
  ; Exact (Transfer_closing_transfer_must_be_pending, 64)
  ; Coarse (Transfer_account_already_closed, [ 65; 66 ])
  ; Exact (Transfer_id_already_failed, 68)
  ]
;;

let codes_of_mapping = function
  | Exact (_, code) -> [ code ]
  | Coarse (_, codes) -> codes
;;

let status_of_mapping = function
  | Exact (status, _) | Coarse (status, _) -> status
;;

let lookup_status mappings status =
  List.find (fun mapping -> status_of_mapping mapping = status) mappings
;;

let to_code_of mappings status =
  match lookup_status mappings status with
  | Exact (_, code) -> Some code
  | Coarse _ -> None
;;

let codes_of mappings status = codes_of_mapping (lookup_status mappings status)

let of_code_of mappings code =
  List.find_map
    (fun mapping ->
      if List.mem code (codes_of_mapping mapping)
      then Some (status_of_mapping mapping)
      else None)
    mappings
;;

let account_to_code = to_code_of account_mappings
let account_codes = codes_of account_mappings
let account_of_code = of_code_of account_mappings
let transfer_to_code = to_code_of transfer_mappings
let transfer_codes = codes_of transfer_mappings
let transfer_of_code = of_code_of transfer_mappings
let account_statuses = List.map status_of_mapping account_mappings
let transfer_statuses = List.map status_of_mapping transfer_mappings

let transfer_status_transient = function
  | Transfer_debit_account_not_found
  | Transfer_credit_account_not_found
  | Transfer_pending_transfer_not_found
  | Transfer_account_already_closed
  | Transfer_exceeds_credits
  | Transfer_exceeds_debits -> true
  | _ -> false
;;
