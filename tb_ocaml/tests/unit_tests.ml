open Alcotest

let u128 = testable U128.pp U128.equal

let int32 =
  testable
    (fun fmt v -> Format.pp_print_string fmt (Int32.to_string v))
    Int32.equal

let check_account_filter label expected actual =
  check u128 (label ^ " account_id") expected.Types.account_id
    actual.Types.account_id;
  check u128 (label ^ " user_data_128") expected.Types.user_data_128
    actual.Types.user_data_128;
  check int64 (label ^ " user_data_64") expected.Types.user_data_64
    actual.Types.user_data_64;
  check int32 (label ^ " user_data_32") expected.Types.user_data_32
    actual.Types.user_data_32;
  check int (label ^ " code") expected.Types.code actual.Types.code;
  check int64 (label ^ " timestamp_min") expected.Types.timestamp_min
    actual.Types.timestamp_min;
  check int64 (label ^ " timestamp_max") expected.Types.timestamp_max
    actual.Types.timestamp_max;
  check int32 (label ^ " limit") expected.Types.limit actual.Types.limit;
  check int32 (label ^ " flags") expected.Types.flags actual.Types.flags

let check_query_filter label expected actual =
  check u128 (label ^ " user_data_128") expected.Types.user_data_128
    actual.Types.user_data_128;
  check int64 (label ^ " user_data_64") expected.Types.user_data_64
    actual.Types.user_data_64;
  check int32 (label ^ " user_data_32") expected.Types.user_data_32
    actual.Types.user_data_32;
  check int32 (label ^ " ledger") expected.Types.ledger actual.Types.ledger;
  check int (label ^ " code") expected.Types.code actual.Types.code;
  check int64 (label ^ " timestamp_min") expected.Types.timestamp_min
    actual.Types.timestamp_min;
  check int64 (label ^ " timestamp_max") expected.Types.timestamp_max
    actual.Types.timestamp_max;
  check int32 (label ^ " limit") expected.Types.limit actual.Types.limit;
  check int32 (label ^ " flags") expected.Types.flags actual.Types.flags

let test_multibatch_roundtrip () =
  let batches =
    [ Bytes.of_string "abcdefghijklmnop"; Bytes.of_string "qrstuvwxyzABCDEF" ]
  in
  let encoded = Multibatch.encode ~element_size:16 batches in
  let decoded = Multibatch.decode ~element_size:16 encoded in
  check (list string) "roundtrip preserves batches"
    (List.map Bytes.to_string batches)
    (List.map Bytes.to_string decoded)

let test_multibatch_alignment () =
  check int "trailer size is padded to element size" 16
    (Multibatch.trailer_total_size ~element_size:16 ~batch_count:2)

let test_account_filter_roundtrip () =
  let filter =
    {
      Types.account_id = U128.of_decimal_string "42";
      user_data_128 = U128.of_decimal_string "99";
      user_data_64 = 123456789L;
      user_data_32 = 77l;
      code = 718;
      timestamp_min = 1000L;
      timestamp_max = 2000L;
      limit = 99l;
      flags = 3l;
    }
  in
  check_account_filter "account filter" filter
    (Codec.decode_account_filter (Codec.encode_account_filter filter))

let test_query_filter_roundtrip () =
  let filter =
    {
      Types.user_data_128 = U128.of_decimal_string "123";
      user_data_64 = 555L;
      user_data_32 = 17l;
      ledger = 3l;
      code = 71;
      timestamp_min = 500L;
      timestamp_max = 900L;
      limit = 10l;
      flags = 1l;
    }
  in
  check_query_filter "query filter" filter
    (Codec.decode_query_filter (Codec.encode_query_filter filter))

let test_create_error_encoding_filters_successes () =
  let results =
    [
      { Types.timestamp = 1L; status = Types.create_account_created };
      { Types.timestamp = 2L; status = Types.create_account_exists };
    ]
  in
  let encoded = Codec.encode_create_account_errors results in
  check int "one failing result is emitted" Types.create_error_result_size
    (Bytes.length encoded);
  check int32 "failing result index" 1l (Codec.get_i32 encoded 0);
  check int32 "failing result status" Types.create_account_exists
    (Codec.get_i32 encoded 4)

let test_flag_names () =
  check (list string) "account flags" [ "linked"; "closed" ]
    (Types.account_flag_names
       (Types.account_flag_linked lor Types.account_flag_closed));
  check (list string) "transfer flags"
    [ "pending"; "closing_credit"; "imported" ]
    (Types.transfer_flag_names
       (Types.transfer_flag_pending lor Types.transfer_flag_closing_credit
      lor Types.transfer_flag_imported))

