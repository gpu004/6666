(* request_codec.ml — Binary encoding/decoding for request payloads *)

open Tiger_core.Types
open Tiger_core.Requests

let account_wire_size = 128
let transfer_wire_size = 128
let id_wire_size = 16
let account_filter_wire_size = 128
let query_filter_wire_size = 64
let change_events_filter_wire_size = 64

let put_uint128 buf off (v : uint128) =
  Cstruct.LE.set_uint64 buf off v.lo;
  Cstruct.LE.set_uint64 buf (off + 8) v.hi

let get_uint128 buf off : uint128 =
  let lo = Cstruct.LE.get_uint64 buf off in
  let hi = Cstruct.LE.get_uint64 buf (off + 8) in
  { hi; lo }

let put_account_id buf off id =
  put_uint128 buf off (account_id_to_u128 id)

let put_transfer_id buf off id =
  put_uint128 buf off (transfer_id_to_u128 id)

let get_account_id buf off =
  let v = get_uint128 buf off in
  match account_id_of_u128 v with
  | Ok id -> Ok id
  | Error _ -> Error "invalid account id"

let encode_account buf off (a : account) =
  put_account_id buf off a.id;
  put_uint128 buf (off + 16) a.debits_pending;
  put_uint128 buf (off + 32) a.debits_posted;
  put_uint128 buf (off + 48) a.credits_pending;
  put_uint128 buf (off + 64) a.credits_posted;
  put_uint128 buf (off + 80) a.user_data_128;
  Cstruct.LE.set_uint64 buf (off + 96) a.user_data_64;
  Cstruct.LE.set_uint32 buf (off + 104) a.user_data_32;
  Cstruct.LE.set_uint32 buf (off + 108) a.reserved;
  Cstruct.LE.set_uint32 buf (off + 112) (ledger_to_int32 a.ledger);
  Cstruct.LE.set_uint16 buf (off + 116) (code_to_int a.code);
  Cstruct.LE.set_uint16 buf (off + 118) (account_flags_to_int a.flags);
  Cstruct.LE.set_uint64 buf (off + 120) a.timestamp

let decode_account buf off : (account, string) result =
  match get_account_id buf off with
  | Error e -> Error e
  | Ok id ->
    let ledger_raw = Cstruct.LE.get_uint32 buf (off + 112) in
    (match ledger_of_int32 ledger_raw with
     | Error e -> Error e
     | Ok ledger ->
       let code_raw = Cstruct.LE.get_uint16 buf (off + 116) in
       (match code_of_int code_raw with
        | Error e -> Error e
        | Ok code ->
          let flags_raw = Cstruct.LE.get_uint16 buf (off + 118) in
          (match account_flags_of_u16 flags_raw with
           | Error _ -> Error "invalid account flags"
           | Ok flags ->
             Ok
               {
                 id;
                 debits_pending = get_uint128 buf (off + 16);
                 debits_posted = get_uint128 buf (off + 32);
                 credits_pending = get_uint128 buf (off + 48);
                 credits_posted = get_uint128 buf (off + 64);
                 user_data_128 = get_uint128 buf (off + 80);
                 user_data_64 = Cstruct.LE.get_uint64 buf (off + 96);
                 user_data_32 = Cstruct.LE.get_uint32 buf (off + 104);
                 reserved = Cstruct.LE.get_uint32 buf (off + 108);
                 ledger;
                 code;
                 flags;
                 timestamp = Cstruct.LE.get_uint64 buf (off + 120);
               })))

let encode_transfer buf off (t : transfer) =
  put_transfer_id buf off t.id;
  put_account_id buf (off + 16) t.debit_account_id;
  put_account_id buf (off + 32) t.credit_account_id;
  put_uint128 buf (off + 48) (amount_to_u128 t.amount);
  put_uint128 buf (off + 64) t.pending_id;
  put_uint128 buf (off + 80) t.user_data_128;
  Cstruct.LE.set_uint64 buf (off + 96) t.user_data_64;
  Cstruct.LE.set_uint32 buf (off + 104) t.user_data_32;
  Cstruct.LE.set_uint32 buf (off + 108) t.timeout;
  Cstruct.LE.set_uint32 buf (off + 112) (ledger_to_int32 t.ledger);
  Cstruct.LE.set_uint16 buf (off + 116) (code_to_int t.code);
  Cstruct.LE.set_uint16 buf (off + 118) (transfer_flags_to_int t.flags);
  Cstruct.LE.set_uint64 buf (off + 120) t.timestamp

