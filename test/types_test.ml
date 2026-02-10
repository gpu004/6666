open Tiger_core

(* --- Helpers ------------------------------------------------------------- *)

let _id_testable = Alcotest.testable
  (fun fmt id -> Format.pp_print_string fmt (Types.id_to_string id))
  Types.id_equal

let uint128_testable = Alcotest.testable
  (fun fmt v -> Format.pp_print_string fmt (Types.uint128_to_string v))
  Types.uint128_equal

(* --- uint128 tests ------------------------------------------------------- *)

let test_uint128_zero () =
  Alcotest.(check bool) "zero equals zero"
    true (Types.uint128_equal Types.uint128_zero Types.uint128_zero)

let test_uint128_of_int () =
  let v = Types.uint128_of_int 42 in
  Alcotest.(check int64) "lo is 42" 42L v.lo;
  Alcotest.(check int64) "hi is 0" 0L v.hi

let test_uint128_compare_equal () =
  let a = Types.uint128_of_int 100 in
  let b = Types.uint128_of_int 100 in
  Alcotest.(check int) "equal" 0 (Types.uint128_compare a b)

let test_uint128_compare_less () =
  let a = Types.uint128_of_int 1 in
  let b = Types.uint128_of_int 2 in
  Alcotest.(check bool) "a < b" true (Types.uint128_compare a b < 0)

let test_uint128_max_not_zero () =
  Alcotest.(check bool) "max != zero"
    false (Types.uint128_equal Types.uint128_max Types.uint128_zero)

(* --- id tests ------------------------------------------------------------ *)

let test_id_reject_zero () =
  match Types.id_of_uint128 Types.uint128_zero with
  | Error _ -> ()
  | Ok _ -> Alcotest.fail "should reject zero"

let test_id_reject_max () =
  match Types.id_of_uint128 Types.uint128_max with
  | Error _ -> ()
  | Ok _ -> Alcotest.fail "should reject max"

let test_id_accept_valid () =
  let v = Types.uint128_of_int 1 in
  match Types.id_of_uint128 v with
  | Ok id ->
    Alcotest.(check (module struct
      type t = Types.uint128
      let pp fmt v = Format.pp_print_string fmt (Types.uint128_to_string v)
      let equal = Types.uint128_equal
    end : Alcotest.TESTABLE with type t = Types.uint128))
      "roundtrip" v (Types.id_to_uint128 id)
  | Error e -> Alcotest.fail e

let test_id_roundtrip () =
  let v = { Types.hi = 123L; lo = 456L } in
  match Types.id_of_uint128 v with
  | Ok id -> Alcotest.check uint128_testable "roundtrip" v (Types.id_to_uint128 id)
  | Error e -> Alcotest.fail e

(* --- ledger tests -------------------------------------------------------- *)

let test_ledger_reject_zero () =
  match Types.ledger_of_int32 0l with
  | Error _ -> ()
  | Ok _ -> Alcotest.fail "should reject zero"

let test_ledger_accept_valid () =
  match Types.ledger_of_int32 1l with
  | Ok l -> Alcotest.(check int32) "roundtrip" 1l (Types.ledger_to_int32 l)
  | Error e -> Alcotest.fail e

(* --- code tests ---------------------------------------------------------- *)

let test_code_reject_zero () =
  match Types.code_of_int 0 with
  | Error _ -> ()
  | Ok _ -> Alcotest.fail "should reject zero"

let test_code_reject_too_large () =
  match Types.code_of_int 0x10000 with
  | Error _ -> ()
  | Ok _ -> Alcotest.fail "should reject > 0xFFFF"

let test_code_accept_valid () =
  match Types.code_of_int 42 with
  | Ok c -> Alcotest.(check int) "roundtrip" 42 (Types.code_to_int c)
  | Error e -> Alcotest.fail e

(* --- account_flags tests ------------------------------------------------- *)