let test_unknown_status_name_includes_code () =
  check string "account unknown status includes numeric code"
    "tigerbeetle.CreateAccountStatus.unknown(999)"
    (Types.account_status_name 999l);
  check string "transfer unknown status includes numeric code"
    "tigerbeetle.CreateTransferStatus.unknown(888)"
    (Types.transfer_status_name 888l)

let test_repl_parse_create_accounts () =
  match Repl.parse_command "create_accounts id=17 code=718 ledger=1" with
  | Repl.CreateAccounts [ account ] ->
      check u128 "account id" (U128.of_int 17) account.Types.id;
      check int "account code" 718 account.Types.code;
      check int32 "account ledger" 1l account.Types.ledger
  | Repl.CreateAccounts _ -> fail "expected single create_accounts statement"
  | Repl.CreateTransfers _ | Repl.LookupAccounts _ | Repl.LookupTransfers _
  | Repl.QueryAccounts _ | Repl.QueryTransfers _ | Repl.GetAccountTransfers _
  | Repl.GetAccountBalances _ ->
      fail "expected create_accounts statement"

let test_repl_parse_query_accounts () =
  match
    Repl.parse_command
      "query_accounts user_data_64=55 ledger=3 code=71 flags=reversed limit=9"
  with
  | Repl.QueryAccounts filter ->
      check int64 "query user_data_64" 55L filter.Types.user_data_64;
      check int32 "query ledger" 3l filter.Types.ledger;
      check int "query code" 71 filter.Types.code;
      check int32 "query limit" 9l filter.Types.limit;
      check int32 "query flags" 1l filter.Types.flags
  | Repl.CreateAccounts _ | Repl.CreateTransfers _ | Repl.LookupAccounts _
  | Repl.LookupTransfers _ | Repl.QueryTransfers _ | Repl.GetAccountTransfers _
  | Repl.GetAccountBalances _ ->
      fail "expected query_accounts statement"

let with_state f =
  let path = Filename.temp_file "tb_ocaml_state" ".db" in
  Fun.protect
    ~finally:(fun () -> if Sys.file_exists path then Sys.remove path)
    (fun () ->
      State.format ~path ~cluster:(U128.of_int 0);
      let state = State.load path in
      f state)

let make_account ?(id = 1) ?(ledger = 1l) ?(code = 10) () =
  {
    Types.id = U128.of_int id;
    debits_pending = U128.zero;
    debits_posted = U128.zero;
    credits_pending = U128.zero;
    credits_posted = U128.zero;
    user_data_128 = U128.zero;
    user_data_64 = 0L;
    user_data_32 = 0l;
    ledger;
    code;
    flags = 0;
    timestamp = 0L;
  }

let test_state_create_and_lookup_account () =
  with_state (fun state ->
      let created = State.create_accounts_batch state [ make_account () ] in
      check int "one create result" 1 (List.length created);
      check int32 "create status" Types.create_account_created
        (List.hd created).Types.status;
      let found = State.lookup_accounts_batch state [ U128.of_int 1 ] in
      check int "one account found" 1 (List.length found);
      check int "lookup preserves code" 10 (List.hd found).Types.code)

let test_state_query_rejects_invalid_filter () =
  with_state (fun state ->
      ignore (State.create_accounts_batch state [ make_account () ]);
      let invalid_filter =
        {
          Types.user_data_128 = U128.zero;
          user_data_64 = 0L;
          user_data_32 = 0l;
          ledger = 0l;
          code = 0;
          timestamp_min = 10L;
          timestamp_max = 5L;
          limit = 10l;
          flags = 0l;
        }
      in
      check int "invalid filter returns no results" 0
        (List.length (State.query_accounts_batch state invalid_filter)))

let () =
  run "tb_ocaml unit"
    [
      ( "multibatch",
        [
          test_case "roundtrip" `Quick test_multibatch_roundtrip;
          test_case "alignment" `Quick test_multibatch_alignment;
        ] );
      ( "codec",
        [
          test_case "account filter roundtrip" `Quick
            test_account_filter_roundtrip;
          test_case "query filter roundtrip" `Quick test_query_filter_roundtrip;
          test_case "create error filtering" `Quick
            test_create_error_encoding_filters_successes;
        ] );
      ( "types",
        [
          test_case "flag names" `Quick test_flag_names;
          test_case "unknown status names include codes" `Quick
            test_unknown_status_name_includes_code;
        ] );
      ( "repl",
        [
          test_case "parse create_accounts" `Quick
            test_repl_parse_create_accounts;
          test_case "parse query_accounts" `Quick test_repl_parse_query_accounts;
        ] );
      ( "state",
        [
          test_case "create and lookup account" `Quick
            test_state_create_and_lookup_account;
          test_case "invalid query filter returns empty" `Quick
            test_state_query_rejects_invalid_filter;
        ] );
    ]