let decode_transfer buf off : (transfer, string) result =
  let id_raw = get_uint128 buf off in
  let debit_raw = get_uint128 buf (off + 16) in
  let credit_raw = get_uint128 buf (off + 32) in
  match
    transfer_id_of_u128 id_raw,
    account_id_of_u128 debit_raw,
    account_id_of_u128 credit_raw
  with
  | Ok id, Ok debit_account_id, Ok credit_account_id ->
    let ledger_raw = Cstruct.LE.get_uint32 buf (off + 112) in
    (match ledger_of_int32 ledger_raw with
     | Error e -> Error e
     | Ok ledger ->
       let code_raw = Cstruct.LE.get_uint16 buf (off + 116) in
       (match code_of_int code_raw with
        | Error e -> Error e
        | Ok code ->
          let flags_raw = Cstruct.LE.get_uint16 buf (off + 118) in
          (match transfer_flags_of_u16 flags_raw with
           | Error _ -> Error "invalid transfer flags"
           | Ok flags -> (
             match amount_of_u128 (get_uint128 buf (off + 48)) with
             | Error _ -> Error "invalid transfer amount"
             | Ok amount ->
               Ok
                 {
                   id;
                   debit_account_id;
                   credit_account_id;
                   amount;
                   pending_id = get_uint128 buf (off + 64);
                   user_data_128 = get_uint128 buf (off + 80);
                   user_data_64 = Cstruct.LE.get_uint64 buf (off + 96);
                   user_data_32 = Cstruct.LE.get_uint32 buf (off + 104);
                   timeout = Cstruct.LE.get_uint32 buf (off + 108);
                   ledger;
                   code;
                   flags;
                   timestamp = Cstruct.LE.get_uint64 buf (off + 120);
                 }))))
  | Error _, _, _ | _, Error _, _ | _, _, Error _ -> Error "invalid transfer ids"

let encode_account_filter buf off (f : account_filter) =
  put_uint128 buf off f.account_id;
  put_uint128 buf (off + 16) f.user_data_128;
  Cstruct.LE.set_uint64 buf (off + 32) f.user_data_64;
  Cstruct.LE.set_uint32 buf (off + 40) f.user_data_32;
  Cstruct.LE.set_uint16 buf (off + 44) f.code;
  Cstruct.blit_from_bytes f.reserved 0 buf (off + 46) 58;
  Cstruct.LE.set_uint64 buf (off + 104) f.timestamp_min;
  Cstruct.LE.set_uint64 buf (off + 112) f.timestamp_max;
  Cstruct.LE.set_uint32 buf (off + 120) f.limit;
  Cstruct.LE.set_uint32 buf (off + 124) (account_filter_flags_to_u32 f.flags)

let decode_account_filter buf off : (account_filter, string) result =
  let reserved = Bytes.create 58 in
  Cstruct.blit_to_bytes buf (off + 46) reserved 0 58;
  match account_filter_flags_of_u32 (Cstruct.LE.get_uint32 buf (off + 124)) with
  | Error _ -> Error "invalid account_filter flags"
  | Ok flags ->
    Ok
      {
        account_id = get_uint128 buf off;
        user_data_128 = get_uint128 buf (off + 16);
        user_data_64 = Cstruct.LE.get_uint64 buf (off + 32);
        user_data_32 = Cstruct.LE.get_uint32 buf (off + 40);
        code = Cstruct.LE.get_uint16 buf (off + 44);
        reserved;
        timestamp_min = Cstruct.LE.get_uint64 buf (off + 104);
        timestamp_max = Cstruct.LE.get_uint64 buf (off + 112);
        limit = Cstruct.LE.get_uint32 buf (off + 120);
        flags;
      }