let test_account_flags_default_is_zero () =
  Alcotest.(check int) "default is 0"
    0 (Types.account_flags_to_int Types.account_flags_default)

let test_account_flags_roundtrip () =
  let f = Types.{ account_flags_default with
    linked = true;
    debits_must_not_exceed_credits = true;
    history = true;
  } in
  let bits = Types.account_flags_to_int f in
  let f' = Types.account_flags_of_int bits in
  Alcotest.(check bool) "linked" true f'.linked;
  Alcotest.(check bool) "debits_must_not_exceed_credits" true
    f'.debits_must_not_exceed_credits;
  Alcotest.(check bool) "credits_must_not_exceed_debits" false
    f'.credits_must_not_exceed_debits;
  Alcotest.(check bool) "history" true f'.history;
  Alcotest.(check bool) "imported" false f'.imported;
  Alcotest.(check bool) "closed" false f'.closed

let test_account_flags_all_bits () =
  let f = Types.{
    linked = true;
    debits_must_not_exceed_credits = true;
    credits_must_not_exceed_debits = true;
    history = true;
    imported = true;
    closed = true;
  } in
  let bits = Types.account_flags_to_int f in
  Alcotest.(check int) "all bits" 0x3F bits

(* --- transfer_flags tests ------------------------------------------------ *)

let test_transfer_flags_default_is_zero () =
  Alcotest.(check int) "default is 0"
    0 (Types.transfer_flags_to_int Types.transfer_flags_default)

let test_transfer_flags_roundtrip () =
  let f = Types.{ transfer_flags_default with
    pending = true;
    balancing_debit = true;
    imported = true;
  } in
  let bits = Types.transfer_flags_to_int f in
  let f' = Types.transfer_flags_of_int bits in
  Alcotest.(check bool) "linked" false f'.linked;
  Alcotest.(check bool) "pending" true f'.pending;
  Alcotest.(check bool) "post" false f'.post_pending_transfer;
  Alcotest.(check bool) "void" false f'.void_pending_transfer;
  Alcotest.(check bool) "balancing_debit" true f'.balancing_debit;
  Alcotest.(check bool) "balancing_credit" false f'.balancing_credit;
  Alcotest.(check bool) "imported" true f'.imported

let test_transfer_flags_all_bits () =
  let f = Types.{
    linked = true;
    pending = true;
    post_pending_transfer = true;
    void_pending_transfer = true;
    balancing_debit = true;
    balancing_credit = true;
    closing_debit = true;
    closing_credit = true;
    imported = true;
  } in
  let bits = Types.transfer_flags_to_int f in
  Alcotest.(check int) "all bits" 0x1FF bits

(* --- error code tests ---------------------------------------------------- *)

