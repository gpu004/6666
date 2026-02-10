open Tiger_core

let unwrap_result = function
  | Ok v -> v
  | Error _ -> Alcotest.fail "invalid generated value"

let mk_account_id v = Types.account_id_of_u128 v |> unwrap_result
let mk_transfer_id v = Types.transfer_id_of_u128 v |> unwrap_result
let mk_ledger v = Types.ledger_id_of_u32 v |> unwrap_result
let mk_amount v = Types.amount_of_u128 v |> unwrap_result

let gen_u128 =
  let open QCheck.Gen in
  map2 (fun hi lo -> Types.{ hi; lo }) int64 int64

let gen_nonzero_u128 =
  let open QCheck.Gen in
  let rec loop () =
    bind gen_u128 (fun v ->
        if Types.u128_equal v Types.u128_zero || Types.u128_equal v Types.u128_max then
          loop ()
        else return v)
  in
  loop ()

let gen_account_id = QCheck.Gen.map mk_account_id gen_nonzero_u128
let gen_transfer_id = QCheck.Gen.map mk_transfer_id gen_nonzero_u128
let gen_amount = QCheck.Gen.map mk_amount gen_u128

let gen_code =
  let open QCheck.Gen in
  1 -- 0xFFFF

let gen_ledger =
  let open QCheck.Gen in
  map (fun n -> mk_ledger (Int32.of_int n)) (1 -- Int32.to_int Int32.max_int)

let gen_account =
  let open QCheck.Gen in
  bind gen_account_id (fun id ->
      bind gen_ledger (fun ledger ->
          bind gen_code (fun code ->
              bind int64 (fun timestamp ->
                  return
                    Types.
                      {
                        id;
                        debits_pending = Types.u128_zero;
                        debits_posted = Types.u128_zero;
                        credits_pending = Types.u128_zero;
                        credits_posted = Types.u128_zero;
                        user_data_128 = Types.u128_zero;
                        user_data_64 = 0L;
                        user_data_32 = 0l;
                        reserved = 0l;
                        ledger;
                        code;
                        flags = Types.account_flags_default;
                        timestamp;
                      }))))

let gen_transfer =
  let open QCheck.Gen in
  bind gen_transfer_id (fun id ->
      bind gen_account_id (fun debit_account_id ->
          bind gen_account_id (fun credit_account_id ->
              bind gen_amount (fun amount ->
                  bind gen_ledger (fun ledger ->
                      bind gen_code (fun code ->
                          bind int64 (fun timestamp ->
                              return
                                Types.
                                  {
                                    id;
                                    debit_account_id;
                                    credit_account_id;
                                    amount;
                                    pending_id = Types.u128_zero;
                                    user_data_128 = Types.u128_zero;
                                    user_data_64 = 0L;
                                    user_data_32 = 0l;
                                    timeout = 0l;
                                    ledger;
                                    code;
                                    flags = Types.transfer_flags_default;
                                    timestamp;
                                  })))))))

let gen_account_filter =
  let open QCheck.Gen in
  bind gen_nonzero_u128 (fun account_id ->
      bind gen_code (fun code ->
          bind int64 (fun timestamp_min ->
              bind int64 (fun timestamp_max ->
                  return
                    Types.
                      {
                        account_id;
                        user_data_128 = Types.u128_zero;
                        user_data_64 = 0L;
                        user_data_32 = 0l;
                        code;
                        reserved = Bytes.make 58 '\x00';
                        timestamp_min;
                        timestamp_max;
                        limit = 32l;
                        flags = Types.account_filter_flags_default;
                      }))))

let gen_query_filter =
  let open QCheck.Gen in
  bind (1 -- Int32.to_int Int32.max_int) (fun ledger ->
      bind gen_code (fun code ->
          bind int64 (fun timestamp_min ->
              bind int64 (fun timestamp_max ->
                  return
                    Types.
                      {
                        user_data_128 = Types.u128_zero;
                        user_data_64 = 0L;
                        user_data_32 = 0l;
                        ledger = Int32.of_int ledger;
                        code;
                        reserved = Bytes.make 6 '\x00';
                        timestamp_min;
                        timestamp_max;
                        limit = 32l;
                        flags = Types.query_filter_flags_default;
                      }))))

let gen_change_events_filter =
  let open QCheck.Gen in
  bind int64 (fun timestamp_min ->
      bind int64 (fun timestamp_max ->
          return
            Types.
              {
                timestamp_min;
                timestamp_max;
                limit = 64l;
                reserved = Bytes.make 44 '\x00';
              }))

let gen_account_balance =
  let open QCheck.Gen in
  bind gen_u128 (fun debits_pending ->
      bind gen_u128 (fun debits_posted ->
          bind gen_u128 (fun credits_pending ->
              bind gen_u128 (fun credits_posted ->
                  bind int64 (fun timestamp ->
                      return
                        Types.
                          {
                            debits_pending;
                            debits_posted;
                            credits_pending;
                            credits_posted;
                            timestamp;
                            reserved = Bytes.make 56 '\x00';
                          })))))

