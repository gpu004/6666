open Types

type request_header = {
  checksum : U128.t;
  cluster : U128.t;
  size : int;
  release : int32;
  command : int;
  client : U128.t;
  session : int64;
  timestamp : int64;
  request : int32;
  operation : int;
}

type reply_header = {
  size : int;
  operation : int;
  timestamp : int64;
}

let get_u8 bytes off = Char.code (Bytes.get bytes off)

let get_u16 bytes off = get_u8 bytes off lor (get_u8 bytes (off + 1) lsl 8)

let get_i32 bytes off =
  let open Int32 in
  logor
    (of_int (get_u8 bytes off))
    (logor
       (shift_left (of_int (get_u8 bytes (off + 1))) 8)
       (logor
          (shift_left (of_int (get_u8 bytes (off + 2))) 16)
          (shift_left (of_int (get_u8 bytes (off + 3))) 24)))

let get_i64 bytes off =
  let open Int64 in
  let v = ref 0L in
  for i = 0 to 7 do
    v := logor !v (shift_left (of_int (get_u8 bytes (off + i))) (8 * i))
  done;
  !v

let set_u8 bytes off v = Bytes.set bytes off (Char.chr (v land 0xFF))

let set_u16 bytes off v =
  set_u8 bytes off v;
  set_u8 bytes (off + 1) (v lsr 8)

let set_i32 bytes off v =
  let open Int32 in
  for i = 0 to 3 do
    set_u8 bytes (off + i) (to_int (logand (shift_right_logical v (8 * i)) 0xFFl))
  done

let set_i64 bytes off v =
  let open Int64 in
  for i = 0 to 7 do
    set_u8 bytes (off + i) (to_int (logand (shift_right_logical v (8 * i)) 0xFFL))
  done

let set_u128 bytes off v =
  let raw = U128.to_le_bytes v in
  Bytes.blit raw 0 bytes off 16

let parse_request_header bytes =
  if Bytes.length bytes <> header_size then invalid_arg "Codec.parse_request_header";
  {
    checksum = U128.of_le_bytes bytes 0;
    cluster = U128.of_le_bytes bytes 80;
    size =
      Int32.to_int
        Int32.(logand (get_i32 bytes 96) 0x7FFF_FFFFl);
    release = get_i32 bytes 108;
    command = get_u8 bytes 114;
    client = U128.of_le_bytes bytes 160;
    session = get_i64 bytes 176;
    timestamp = get_i64 bytes 184;
    request = get_i32 bytes 192;
    operation = get_u8 bytes 196;
  }

let parse_reply_header bytes =
  if Bytes.length bytes <> header_size then invalid_arg "Codec.parse_reply_header";
  { size = Int32.to_int Int32.(logand (get_i32 bytes 96) 0x7FFF_FFFFl); operation = get_u8 bytes 236; timestamp = get_i64 bytes 224 }

let decode_account bytes off =
  {
    id = U128.of_le_bytes bytes off;
    debits_pending = U128.of_le_bytes bytes (off + 16);
    debits_posted = U128.of_le_bytes bytes (off + 32);
    credits_pending = U128.of_le_bytes bytes (off + 48);
    credits_posted = U128.of_le_bytes bytes (off + 64);
    user_data_128 = U128.of_le_bytes bytes (off + 80);
    user_data_64 = get_i64 bytes (off + 96);
    user_data_32 = get_i32 bytes (off + 104);
    ledger = get_i32 bytes (off + 112);
    code = get_u16 bytes (off + 116);
    flags = get_u16 bytes (off + 118);
    timestamp = get_i64 bytes (off + 120);
  }

let encode_account (a : account) =
  let out = Bytes.make account_size '\x00' in
  set_u128 out 0 a.id;
  set_u128 out 16 a.debits_pending;
  set_u128 out 32 a.debits_posted;
  set_u128 out 48 a.credits_pending;
  set_u128 out 64 a.credits_posted;
  set_u128 out 80 a.user_data_128;
  set_i64 out 96 a.user_data_64;
  set_i32 out 104 a.user_data_32;
  set_i32 out 112 a.ledger;
  set_u16 out 116 a.code;
  set_u16 out 118 a.flags;
  set_i64 out 120 a.timestamp;
  out

let decode_transfer bytes off =
  {
    id = U128.of_le_bytes bytes off;
    debit_account_id = U128.of_le_bytes bytes (off + 16);
    credit_account_id = U128.of_le_bytes bytes (off + 32);
    amount = U128.of_le_bytes bytes (off + 48);
    pending_id = U128.of_le_bytes bytes (off + 64);
    user_data_128 = U128.of_le_bytes bytes (off + 80);
    user_data_64 = get_i64 bytes (off + 96);
    user_data_32 = get_i32 bytes (off + 104);
    timeout = get_i32 bytes (off + 108);
    ledger = get_i32 bytes (off + 112);
    code = get_u16 bytes (off + 116);
    flags = get_u16 bytes (off + 118);
    timestamp = get_i64 bytes (off + 120);
  }

let encode_transfer (t : transfer) =
  let out = Bytes.make transfer_size '\x00' in
  set_u128 out 0 t.id;
  set_u128 out 16 t.debit_account_id;
  set_u128 out 32 t.credit_account_id;
  set_u128 out 48 t.amount;
  set_u128 out 64 t.pending_id;
  set_u128 out 80 t.user_data_128;
  set_i64 out 96 t.user_data_64;
  set_i32 out 104 t.user_data_32;
  set_i32 out 108 t.timeout;
  set_i32 out 112 t.ledger;
  set_u16 out 116 t.code;
  set_u16 out 118 t.flags;
  set_i64 out 120 t.timestamp;
  out

