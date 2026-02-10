open Tiger_core.Types
open Tiger_core.Requests

let account_wire_size = Request_codec.account_wire_size
let transfer_wire_size = Request_codec.transfer_wire_size
let create_result_wire_size = 8
let account_balance_wire_size = 128
let change_event_wire_size = 384

let put_uint128 buf off (v : u128) =
  Cstruct.LE.set_uint64 buf off v.lo;
  Cstruct.LE.set_uint64 buf (off + 8) v.hi

let get_uint128 buf off : u128 =
  let lo = Cstruct.LE.get_uint64 buf off in
  let hi = Cstruct.LE.get_uint64 buf (off + 8) in
  { hi; lo }

let put_account_id buf off id = put_uint128 buf off (account_id_to_u128 id)
let put_transfer_id buf off id = put_uint128 buf off (transfer_id_to_u128 id)

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

let encode_create_accounts_result buf off (r : create_accounts_result) =
  Cstruct.LE.set_uint32 buf off r.index;
  Cstruct.LE.set_uint32 buf (off + 4)
    (Tiger_core.Errors.create_account_result_to_u32 r.result)

let decode_create_accounts_result buf off :
    (create_accounts_result, string) result =
  let result_raw = Cstruct.LE.get_uint32 buf (off + 4) in
  match Tiger_core.Errors.create_account_result_of_u32 result_raw with
  | None -> Error "invalid create_account result code"
  | Some result -> Ok { index = Cstruct.LE.get_uint32 buf off; result }

let encode_create_transfers_result buf off (r : create_transfers_result) =
  Cstruct.LE.set_uint32 buf off r.index;
  Cstruct.LE.set_uint32 buf (off + 4)
    (Tiger_core.Errors.create_transfer_result_to_u32 r.result)

let decode_create_transfers_result buf off :
    (create_transfers_result, string) result =
  let result_raw = Cstruct.LE.get_uint32 buf (off + 4) in
  match Tiger_core.Errors.create_transfer_result_of_u32 result_raw with
  | None -> Error "invalid create_transfer result code"
  | Some result -> Ok { index = Cstruct.LE.get_uint32 buf off; result }

let encode_account_balance buf off (b : account_balance) =
  put_uint128 buf off b.debits_pending;
  put_uint128 buf (off + 16) b.debits_posted;
  put_uint128 buf (off + 32) b.credits_pending;
  put_uint128 buf (off + 48) b.credits_posted;
  Cstruct.LE.set_uint64 buf (off + 64) b.timestamp;
  Cstruct.blit_from_bytes b.reserved 0 buf (off + 72) 56

let decode_account_balance buf off : (account_balance, string) result =
  let reserved = Bytes.create 56 in
  Cstruct.blit_to_bytes buf (off + 72) reserved 0 56;
  Ok
    {
      debits_pending = get_uint128 buf off;
      debits_posted = get_uint128 buf (off + 16);
      credits_pending = get_uint128 buf (off + 32);
      credits_posted = get_uint128 buf (off + 48);
      timestamp = Cstruct.LE.get_uint64 buf (off + 64);
      reserved;
    }