let gen_request =
  let open QCheck.Gen in
  oneof_weighted
    [
      (2, map (fun xs -> Requests.Create_accounts xs) (list_small gen_account));
      (2, map (fun xs -> Requests.Create_transfers xs) (list_small gen_transfer));
      (2, map (fun xs -> Requests.Lookup_accounts xs) (list_small gen_nonzero_u128));
      (2, map (fun xs -> Requests.Lookup_transfers xs) (list_small gen_nonzero_u128));
      (1, map (fun f -> Requests.Get_account_transfers f) gen_account_filter);
      (1, map (fun f -> Requests.Get_account_balances f) gen_account_filter);
      (1, map (fun f -> Requests.Query_accounts f) gen_query_filter);
      (1, map (fun f -> Requests.Query_transfers f) gen_query_filter);
      (1, map (fun f -> Requests.Get_change_events f) gen_change_events_filter);
    ]

let gen_response =
  let open QCheck.Gen in
  let gen_create_accounts_result : Types.create_accounts_result QCheck.Gen.t =
    bind int32 (fun index ->
        bind
          (oneof_list
             [
               (Errors.Ok : Errors.create_account_result);
               Errors.Exists;
               Errors.Id_must_not_be_zero;
             ])
          (fun result ->
            return (({ index; result } : Types.create_accounts_result))))
  in
  let gen_create_transfers_result : Types.create_transfers_result QCheck.Gen.t =
    bind int32 (fun index ->
        bind
          (oneof_list
             [
               (Errors.Ok : Errors.create_transfer_result);
               Errors.Exists;
               Errors.Debit_account_not_found;
             ])
          (fun result -> return (({ index; result } : Types.create_transfers_result))))
  in
  oneof_weighted
    [
      (2, map (fun xs -> Requests.Create_accounts_result xs) (list_small gen_create_accounts_result));
      (2, map (fun xs -> Requests.Create_transfers_result xs) (list_small gen_create_transfers_result));
      (2, map (fun xs -> Requests.Lookup_accounts_result xs) (list_small gen_account));
      (2, map (fun xs -> Requests.Lookup_transfers_result xs) (list_small gen_transfer));
      (1, map (fun xs -> Requests.Get_account_transfers_result xs) (list_small gen_transfer));
      (1,
       map
         (fun xs -> Requests.Get_account_balances_result xs)
         (list_small gen_account_balance));
      (1, map (fun xs -> Requests.Query_accounts_result xs) (list_small gen_account));
      (1, map (fun xs -> Requests.Query_transfers_result xs) (list_small gen_transfer));
      (1, return (Requests.Get_change_events_result []));
    ]

let test_header_shape () =
  Alcotest.(check int) "header_size=256" 256 Tiger_codec.Header.header_size

let test_request_checksum_rejects_corruption () =
  let req = Requests.Lookup_accounts [ Types.u128_of_int 1; Types.u128_of_int 2 ] in
  let frame = Tiger_codec.Request_codec.encode_request req in
  let off = Cstruct.length frame - 1 in
  let b = Cstruct.get_uint8 frame off in
  Cstruct.set_uint8 frame off (b lxor 0x01);
  match Tiger_codec.Request_codec.decode_request frame with
  | Ok _ -> Alcotest.fail "corrupted request should fail checksum validation"
  | Error _ -> ()

let test_response_checksum_rejects_corruption () =
  let resp = Requests.Create_accounts_result [ Types.{ index = 0l; result = Errors.Ok } ] in
  let frame = Tiger_codec.Response_codec.encode_response resp in
  let off = Cstruct.length frame - 1 in
  let b = Cstruct.get_uint8 frame off in
  Cstruct.set_uint8 frame off (b lxor 0x01);
  match Tiger_codec.Response_codec.decode_response frame with
  | Ok _ -> Alcotest.fail "corrupted response should fail checksum validation"
  | Error _ -> ()

let req_roundtrip_prop =
  QCheck.Test.make ~count:300 ~name:"request encode/decode roundtrip"
    QCheck.(make gen_request)
    (fun req ->
      let frame = Tiger_codec.Request_codec.encode_request req in
      match Tiger_codec.Request_codec.decode_request frame with
      | Ok decoded -> decoded = req
      | Error _ -> false)

let resp_roundtrip_prop =
  QCheck.Test.make ~count:300 ~name:"response encode/decode roundtrip"
    QCheck.(make gen_response)
    (fun resp ->
      let frame = Tiger_codec.Response_codec.encode_response resp in
      match Tiger_codec.Response_codec.decode_response frame with
      | Ok decoded -> decoded = resp
      | Error _ -> false)

let () =
  Alcotest.run "codec"
    [
      ( "wire",
        [
          Alcotest.test_case "header is 256 bytes" `Quick test_header_shape;
          Alcotest.test_case "request checksum detects corruption" `Quick
            test_request_checksum_rejects_corruption;
          Alcotest.test_case "response checksum detects corruption" `Quick
            test_response_checksum_rejects_corruption;
        ] );
      ( "roundtrip",
        List.map QCheck_alcotest.to_alcotest [ req_roundtrip_prop; resp_roundtrip_prop ] );
    ]
