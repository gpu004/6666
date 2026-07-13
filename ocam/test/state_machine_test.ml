open Tigerbeetle_state_machine.State_machine

let u128 = U128.of_int

let account_flags ?(linked = false) () =
  { linked
  ; debits_must_not_exceed_credits = false
  ; credits_must_not_exceed_debits = false
  ; history = true
  ; imported = false
  ; closed = false
  }
;;

let transfer_flags
      ?(linked = false)
      ?(pending = false)
      ?(post_pending_transfer = false)
      ?(void_pending_transfer = false)
      ()
  =
  { linked
  ; pending
  ; post_pending_transfer
  ; void_pending_transfer
  ; balancing_debit = false
  ; balancing_credit = false
  ; closing_debit = false
  ; closing_credit = false
  ; imported = false
  }
;;

let account ?(linked = false) id =
  { id = u128 id
  ; debits_pending = U128.zero
  ; debits_posted = U128.zero
  ; credits_pending = U128.zero
  ; credits_posted = U128.zero
  ; user_data_128 = U128.zero
  ; user_data_64 = 0L
  ; user_data_32 = 0l
  ; ledger = 1l
  ; code = 1
  ; flags = account_flags ~linked ()
  ; timestamp = 0L
  }
;;

let transfer ?(flags = transfer_flags ()) ?(pending_id = U128.zero) ?(amount = 10) id =
  { id = u128 id
  ; debit_account_id = u128 1
  ; credit_account_id = u128 2
  ; amount = u128 amount
  ; pending_id
  ; user_data_128 = U128.zero
  ; user_data_64 = 0L
  ; user_data_32 = 0l
  ; timeout = 0l
  ; ledger = 1l
  ; code = 1
  ; flags
  ; timestamp = 0L
  }
;;

let require condition message = if not condition then failwith message

let require_u128 expected actual message =
  require (U128.equal (u128 expected) actual) message
;;

let account_of state id =
  match lookup_accounts state [ u128 id ] with
  | [ account ] -> account
  | _ -> failwith "account lookup did not return exactly one account"
;;

let test_single_phase () =
  let state = empty () in
  let account_results = create_accounts state ~timestamp:1L [ account 1; account 2 ] in
  require
    (List.for_all (fun result -> result.status = Account_created) account_results)
    "accounts should be created";
  let result = List.hd (create_transfers state ~timestamp:3L [ transfer 10 ]) in
  require (result.status = Transfer_created) "transfer should be created";
  require_u128 10 (account_of state 1).debits_posted "debit posted mismatch";
  require_u128 10 (account_of state 2).credits_posted "credit posted mismatch"
;;

let test_pending_post_and_void () =
  let state = empty () in
  ignore (create_accounts state ~timestamp:1L [ account 1; account 2 ]);
  let pending = transfer ~flags:(transfer_flags ~pending:true ()) 20 in
  let pending_result = List.hd (create_transfers state ~timestamp:3L [ pending ]) in
  require (pending_result.status = Transfer_created) "pending transfer should be created";
  require_u128 10 (account_of state 1).debits_pending "debit pending mismatch";
  let post =
    transfer
      ~flags:(transfer_flags ~post_pending_transfer:true ())
      ~pending_id:(u128 20)
      ~amount:6
      21
  in
  let post_result = List.hd (create_transfers state ~timestamp:4L [ post ]) in
  require (post_result.status = Transfer_created) "post should be created";
  require_u128 0 (account_of state 1).debits_pending "pending debit should clear";
  require_u128 6 (account_of state 1).debits_posted "posted debit mismatch";
  let pending2 = transfer ~flags:(transfer_flags ~pending:true ()) 30 in
  ignore (create_transfers state ~timestamp:5L [ pending2 ]);
  let void =
    transfer
      ~flags:(transfer_flags ~void_pending_transfer:true ())
      ~pending_id:(u128 30)
      ~amount:0
      31
  in
  let void_result = List.hd (create_transfers state ~timestamp:6L [ void ]) in
  require (void_result.status = Transfer_created) "void should be created";
  require_u128 0 (account_of state 1).debits_pending "void should clear pending debit"
;;

let test_linked_rollback () =
  let state = empty () in
  let results =
    create_accounts state ~timestamp:1L [ account ~linked:true 1; account 0 ]
  in
  require
    ((List.hd results).status = Account_linked_event_failed)
    "successful linked prefix must be rolled back";
  require (lookup_accounts state [ u128 1 ] = []) "rolled-back account remains visible"
;;

let test_zig_validation_precedence () =
  (* Mirrors the pinned Zig create_account/create_transfer validation ordering. *)
  let state = empty () in
  let result = List.hd (create_accounts state ~timestamp:1L [ account 0 ]) in
  require (result.status = Account_id_must_not_be_zero) "Zig precedence: account id zero";
  let result = List.hd (create_transfers state ~timestamp:2L [ transfer 1 ]) in
  require
    (result.status = Transfer_debit_account_not_found)
    "Zig precedence: missing debit before missing credit"
;;

let () =
  test_single_phase ();
  test_pending_post_and_void ();
  test_linked_rollback ();
  test_zig_validation_precedence ();
  print_endline "state_machine equivalence scenarios: ok"
;;
