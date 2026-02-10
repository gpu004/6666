open Tiger_core

let uint128_testable =
  Alcotest.testable
    (fun fmt v -> Format.pp_print_string fmt (Types.u128_to_string v))
    Types.u128_equal

let test_id_reject_zero () =
  match Types.account_id_of_u128 Types.u128_zero with
  | Error Types.Id_must_not_be_zero -> ()
  | _ -> Alcotest.fail "should reject zero"

let test_id_reject_max () =
  match Types.transfer_id_of_u128 Types.u128_max with
  | Error Types.Id_must_not_be_int_max -> ()
  | _ -> Alcotest.fail "should reject max"

let test_id_accept_valid () =
  let v = Types.u128_of_int 1 in
  match Types.account_id_of_u128 v with
  | Ok id -> Alcotest.check uint128_testable "roundtrip" v (Types.account_id_to_u128 id)
  | Error _ -> Alcotest.fail "expected valid id"

let test_ledger_reject_zero () =
  match Types.ledger_id_of_u32 0l with
  | Error Types.Ledger_must_not_be_zero -> ()
  | _ -> Alcotest.fail "should reject zero ledger"

let test_ledger_accept_valid () =
  match Types.ledger_id_of_u32 7l with
  | Ok ledger -> Alcotest.(check int32) "roundtrip" 7l (Types.ledger_id_to_u32 ledger)
  | Error _ -> Alcotest.fail "expected valid ledger"

let test_account_flags_mutual_exclusion () =
  match
    Types.account_flags_make ~linked:false
      ~debits_must_not_exceed_credits:true
      ~credits_must_not_exceed_debits:true ~history:false ~imported:false
      ~closed:false
  with
  | Error Types.Flags_are_mutually_exclusive -> ()
  | _ -> Alcotest.fail "expected mutually exclusive flags error"

let test_account_flags_roundtrip () =
  match
    Types.account_flags_make ~linked:true
      ~debits_must_not_exceed_credits:true
      ~credits_must_not_exceed_debits:false ~history:false ~imported:true
      ~closed:false
  with
  | Error _ -> Alcotest.fail "expected valid account flags"
  | Ok flags ->
    let bits = Types.account_flags_to_u16 flags in
    match Types.account_flags_of_u16 bits with
    | Ok decoded ->
      Alcotest.(check bool) "linked" true decoded.linked;
      Alcotest.(check bool) "imported" true decoded.imported
    | Error _ -> Alcotest.fail "expected decode to pass"

let test_transfer_flags_mutual_exclusion () =
  match
    Types.transfer_flags_make ~linked:false ~pending:true
      ~post_pending_transfer:true ~void_pending_transfer:false
      ~balancing_debit:false ~balancing_credit:false ~closing_debit:false
      ~closing_credit:false ~imported:false
  with
  | Error Types.Flags_are_mutually_exclusive -> ()
  | _ -> Alcotest.fail "expected mutually exclusive flags error"

let test_transfer_flags_roundtrip () =
  match
    Types.transfer_flags_make ~linked:true ~pending:true
      ~post_pending_transfer:false ~void_pending_transfer:false
      ~balancing_debit:false ~balancing_credit:false ~closing_debit:false
      ~closing_credit:false ~imported:false
  with
  | Error _ -> Alcotest.fail "expected valid transfer flags"
  | Ok flags ->
    let bits = Types.transfer_flags_to_u16 flags in
    match Types.transfer_flags_of_u16 bits with
    | Ok decoded -> Alcotest.(check bool) "pending" true decoded.pending
    | Error _ -> Alcotest.fail "expected decode to pass"

let test_transfer_pending_status_mapping () =
  Alcotest.(check int) "pending->1" 1
    (Types.transfer_pending_status_to_u8 Types.Pending);
  match Types.transfer_pending_status_of_u8 4 with
  | Some Types.Expired -> ()
  | _ -> Alcotest.fail "expected expired"

let test_create_account_result_codes () =
  Alcotest.(check int32) "ok=0" 0l
    (Errors.create_account_result_to_u32 Errors.Ok);
  Alcotest.(check int32) "exists=21" 21l
    (Errors.create_account_result_to_u32 Errors.Exists);
  match Errors.create_account_result_of_u32 26l with
  | Some Errors.Imported_event_timestamp_must_not_regress -> ()
  | _ -> Alcotest.fail "expected account code 26"

let test_create_transfer_result_codes () =
  Alcotest.(check int32) "ok=0" 0l
    (Errors.create_transfer_result_to_u32 Errors.Ok);
  Alcotest.(check int32) "id_already_failed=68" 68l
    (Errors.create_transfer_result_to_u32 Errors.Id_already_failed);
  match Errors.create_transfer_result_of_u32 18l with
  | Some Errors.Deprecated_18 -> ()
  | _ -> Alcotest.fail "expected transfer code 18"

let test_command_roundtrip () =
  let commands =
    [
      Requests.Cmd_create_accounts;
      Requests.Cmd_create_transfers;
      Requests.Cmd_lookup_accounts;
      Requests.Cmd_lookup_transfers;
      Requests.Cmd_get_account_transfers;
      Requests.Cmd_get_account_balances;
      Requests.Cmd_query_accounts;
      Requests.Cmd_query_transfers;
      Requests.Cmd_get_change_events;
    ]
  in
  List.iter
    (fun cmd ->
      let i = Requests.command_to_int cmd in
      match Requests.command_of_int i with
      | Some cmd' ->
        Alcotest.(check string) "roundtrip"
          (Requests.command_to_string cmd)
          (Requests.command_to_string cmd')
      | None -> Alcotest.fail "unknown command")
    commands

let test_request_command_mapping () =
  let req = Requests.Lookup_accounts [ Types.u128_of_int 1 ] in
  Alcotest.(check string) "command" "lookup_accounts"
    (Requests.command_to_string (Requests.request_command req))

let () =
  Alcotest.run "types"
    [
      ( "ids",
        [
          Alcotest.test_case "reject zero" `Quick test_id_reject_zero;
          Alcotest.test_case "reject max" `Quick test_id_reject_max;
          Alcotest.test_case "accept valid" `Quick test_id_accept_valid;
          Alcotest.test_case "ledger rejects zero" `Quick test_ledger_reject_zero;
          Alcotest.test_case "ledger valid" `Quick test_ledger_accept_valid;
        ] );
      ( "flags",
        [
          Alcotest.test_case "account flags mutual exclusion" `Quick
            test_account_flags_mutual_exclusion;
          Alcotest.test_case "account flags roundtrip" `Quick
            test_account_flags_roundtrip;
          Alcotest.test_case "transfer flags mutual exclusion" `Quick
            test_transfer_flags_mutual_exclusion;
          Alcotest.test_case "transfer flags roundtrip" `Quick
            test_transfer_flags_roundtrip;
          Alcotest.test_case "pending status" `Quick
            test_transfer_pending_status_mapping;
        ] );
      ( "errors",
        [
          Alcotest.test_case "account result codes" `Quick
            test_create_account_result_codes;
          Alcotest.test_case "transfer result codes" `Quick
            test_create_transfer_result_codes;
        ] );
      ( "requests",
        [
          Alcotest.test_case "command roundtrip" `Quick test_command_roundtrip;
          Alcotest.test_case "request_command" `Quick
            test_request_command_mapping;
        ] );
    ]