let test_create_account_result_roundtrip () =
  (* Test a few representative codes *)
  let codes : Errors.create_account_result list = [
    Errors.Ok; Errors.Exists; Errors.Id_must_not_be_zero;
    Errors.Mutually_exclusive_flags;
  ] in
  List.iter (fun code ->
    let i = Errors.create_account_result_to_int code in
    match Errors.create_account_result_of_int i with
    | Some code' ->
      Alcotest.(check string) "roundtrip"
        (Errors.create_account_result_to_string code)
        (Errors.create_account_result_to_string code')
    | None -> Alcotest.fail (Printf.sprintf "unknown code %d" i)
  ) codes

let test_create_transfer_result_roundtrip () =
  let codes = [
    Errors.Ok; Errors.Exists; Errors.Id_must_not_be_zero;
    Errors.Debit_account_not_found; Errors.Insufficient_debit_balance;
    Errors.Linked_event_failed;
  ] in
  List.iter (fun (code : Errors.create_transfer_result) ->
    let i = Errors.create_transfer_result_to_int code in
    match Errors.create_transfer_result_of_int i with
    | Some code' ->
      Alcotest.(check string) "roundtrip"
        (Errors.create_transfer_result_to_string code)
        (Errors.create_transfer_result_to_string code')
    | None -> Alcotest.fail (Printf.sprintf "unknown code %d" i)
  ) codes

let test_unknown_error_code_returns_none () =
  Alcotest.(check bool) "account unknown" true
    (Errors.create_account_result_of_int 999 = None);
  Alcotest.(check bool) "transfer unknown" true
    (Errors.create_transfer_result_of_int 999 = None)

(* --- request tests ------------------------------------------------------- *)

let test_command_roundtrip () =
  let commands = [
    Requests.Create_accounts; Create_transfers;
    Lookup_accounts; Lookup_transfers;
    Get_account_transfers; Get_account_balances;
    Query_accounts; Query_transfers;
  ] in
  List.iter (fun cmd ->
    let i = Requests.command_to_int cmd in
    match Requests.command_of_int i with
    | Some cmd' ->
      Alcotest.(check string) "roundtrip"
        (Requests.command_to_string cmd)
        (Requests.command_to_string cmd')
    | None -> Alcotest.fail (Printf.sprintf "unknown command %d" i)
  ) commands

let test_request_command_mapping () =
  let id = match Types.id_of_uint128 (Types.uint128_of_int 1) with
    | Ok id -> id | Error e -> failwith e
  in
  let req = Requests.Req_lookup_accounts [id] in
  Alcotest.(check string) "command" "lookup_accounts"
    (Requests.command_to_string (Requests.request_command req))

(* --- Run ----------------------------------------------------------------- *)

let () =
  Alcotest.run "types"
    [
      ( "uint128",
        [
          Alcotest.test_case "zero" `Quick test_uint128_zero;
          Alcotest.test_case "of_int" `Quick test_uint128_of_int;
          Alcotest.test_case "compare equal" `Quick test_uint128_compare_equal;
          Alcotest.test_case "compare less" `Quick test_uint128_compare_less;
          Alcotest.test_case "max != zero" `Quick test_uint128_max_not_zero;
        ] );
      ( "id",
        [
          Alcotest.test_case "reject zero" `Quick test_id_reject_zero;
          Alcotest.test_case "reject max" `Quick test_id_reject_max;
          Alcotest.test_case "accept valid" `Quick test_id_accept_valid;
          Alcotest.test_case "roundtrip" `Quick test_id_roundtrip;
        ] );
      ( "ledger",
        [
          Alcotest.test_case "reject zero" `Quick test_ledger_reject_zero;
          Alcotest.test_case "accept valid" `Quick test_ledger_accept_valid;
        ] );
      ( "code",
        [
          Alcotest.test_case "reject zero" `Quick test_code_reject_zero;
          Alcotest.test_case "reject too large" `Quick test_code_reject_too_large;
          Alcotest.test_case "accept valid" `Quick test_code_accept_valid;
        ] );
      ( "account_flags",
        [
          Alcotest.test_case "default is zero" `Quick test_account_flags_default_is_zero;
          Alcotest.test_case "roundtrip" `Quick test_account_flags_roundtrip;
          Alcotest.test_case "all bits" `Quick test_account_flags_all_bits;
        ] );
      ( "transfer_flags",
        [
          Alcotest.test_case "default is zero" `Quick test_transfer_flags_default_is_zero;
          Alcotest.test_case "roundtrip" `Quick test_transfer_flags_roundtrip;
          Alcotest.test_case "all bits" `Quick test_transfer_flags_all_bits;
        ] );
      ( "errors",
        [
          Alcotest.test_case "account result roundtrip" `Quick
            test_create_account_result_roundtrip;
          Alcotest.test_case "transfer result roundtrip" `Quick
            test_create_transfer_result_roundtrip;
          Alcotest.test_case "unknown returns None" `Quick
            test_unknown_error_code_returns_none;
        ] );
      ( "requests",
        [
          Alcotest.test_case "command roundtrip" `Quick test_command_roundtrip;
          Alcotest.test_case "request_command" `Quick test_request_command_mapping;
        ] );
    ]