let encode_change_event buf off (e : change_event) =
  put_uint128 buf off e.transfer_id;
  put_uint128 buf (off + 16) e.transfer_amount;
  put_uint128 buf (off + 32) e.transfer_pending_id;
  put_uint128 buf (off + 48) e.transfer_user_data_128;
  Cstruct.LE.set_uint64 buf (off + 64) e.transfer_user_data_64;
  Cstruct.LE.set_uint32 buf (off + 72) e.transfer_user_data_32;
  Cstruct.LE.set_uint32 buf (off + 76) e.transfer_timeout;
  Cstruct.LE.set_uint16 buf (off + 80) e.transfer_code;
  Cstruct.LE.set_uint16 buf (off + 82) (transfer_flags_to_int e.transfer_flags);
  Cstruct.LE.set_uint32 buf (off + 84) e.ledger;
  Cstruct.set_uint8 buf (off + 88) (change_event_type_to_u8 e.event_type);
  Cstruct.blit_from_bytes e.reserved 0 buf (off + 89) 39;
  put_uint128 buf (off + 128) e.debit_account_id;
  put_uint128 buf (off + 144) e.debit_account_debits_pending;
  put_uint128 buf (off + 160) e.debit_account_debits_posted;
  put_uint128 buf (off + 176) e.debit_account_credits_pending;
  put_uint128 buf (off + 192) e.debit_account_credits_posted;
  put_uint128 buf (off + 208) e.debit_account_user_data_128;
  Cstruct.LE.set_uint64 buf (off + 224) e.debit_account_user_data_64;
  Cstruct.LE.set_uint32 buf (off + 232) e.debit_account_user_data_32;
  Cstruct.LE.set_uint16 buf (off + 236) e.debit_account_code;
  Cstruct.LE.set_uint16 buf (off + 238) (account_flags_to_int e.debit_account_flags);
  put_uint128 buf (off + 240) e.credit_account_id;
  put_uint128 buf (off + 256) e.credit_account_debits_pending;
  put_uint128 buf (off + 272) e.credit_account_debits_posted;
  put_uint128 buf (off + 288) e.credit_account_credits_pending;
  put_uint128 buf (off + 304) e.credit_account_credits_posted;
  put_uint128 buf (off + 320) e.credit_account_user_data_128;
  Cstruct.LE.set_uint64 buf (off + 336) e.credit_account_user_data_64;
  Cstruct.LE.set_uint32 buf (off + 344) e.credit_account_user_data_32;
  Cstruct.LE.set_uint16 buf (off + 348) e.credit_account_code;
  Cstruct.LE.set_uint16 buf (off + 350) (account_flags_to_int e.credit_account_flags);
  Cstruct.LE.set_uint64 buf (off + 352) e.timestamp;
  Cstruct.LE.set_uint64 buf (off + 360) e.transfer_timestamp;
  Cstruct.LE.set_uint64 buf (off + 368) e.debit_account_timestamp;
  Cstruct.LE.set_uint64 buf (off + 376) e.credit_account_timestamp

let decode_change_event buf off : (change_event, string) result =
  let event_type_raw = Cstruct.get_uint8 buf (off + 88) in
  let transfer_flags_raw = Cstruct.LE.get_uint16 buf (off + 82) in
  let debit_flags_raw = Cstruct.LE.get_uint16 buf (off + 238) in
  let credit_flags_raw = Cstruct.LE.get_uint16 buf (off + 350) in
  match
    change_event_type_of_u8 event_type_raw,
    transfer_flags_of_u16 transfer_flags_raw,
    account_flags_of_u16 debit_flags_raw,
    account_flags_of_u16 credit_flags_raw
  with
  | Some event_type, Ok transfer_flags, Ok debit_account_flags, Ok credit_account_flags ->
    let reserved = Bytes.create 39 in
    Cstruct.blit_to_bytes buf (off + 89) reserved 0 39;
    Ok
      {
        transfer_id = get_uint128 buf off;
        transfer_amount = get_uint128 buf (off + 16);
        transfer_pending_id = get_uint128 buf (off + 32);
        transfer_user_data_128 = get_uint128 buf (off + 48);
        transfer_user_data_64 = Cstruct.LE.get_uint64 buf (off + 64);
        transfer_user_data_32 = Cstruct.LE.get_uint32 buf (off + 72);
        transfer_timeout = Cstruct.LE.get_uint32 buf (off + 76);
        transfer_code = Cstruct.LE.get_uint16 buf (off + 80);
        transfer_flags;
        ledger = Cstruct.LE.get_uint32 buf (off + 84);
        event_type;
        reserved;
        debit_account_id = get_uint128 buf (off + 128);
        debit_account_debits_pending = get_uint128 buf (off + 144);
        debit_account_debits_posted = get_uint128 buf (off + 160);
        debit_account_credits_pending = get_uint128 buf (off + 176);
        debit_account_credits_posted = get_uint128 buf (off + 192);
        debit_account_user_data_128 = get_uint128 buf (off + 208);
        debit_account_user_data_64 = Cstruct.LE.get_uint64 buf (off + 224);
        debit_account_user_data_32 = Cstruct.LE.get_uint32 buf (off + 232);
        debit_account_code = Cstruct.LE.get_uint16 buf (off + 236);
        debit_account_flags;
        credit_account_id = get_uint128 buf (off + 240);
        credit_account_debits_pending = get_uint128 buf (off + 256);
        credit_account_debits_posted = get_uint128 buf (off + 272);
        credit_account_credits_pending = get_uint128 buf (off + 288);
        credit_account_credits_posted = get_uint128 buf (off + 304);
        credit_account_user_data_128 = get_uint128 buf (off + 320);
        credit_account_user_data_64 = Cstruct.LE.get_uint64 buf (off + 336);
        credit_account_user_data_32 = Cstruct.LE.get_uint32 buf (off + 344);
        credit_account_code = Cstruct.LE.get_uint16 buf (off + 348);
        credit_account_flags;
        timestamp = Cstruct.LE.get_uint64 buf (off + 352);
        transfer_timestamp = Cstruct.LE.get_uint64 buf (off + 360);
        debit_account_timestamp = Cstruct.LE.get_uint64 buf (off + 368);
        credit_account_timestamp = Cstruct.LE.get_uint64 buf (off + 376);
      }
  | None, _, _, _ -> Error "invalid change_event_type"
  | _, Error _, _, _ -> Error "invalid transfer flags"
  | _, _, Error _, _ -> Error "invalid debit account flags"
  | _, _, _, Error _ -> Error "invalid credit account flags"

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