let encode_query_filter buf off (f : query_filter) =
  put_uint128 buf off f.user_data_128;
  Cstruct.LE.set_uint64 buf (off + 16) f.user_data_64;
  Cstruct.LE.set_uint32 buf (off + 24) f.user_data_32;
  Cstruct.LE.set_uint32 buf (off + 28) f.ledger;
  Cstruct.LE.set_uint16 buf (off + 32) f.code;
  Cstruct.blit_from_bytes f.reserved 0 buf (off + 34) 6;
  Cstruct.LE.set_uint64 buf (off + 40) f.timestamp_min;
  Cstruct.LE.set_uint64 buf (off + 48) f.timestamp_max;
  Cstruct.LE.set_uint32 buf (off + 56) f.limit;
  Cstruct.LE.set_uint32 buf (off + 60) (query_filter_flags_to_u32 f.flags)

let decode_query_filter buf off : (query_filter, string) result =
  let reserved = Bytes.create 6 in
  Cstruct.blit_to_bytes buf (off + 34) reserved 0 6;
  match query_filter_flags_of_u32 (Cstruct.LE.get_uint32 buf (off + 60)) with
  | Error _ -> Error "invalid query_filter flags"
  | Ok flags ->
    Ok
      {
        user_data_128 = get_uint128 buf off;
        user_data_64 = Cstruct.LE.get_uint64 buf (off + 16);
        user_data_32 = Cstruct.LE.get_uint32 buf (off + 24);
        ledger = Cstruct.LE.get_uint32 buf (off + 28);
        code = Cstruct.LE.get_uint16 buf (off + 32);
        reserved;
        timestamp_min = Cstruct.LE.get_uint64 buf (off + 40);
        timestamp_max = Cstruct.LE.get_uint64 buf (off + 48);
        limit = Cstruct.LE.get_uint32 buf (off + 56);
        flags;
      }

let encode_change_events_filter buf off (f : change_events_filter) =
  Cstruct.LE.set_uint64 buf off f.timestamp_min;
  Cstruct.LE.set_uint64 buf (off + 8) f.timestamp_max;
  Cstruct.LE.set_uint32 buf (off + 16) f.limit;
  Cstruct.blit_from_bytes f.reserved 0 buf (off + 20) 44

let decode_change_events_filter buf off : change_events_filter =
  let reserved = Bytes.create 44 in
  Cstruct.blit_to_bytes buf (off + 20) reserved 0 44;
  {
    timestamp_min = Cstruct.LE.get_uint64 buf off;
    timestamp_max = Cstruct.LE.get_uint64 buf (off + 8);
    limit = Cstruct.LE.get_uint32 buf (off + 16);
    reserved;
  }

let encode_list items item_size encode_fn =
  let n = List.length items in
  let buf = Cstruct.create (n * item_size) in
  Cstruct.memset buf 0;
  List.iteri (fun i item -> encode_fn buf (i * item_size) item) items;
  buf

let decode_list buf item_size decode_fn =
  let len = Cstruct.length buf in
  if len mod item_size <> 0 then Error "payload size not aligned to item size"
  else
    let n = len / item_size in
    let rec aux acc i =
      if i < 0 then Ok (List.rev acc)
      else
        match decode_fn buf (i * item_size) with
        | Ok item -> aux (item :: acc) (i - 1)
        | Error e -> Error (Printf.sprintf "item %d: %s" i e)
    in
    aux [] (n - 1)

let decode_id_list buf =
  let len = Cstruct.length buf in
  if len mod id_wire_size <> 0 then Error "payload size not aligned to id size"
  else
    let n = len / id_wire_size in
    let rec aux acc i =
      if i < 0 then Ok (List.rev acc)
      else aux (get_uint128 buf (i * id_wire_size) :: acc) (i - 1)
    in
    aux [] (n - 1)

