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
      ?(closing_debit = false)
      ?(closing_credit = false)
      ?(imported = false)
      ()
  =
  { linked
  ; pending
  ; post_pending_transfer
  ; void_pending_transfer
  ; balancing_debit = false
  ; balancing_credit = false
  ; closing_debit
  ; closing_credit
  ; imported
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

let transfer
      ?(flags = transfer_flags ())
      ?(pending_id = U128.zero)
      ?(amount = 10)
      ?(timeout = 0l)
      ?(timestamp = 0L)
      id
  =
  { id = u128 id
  ; debit_account_id = u128 1
  ; credit_account_id = u128 2
  ; amount = u128 amount
  ; pending_id
  ; user_data_128 = U128.zero
  ; user_data_64 = 0L
  ; user_data_32 = 0l
  ; timeout
  ; ledger = 1l
  ; code = 1
  ; flags
  ; timestamp
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

let test_open_linked_suffix () =
  let account_state = empty () in
  let account_results =
    create_accounts
      account_state
      ~timestamp:1L
      [ account 1; account ~linked:true 2; account ~linked:true 3 ]
  in
  require
    (List.map (fun result -> result.status) account_results
     = [ Account_created; Account_linked_event_failed; Account_linked_event_chain_open ])
    "only the trailing open account chain should fail";
  require
    (List.length (lookup_accounts account_state [ u128 1; u128 2; u128 3 ]) = 1)
    "the complete account prefix should remain committed";
  let transfer_state = empty () in
  ignore (create_accounts transfer_state ~timestamp:1L [ account 1; account 2 ]);
  let transfer_results =
    create_transfers
      transfer_state
      ~timestamp:3L
      [ transfer 10
      ; transfer ~flags:(transfer_flags ~linked:true ()) 11
      ; transfer ~flags:(transfer_flags ~linked:true ()) 12
      ]
  in
  require
    (List.map (fun result -> result.status) transfer_results
     = [ Transfer_created
       ; Transfer_linked_event_failed
       ; Transfer_linked_event_chain_open
       ])
    "only the trailing open transfer chain should fail";
  require_u128 10 (account_of transfer_state 1).debits_posted "complete transfer lost"
;;

let test_timeout_validation_and_closing_expiry () =
  let overflow_state = empty () in
  ignore (create_accounts overflow_state ~timestamp:1L [ account 1; account 2 ]);
  let overflow =
    List.hd
      (create_transfers
         overflow_state
         ~timestamp:(Int64.sub Int64.max_int 500_000_000L)
         [ transfer ~flags:(transfer_flags ~pending:true ()) ~timeout:1l 10 ])
  in
  require
    (overflow.status = Transfer_overflows_timeout)
    "pending timeout overflow should be rejected";
  let imported_state = empty () in
  ignore (create_accounts imported_state ~timestamp:1L [ account 1; account 2 ]);
  let imported =
    List.hd
      (create_transfers
         imported_state
         ~timestamp:4L
         [ transfer
             ~flags:(transfer_flags ~pending:true ~imported:true ())
             ~timeout:1l
             ~timestamp:3L
             10
         ])
  in
  require
    (imported.status = Transfer_imported_timeout_must_be_zero)
    "imported pending timeout should be rejected";
  let closing_state = empty () in
  ignore (create_accounts closing_state ~timestamp:1L [ account 1; account 2 ]);
  let closing =
    transfer ~flags:(transfer_flags ~pending:true ~closing_debit:true ()) ~timeout:1l 10
  in
  ignore (create_transfers closing_state ~timestamp:3L [ closing ]);
  require
    (account_of closing_state 1).flags.closed
    "closing pending transfer should close";
  require
    (expire_pending_transfers closing_state ~timestamp:1_000_000_003L = 1)
    "closing pending transfer should expire";
  require
    (not (account_of closing_state 1).flags.closed)
    "expired closing pending transfer should reopen"
;;

let test_post_pending_retry_and_balance_history () =
  let state = empty () in
  ignore (create_accounts state ~timestamp:1L [ account 1; account 2 ]);
  ignore
    (create_transfers
       state
       ~timestamp:3L
       [ transfer ~flags:(transfer_flags ~pending:true ()) 10 ]);
  let full_post =
    { (transfer
         ~flags:(transfer_flags ~post_pending_transfer:true ())
         ~pending_id:(u128 10)
         11)
      with
      amount = U128.max_value
    }
  in
  require
    ((List.hd (create_transfers state ~timestamp:4L [ full_post ])).status
     = Transfer_created)
    "full post should be created";
  require
    ((List.hd (create_transfers state ~timestamp:5L [ full_post ])).status
     = Transfer_exists)
    "AMOUNT_MAX full-post retry should exist";
  require
    ((List.hd
        (create_transfers state ~timestamp:6L [ { full_post with amount = u128 10 } ]))
       .status
     = Transfer_exists)
    "normalized full-post retry should exist";
  ignore (create_transfers state ~timestamp:7L [ transfer ~amount:7 12 ]);
  let filter debits credits =
    { account_id = u128 1
    ; user_data_128 = U128.zero
    ; user_data_64 = 0L
    ; user_data_32 = 0l
    ; code = 0
    ; timestamp_min = 0L
    ; timestamp_max = 0L
    ; limit = 10
    ; debits
    ; credits
    ; reversed = false
    }
  in
  let history = get_account_balances state (filter true true) in
  require (List.length history = 3) "history should contain one snapshot per transfer";
  require
    (List.map (fun (account : account) -> account.timestamp) history = [ 3L; 4L; 7L ])
    "history should be chronological";
  require_u128 10 (List.nth history 0).debits_pending "pending history mismatch";
  require_u128 10 (List.nth history 1).debits_posted "post history mismatch";
  require_u128 17 (List.nth history 2).debits_posted "single-phase history mismatch";
  require
    (List.length (get_account_balances state (filter false true)) = 0)
    "credit-only filter should exclude debit events"
;;

let () =
  test_single_phase ();
  test_pending_post_and_void ();
  test_linked_rollback ();
  test_zig_validation_precedence ();
  test_open_linked_suffix ();
  test_timeout_validation_and_closing_expiry ();
  test_post_pending_retry_and_balance_history ();
  print_endline "state_machine equivalence scenarios: ok"
;;