let response_command (resp : response) =
  match resp with
  | Create_accounts_result _ -> Cmd_create_accounts
  | Create_transfers_result _ -> Cmd_create_transfers
  | Lookup_accounts_result _ -> Cmd_lookup_accounts
  | Lookup_transfers_result _ -> Cmd_lookup_transfers
  | Get_account_transfers_result _ -> Cmd_get_account_transfers
  | Get_account_balances_result _ -> Cmd_get_account_balances
  | Query_accounts_result _ -> Cmd_query_accounts
  | Query_transfers_result _ -> Cmd_query_transfers
  | Get_change_events_result _ -> Cmd_get_change_events

let encode_payload (resp : response) : Cstruct.t =
  match resp with
  | Create_accounts_result items ->
    encode_list items create_result_wire_size encode_create_accounts_result
  | Create_transfers_result items ->
    encode_list items create_result_wire_size encode_create_transfers_result
  | Lookup_accounts_result items ->
    encode_list items account_wire_size encode_account
  | Lookup_transfers_result items ->
    encode_list items transfer_wire_size encode_transfer
  | Get_account_transfers_result items ->
    encode_list items transfer_wire_size encode_transfer
  | Get_account_balances_result items ->
    encode_list items account_balance_wire_size encode_account_balance
  | Query_accounts_result items ->
    encode_list items account_wire_size encode_account
  | Query_transfers_result items ->
    encode_list items transfer_wire_size encode_transfer
  | Get_change_events_result items ->
    encode_list items change_event_wire_size encode_change_event

let decode_payload (cmd : command) (buf : Cstruct.t) : (response, string) result =
  match cmd with
  | Cmd_create_accounts ->
    (match decode_list buf create_result_wire_size decode_create_accounts_result with
     | Ok items -> Ok (Create_accounts_result items)
     | Error e -> Error e)
  | Cmd_create_transfers ->
    (match decode_list buf create_result_wire_size decode_create_transfers_result with
     | Ok items -> Ok (Create_transfers_result items)
     | Error e -> Error e)
  | Cmd_lookup_accounts ->
    (match decode_list buf account_wire_size decode_account with
     | Ok items -> Ok (Lookup_accounts_result items)
     | Error e -> Error e)
  | Cmd_lookup_transfers ->
    (match decode_list buf transfer_wire_size decode_transfer with
     | Ok items -> Ok (Lookup_transfers_result items)
     | Error e -> Error e)
  | Cmd_get_account_transfers ->
    (match decode_list buf transfer_wire_size decode_transfer with
     | Ok items -> Ok (Get_account_transfers_result items)
     | Error e -> Error e)
  | Cmd_get_account_balances ->
    (match decode_list buf account_balance_wire_size decode_account_balance with
     | Ok items -> Ok (Get_account_balances_result items)
     | Error e -> Error e)
  | Cmd_query_accounts ->
    (match decode_list buf account_wire_size decode_account with
     | Ok items -> Ok (Query_accounts_result items)
     | Error e -> Error e)
  | Cmd_query_transfers ->
    (match decode_list buf transfer_wire_size decode_transfer with
     | Ok items -> Ok (Query_transfers_result items)
     | Error e -> Error e)
  | Cmd_get_change_events ->
    (match decode_list buf change_event_wire_size decode_change_event with
     | Ok items -> Ok (Get_change_events_result items)
     | Error e -> Error e)

let encode_response (resp : response) : Cstruct.t =
  let payload = encode_payload resp in
  let command = response_command resp in
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

let decode_response (frame : Cstruct.t) : (response, string) result =
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
