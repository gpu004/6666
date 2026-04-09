open QCheck

let equal_u128 = U128.equal

let equal_account (a : Types.account) (b : Types.account) =
  equal_u128 a.Types.id b.Types.id
  && equal_u128 a.Types.debits_pending b.Types.debits_pending
  && equal_u128 a.Types.debits_posted b.Types.debits_posted
  && equal_u128 a.Types.credits_pending b.Types.credits_pending
  && equal_u128 a.Types.credits_posted b.Types.credits_posted
  && equal_u128 a.Types.user_data_128 b.Types.user_data_128
  && a.Types.user_data_64 = b.Types.user_data_64
  && a.Types.user_data_32 = b.Types.user_data_32
  && a.Types.ledger = b.Types.ledger
  && a.Types.code = b.Types.code
  && a.Types.flags = b.Types.flags
  && a.Types.timestamp = b.Types.timestamp

let equal_account_filter a b =
  equal_u128 a.Types.account_id b.Types.account_id
  && equal_u128 a.Types.user_data_128 b.Types.user_data_128
  && a.Types.user_data_64 = b.Types.user_data_64
  && a.Types.user_data_32 = b.Types.user_data_32
  && a.Types.code = b.Types.code
  && a.Types.timestamp_min = b.Types.timestamp_min
  && a.Types.timestamp_max = b.Types.timestamp_max
  && a.Types.limit = b.Types.limit
  && a.Types.flags = b.Types.flags

let ( let* ) = Gen.bind
let return = Gen.return

let gen_u128 =
  let* raw = Gen.string_size ~gen:Gen.char (Gen.return 16) in
  return (U128.of_le_bytes (Bytes.unsafe_of_string raw) 0)

let arb_u128 = make ~print:U128.to_string gen_u128

let gen_account : Types.account Gen.t =
  let* id = gen_u128 in
  let* debits_pending = gen_u128 in
  let* debits_posted = gen_u128 in
  let* credits_pending = gen_u128 in
  let* credits_posted = gen_u128 in
  let* user_data_128 = gen_u128 in
  let* user_data_64 = Gen.int64 in
  let* user_data_32 = Gen.int32 in
  let* ledger = Gen.map (fun n -> Int32.of_int (n + 1)) (Gen.int_bound 1023) in
  let* code = Gen.int_bound 0xFFFF in
  let* flags = Gen.int_bound 0xFFFF in
  let* timestamp = Gen.int64 in
  return
    {
      Types.id;
      debits_pending;
      debits_posted;
      credits_pending;
      credits_posted;
      user_data_128;
      user_data_64;
      user_data_32;
      ledger;
      code;
      flags;
      timestamp;
    }

let arb_account = make ~print:(fun _ -> "<account>") gen_account

let gen_account_filter : Types.account_filter Gen.t =
  let* account_id = gen_u128 in
  let* user_data_128 = gen_u128 in
  let* user_data_64 = Gen.int64 in
  let* user_data_32 = Gen.int32 in
  let* code = Gen.int_bound 0xFFFF in
  let* timestamp_min = Gen.int64 in
  let* timestamp_max = Gen.int64 in
  let* limit = Gen.map Int32.of_int (Gen.int_bound 2048) in
  let* flags = Gen.int32 in
  return
    {
      Types.account_id;
      user_data_128;
      user_data_64;
      user_data_32;
      code;
      timestamp_min;
      timestamp_max;
      limit;
      flags;
    }

let arb_account_filter =
  make ~print:(fun _ -> "<account_filter>") gen_account_filter

let gen_batch =
  let* chunk_count = Gen.int_bound 4 in
  let len = chunk_count * 16 in
  let* payload = Gen.string_size ~gen:Gen.printable (Gen.return len) in
  return (Bytes.of_string payload)

let rec gen_batch_list n acc =
  if n = 0 then return (List.rev acc)
  else
    let* batch = gen_batch in
    gen_batch_list (n - 1) (batch :: acc)

let gen_batches =
  let* count = Gen.map (fun n -> n + 1) (Gen.int_bound 4) in
  gen_batch_list count []

let arb_batches =
  make
    ~print:(fun batches ->
      batches |> List.map Bytes.to_string |> String.concat ";")
    gen_batches

let tests =
  [
    Test.make ~count:200 ~name:"U128 little-endian bytes roundtrip" arb_u128
      (fun value ->
        U128.equal value (U128.of_le_bytes (U128.to_le_bytes value) 0));
    Test.make ~count:200 ~name:"Codec account roundtrip" arb_account
      (fun account ->
        equal_account account
          (Codec.decode_account (Codec.encode_account account) 0));
    Test.make ~count:200 ~name:"Codec account_filter roundtrip"
      arb_account_filter (fun filter ->
        equal_account_filter filter
          (Codec.decode_account_filter (Codec.encode_account_filter filter)));
    Test.make ~count:200 ~name:"MultiBatch encode/decode roundtrip" arb_batches
      (fun batches ->
        let decoded =
          Multibatch.decode ~element_size:16
            (Multibatch.encode ~element_size:16 batches)
        in
        List.for_all2 Bytes.equal batches decoded);
  ]

let () = if QCheck_base_runner.run_tests_main tests then () else exit 1