let encode_payload (req : request) : Cstruct.t =
  match req with
  | Create_accounts accounts -> encode_list accounts account_wire_size encode_account
  | Create_transfers transfers ->
    encode_list transfers transfer_wire_size encode_transfer
  | Lookup_accounts ids -> encode_list ids id_wire_size put_uint128
  | Lookup_transfers ids -> encode_list ids id_wire_size put_uint128
  | Get_account_transfers f ->
    let buf = Cstruct.create account_filter_wire_size in
    Cstruct.memset buf 0;
    encode_account_filter buf 0 f;
    buf
  | Get_account_balances f ->
    let buf = Cstruct.create account_filter_wire_size in
    Cstruct.memset buf 0;
    encode_account_filter buf 0 f;
    buf
  | Query_accounts f ->
    let buf = Cstruct.create query_filter_wire_size in
    Cstruct.memset buf 0;
    encode_query_filter buf 0 f;
    buf
  | Query_transfers f ->
    let buf = Cstruct.create query_filter_wire_size in
    Cstruct.memset buf 0;
    encode_query_filter buf 0 f;
    buf
  | Get_change_events f ->
    let buf = Cstruct.create change_events_filter_wire_size in
    Cstruct.memset buf 0;
    encode_change_events_filter buf 0 f;
    buf

let decode_payload (cmd : command) (buf : Cstruct.t) : (request, string) result =
  match cmd with
  | Cmd_create_accounts ->
    (match decode_list buf account_wire_size decode_account with
     | Ok accounts -> Ok (Create_accounts accounts)
     | Error e -> Error e)
  | Cmd_create_transfers ->
    (match decode_list buf transfer_wire_size decode_transfer with
     | Ok transfers -> Ok (Create_transfers transfers)
     | Error e -> Error e)
  | Cmd_lookup_accounts ->
    (match decode_id_list buf with
     | Ok ids -> Ok (Lookup_accounts ids)
     | Error e -> Error e)
  | Cmd_lookup_transfers ->
    (match decode_id_list buf with
     | Ok ids -> Ok (Lookup_transfers ids)
     | Error e -> Error e)
  | Cmd_get_account_transfers ->
    if Cstruct.length buf <> account_filter_wire_size then
      Error "invalid account_filter size"
    else
      (match decode_account_filter buf 0 with
       | Ok f -> Ok (Get_account_transfers f)
       | Error e -> Error e)
  | Cmd_get_account_balances ->
    if Cstruct.length buf <> account_filter_wire_size then
      Error "invalid account_filter size"
    else
      (match decode_account_filter buf 0 with
       | Ok f -> Ok (Get_account_balances f)
       | Error e -> Error e)
  | Cmd_query_accounts ->
    if Cstruct.length buf <> query_filter_wire_size then
      Error "invalid query_filter size"
    else
      (match decode_query_filter buf 0 with
       | Ok f -> Ok (Query_accounts f)
       | Error e -> Error e)
  | Cmd_query_transfers ->
    if Cstruct.length buf <> query_filter_wire_size then
      Error "invalid query_filter size"
    else
      (match decode_query_filter buf 0 with
       | Ok f -> Ok (Query_transfers f)
       | Error e -> Error e)
  | Cmd_get_change_events ->
    if Cstruct.length buf <> change_events_filter_wire_size then
      Error "invalid change_events_filter size"
    else Ok (Get_change_events (decode_change_events_filter buf 0))

let encode_request (req : request) : Cstruct.t =
  let payload = encode_payload req in
  let command = request_command req in
  let header =
    Header.encode
      {
        Header.cluster = u128_zero;
        epoch = 0l;
        view = 0l;
        release = 0l;
        protocol = 1;
        command;
        replica = 0;
        body_size = Cstruct.length payload;
      }
      ~body:payload
  in
  Cstruct.append header payload

let decode_request (frame : Cstruct.t) : (request, string) result =
  if Cstruct.length frame < Header.header_size then Error "frame too short"
  else
    let header_buf = Cstruct.sub frame 0 Header.header_size in
    match Header.decode header_buf with
    | Error e -> Error e
    | Ok header ->
      let expected_total = Header.header_size + header.body_size in
      if Cstruct.length frame <> expected_total then
        Error "frame size does not match header size field"
      else
        let payload = Cstruct.sub frame Header.header_size header.body_size in
        if not (Header.validate_body ~header_buf ~body:payload) then
          Error "body checksum mismatch"
        else decode_payload header.command payload