let decode_id_batch bytes =
  let count = Bytes.length bytes / id_size in
  Array.init count (fun i -> U128.of_le_bytes bytes (i * id_size)) |> Array.to_list

let encode_id id = U128.to_le_bytes id

let decode_account_filter bytes =
  {
    account_id = U128.of_le_bytes bytes 0;
    user_data_128 = U128.of_le_bytes bytes 16;
    user_data_64 = get_i64 bytes 32;
    user_data_32 = get_i32 bytes 40;
    code = get_u16 bytes 44;
    timestamp_min = get_i64 bytes 104;
    timestamp_max = get_i64 bytes 112;
    limit = get_i32 bytes 120;
    flags = get_i32 bytes 124;
  }

let decode_query_filter bytes =
  {
    user_data_128 = U128.of_le_bytes bytes 0;
    user_data_64 = get_i64 bytes 16;
    user_data_32 = get_i32 bytes 24;
    ledger = get_i32 bytes 28;
    code = get_u16 bytes 32;
    timestamp_min = get_i64 bytes 40;
    timestamp_max = get_i64 bytes 48;
    limit = get_i32 bytes 56;
    flags = get_i32 bytes 60;
  }

let encode_account_balance (b : account_balance) =
  let out = Bytes.make account_balance_size '\x00' in
  set_u128 out 0 b.debits_pending;
  set_u128 out 16 b.debits_posted;
  set_u128 out 32 b.credits_pending;
  set_u128 out 48 b.credits_posted;
  set_i64 out 64 b.timestamp;
  out

let encode_account_filter f =
  let out = Bytes.make account_filter_size '\x00' in
  set_u128 out 0 f.account_id;
  set_u128 out 16 f.user_data_128;
  set_i64 out 32 f.user_data_64;
  set_i32 out 40 f.user_data_32;
  set_u16 out 44 f.code;
  set_i64 out 104 f.timestamp_min;
  set_i64 out 112 f.timestamp_max;
  set_i32 out 120 f.limit;
  set_i32 out 124 f.flags;
  out

let encode_query_filter f =
  let out = Bytes.make query_filter_size '\x00' in
  set_u128 out 0 f.user_data_128;
  set_i64 out 16 f.user_data_64;
  set_i32 out 24 f.user_data_32;
  set_i32 out 28 f.ledger;
  set_u16 out 32 f.code;
  set_i64 out 40 f.timestamp_min;
  set_i64 out 48 f.timestamp_max;
  set_i32 out 56 f.limit;
  set_i32 out 60 f.flags;
  out

let encode_create_result (r : create_result) =
  let out = Bytes.make create_result_size '\x00' in
  set_i64 out 0 r.timestamp;
  set_i32 out 8 r.status;
  out

let encode_create_results results =
  let out = Bytes.make (List.length results * create_result_size) '\x00' in
  List.iteri
    (fun i r -> Bytes.blit (encode_create_result r) 0 out (i * create_result_size) create_result_size)
    results;
  out

let encode_accounts accounts =
  let out = Bytes.make (List.length accounts * account_size) '\x00' in
  List.iteri
    (fun i a -> Bytes.blit (encode_account a) 0 out (i * account_size) account_size)
    accounts;
  out

let encode_transfers transfers =
  let out = Bytes.make (List.length transfers * transfer_size) '\x00' in
  List.iteri
    (fun i t -> Bytes.blit (encode_transfer t) 0 out (i * transfer_size) transfer_size)
    transfers;
  out

let encode_balances balances =
  let out = Bytes.make (List.length balances * account_balance_size) '\x00' in
  List.iteri
    (fun i b ->
      Bytes.blit (encode_account_balance b) 0 out (i * account_balance_size) account_balance_size)
    balances;
  out

let encode_register_result () =
  let out = Bytes.make register_result_size '\x00' in
  set_i32 out 0 (Int32.of_int batch_size_limit);
  out

let make_reply_header ~request_header ~body ~commit ~timestamp ~operation ~context =
  let header = Bytes.make header_size '\x00' in
  set_u128 header 80 request_header.cluster;
  set_i32 header 96 (Int32.of_int (header_size + Bytes.length body));
  set_i32 header 104 0l;
  set_i32 header 108 request_header.release;
  set_u16 header 112 0;
  set_u8 header 114 command_reply;
  set_u8 header 115 0;
  set_u128 header 128 request_header.checksum;
  set_u128 header 160 context;
  set_u128 header 192 request_header.client;
  set_i64 header 208 commit;
  set_i64 header 216 commit;
  set_i64 header 224 timestamp;
  set_i32 header 232 request_header.request;
  set_u8 header 236 operation;
  let checksum_body = Checksum.compute body in
  set_u128 header 32 checksum_body;
  let checksum = Checksum.compute (Bytes.sub header 16 (header_size - 16)) in
  set_u128 header 0 checksum;
  header

let make_reply ~request_header ~body ~commit ~timestamp ~operation ~context =
  let header = make_reply_header ~request_header ~body ~commit ~timestamp ~operation ~context in
  Bytes.cat header body
