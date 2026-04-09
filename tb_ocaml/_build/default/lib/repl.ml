open Types

type statement =
  | CreateAccounts of account list
  | CreateTransfers of transfer list
  | LookupAccounts of U128.t list
  | LookupTransfers of U128.t list
  | QueryAccounts of query_filter
  | QueryTransfers of query_filter
  | GetAccountTransfers of account_filter
  | GetAccountBalances of account_filter

let trim = String.trim

let split_items s =
  s |> String.split_on_char ',' |> List.map trim |> List.filter (fun x -> x <> "")

let parse_fields item =
  item |> String.split_on_char ' ' |> List.map trim |> List.filter (fun x -> x <> "")

let parse_kv token =
  match String.split_on_char '=' token with
  | [ k; v ] -> (trim k, trim v)
  | _ -> failwith ("invalid token: " ^ token)

let u128 s = U128.of_decimal_string s
let i64 s = Int64.of_string s
let i32 s = Int32.of_string s
let intv s = int_of_string s

let default_account () =
  { id = U128.zero; debits_pending = U128.zero; debits_posted = U128.zero; credits_pending = U128.zero;
    credits_posted = U128.zero; user_data_128 = U128.zero; user_data_64 = 0L; user_data_32 = 0l;
    ledger = 0l; code = 0; flags = 0; timestamp = 0L }

let default_transfer () =
  { id = U128.zero; debit_account_id = U128.zero; credit_account_id = U128.zero; amount = U128.zero;
    pending_id = U128.zero; user_data_128 = U128.zero; user_data_64 = 0L; user_data_32 = 0l;
    timeout = 0l; ledger = 0l; code = 0; flags = 0; timestamp = 0L }

let default_account_filter () =
  {
    account_id = U128.zero;
    user_data_128 = U128.zero;
    user_data_64 = 0L;
    user_data_32 = 0l;
    code = 0;
    timestamp_min = 0L;
    timestamp_max = 0L;
    limit = Int32.of_int batch_size_limit;
    flags = Int32.of_int (account_filter_credits lor account_filter_debits);
  }

let default_query_filter () =
  { user_data_128 = U128.zero; user_data_64 = 0L; user_data_32 = 0l; ledger = 0l; code = 0;
    timestamp_min = 0L; timestamp_max = 0L; limit = Int32.of_int batch_size_limit; flags = 0l }

let parse_account_flags = function
  | "" -> 0
  | s ->
      s |> String.split_on_char '|'
      |> List.fold_left
           (fun acc part ->
             match trim part with
             | "linked" -> acc lor account_flag_linked
             | "history" -> acc lor account_flag_history
             | "imported" -> acc lor account_flag_imported
             | _ -> acc)
           0

let parse_transfer_flags = function
  | "" -> 0
  | s ->
      s |> String.split_on_char '|'
      |> List.fold_left
           (fun acc part ->
             match trim part with
             | "linked" -> acc lor transfer_flag_linked
             | "pending" -> acc lor transfer_flag_pending
             | "post_pending_transfer" -> acc lor transfer_flag_post_pending_transfer
             | "void_pending_transfer" -> acc lor transfer_flag_void_pending_transfer
             | "closing_debit" -> acc lor transfer_flag_closing_debit
             | "closing_credit" -> acc lor transfer_flag_closing_credit
             | "imported" -> acc lor transfer_flag_imported
             | _ -> acc)
           0

let parse_account_item item =
  List.fold_left
    (fun (a : account) token ->
      let k, v = parse_kv token in
      match k with
      | "id" -> { a with id = u128 v }
      | "user_data_128" -> { a with user_data_128 = u128 v }
      | "user_data_64" -> { a with user_data_64 = i64 v }
      | "user_data_32" -> { a with user_data_32 = i32 v }
      | "ledger" -> { a with ledger = i32 v }
      | "code" -> { a with code = intv v }
      | "flags" -> { a with flags = parse_account_flags v }
      | "timestamp" -> { a with timestamp = i64 v }
      | _ -> a)
    (default_account ()) (parse_fields item)

let parse_transfer_item item =
  List.fold_left
    (fun (tr : transfer) token ->
      let k, v = parse_kv token in
      match k with
      | "id" -> { tr with id = u128 v }
      | "debit_account_id" -> { tr with debit_account_id = u128 v }
      | "credit_account_id" -> { tr with credit_account_id = u128 v }
      | "amount" -> { tr with amount = u128 v }
      | "pending_id" -> { tr with pending_id = u128 v }
      | "user_data_128" -> { tr with user_data_128 = u128 v }
      | "user_data_64" -> { tr with user_data_64 = i64 v }
      | "user_data_32" -> { tr with user_data_32 = i32 v }
      | "timeout" -> { tr with timeout = i32 v }
      | "ledger" -> { tr with ledger = i32 v }
      | "code" -> { tr with code = intv v }
      | "flags" -> { tr with flags = parse_transfer_flags v }
      | "timestamp" -> { tr with timestamp = i64 v }
      | _ -> tr)
    (default_transfer ()) (parse_fields item)

let parse_command s =
  let s = trim s in
  let op, rest =
    match String.split_on_char ' ' s with
    | [] -> failwith "empty command"
    | x :: xs -> (x, String.concat " " xs)
  in
  match op with
  | "create_accounts" -> CreateAccounts (List.map parse_account_item (split_items rest))
  | "create_transfers" -> CreateTransfers (List.map parse_transfer_item (split_items rest))
  | "lookup_accounts" ->
      LookupAccounts (split_items rest |> List.map (fun item -> u128 (snd (parse_kv item))))
  | "lookup_transfers" ->
      LookupTransfers (split_items rest |> List.map (fun item -> u128 (snd (parse_kv item))))
  | "query_accounts" ->
      let f =
        List.fold_left
          (fun q token ->
            let k, v = parse_kv token in
            match k with
            | "user_data_128" -> { q with user_data_128 = u128 v }
            | "user_data_64" -> { q with user_data_64 = i64 v }
            | "user_data_32" -> { q with user_data_32 = i32 v }
            | "ledger" -> { q with ledger = i32 v }
            | "code" -> { q with code = intv v }
            | "timestamp_min" -> { q with timestamp_min = i64 v }
            | "timestamp_max" -> { q with timestamp_max = i64 v }
            | "limit" -> { q with limit = i32 v }
            | "flags" when v = "reversed" -> { q with flags = 1l }
            | _ -> q)
          (default_query_filter ()) (parse_fields rest)
      in
      QueryAccounts f
  | "query_transfers" ->
      let f =
        List.fold_left
          (fun q token ->
            let k, v = parse_kv token in
            match k with
            | "user_data_128" -> { q with user_data_128 = u128 v }
            | "user_data_64" -> { q with user_data_64 = i64 v }
            | "user_data_32" -> { q with user_data_32 = i32 v }
            | "ledger" -> { q with ledger = i32 v }
            | "code" -> { q with code = intv v }
            | "timestamp_min" -> { q with timestamp_min = i64 v }
            | "timestamp_max" -> { q with timestamp_max = i64 v }
            | "limit" -> { q with limit = i32 v }
            | "flags" when v = "reversed" -> { q with flags = 1l }
            | _ -> q)
          (default_query_filter ()) (parse_fields rest)
      in
      QueryTransfers f
  | "get_account_transfers" ->
      let f =
        List.fold_left
          (fun a token ->
            let k, v = parse_kv token in
            match k with
            | "account_id" -> { a with account_id = u128 v }
            | "limit" -> { a with limit = i32 v }
            | "flags" ->
                let flags =
                  v |> String.split_on_char '|'
                  |> List.fold_left
                       (fun acc part ->
                         match trim part with
                         | "credits" -> acc lor account_filter_credits
                         | "debits" -> acc lor account_filter_debits
                         | "reversed" -> acc lor account_filter_reversed
                         | _ -> acc)
                       0
                in
                { a with flags = Int32.of_int flags }
            | "code" -> { a with code = intv v }
            | _ -> a)
          (default_account_filter ()) (parse_fields rest)
      in
      GetAccountTransfers f
  | "get_account_balances" ->
      let f =
        List.fold_left
          (fun a token ->
            let k, v = parse_kv token in
            match k with
            | "account_id" -> { a with account_id = u128 v }
            | "limit" -> { a with limit = i32 v }
            | "flags" ->
                let flags =
                  v |> String.split_on_char '|'
                  |> List.fold_left
                       (fun acc part ->
                         match trim part with
                         | "credits" -> acc lor account_filter_credits
                         | "debits" -> acc lor account_filter_debits
                         | "reversed" -> acc lor account_filter_reversed
                         | _ -> acc)
                       0
                in
                { a with flags = Int32.of_int flags }
            | "code" -> { a with code = intv v }
            | _ -> a)
          (default_account_filter ()) (parse_fields rest)
      in
      GetAccountBalances f
  | _ -> failwith ("unsupported repl operation: " ^ op)

let read_exact_fd fd len =
  let buf = Bytes.create len in
  let rec loop off remaining =
    if remaining = 0 then buf
    else
      let n = Unix.read fd buf off remaining in
      if n = 0 then raise End_of_file else loop (off + n) (remaining - n)
  in
  loop 0 len

let write_all_fd fd buf =
  let rec loop off remaining =
    if remaining > 0 then
      let n = Unix.write fd buf off remaining in
      if n <= 0 then raise End_of_file else loop (off + n) (remaining - n)
  in
  loop 0 (Bytes.length buf)

let make_register_request cluster client_id =
  let header = Bytes.make header_size '\x00' in
  Codec.set_u128 header 80 cluster;
  Codec.set_i32 header 96 (Int32.of_int (header_size + register_request_size));
  Codec.set_i32 header 108 1l;
  Codec.set_u8 header 114 command_request;
  Codec.set_u128 header 160 client_id;
  Codec.set_i32 header 192 0l;
  Codec.set_u8 header 196 op_register;
  let body = Bytes.make register_request_size '\x00' in
  Bytes.cat header body

let make_request cluster client_id session request_num operation body =
  let header = Bytes.make header_size '\x00' in
  Codec.set_u128 header 80 cluster;
  Codec.set_i32 header 96 (Int32.of_int (header_size + Bytes.length body));
  Codec.set_i32 header 108 1l;
  Codec.set_u8 header 114 command_request;
  Codec.set_u128 header 160 client_id;
  Codec.set_i64 header 176 session;
  Codec.set_i32 header 192 (Int32.of_int request_num);
  Codec.set_u8 header 196 operation;
  Bytes.cat header body

let json_of_account (a : account) =
  `Assoc
    [
      ("id", `String (U128.to_string a.id));
      ("debits_pending", `String (U128.to_string a.debits_pending));
      ("debits_posted", `String (U128.to_string a.debits_posted));
      ("credits_pending", `String (U128.to_string a.credits_pending));
      ("credits_posted", `String (U128.to_string a.credits_posted));
      ("user_data_128", `String (U128.to_string a.user_data_128));
      ("user_data_64", `String (Int64.to_string a.user_data_64));
      ("user_data_32", `String (Int32.to_string a.user_data_32));
      ("ledger", `String (Int32.to_string a.ledger));
      ("code", `String (string_of_int a.code));
      ("flags", `List (List.map (fun s -> `String s) (Types.account_flag_names a.flags)));
      ("timestamp", `String (Int64.to_string a.timestamp));
    ]

let json_of_transfer (t : transfer) =
  `Assoc
    [
      ("id", `String (U128.to_string t.id));
      ("debit_account_id", `String (U128.to_string t.debit_account_id));
      ("credit_account_id", `String (U128.to_string t.credit_account_id));
      ("amount", `String (U128.to_string t.amount));
      ("pending_id", `String (U128.to_string t.pending_id));
      ("user_data_128", `String (U128.to_string t.user_data_128));
      ("user_data_64", `String (Int64.to_string t.user_data_64));
      ("user_data_32", `String (Int32.to_string t.user_data_32));
      ("timeout", `String (Int32.to_string t.timeout));
      ("ledger", `String (Int32.to_string t.ledger));
      ("code", `String (string_of_int t.code));
      ("flags", `List (List.map (fun s -> `String s) (Types.transfer_flag_names t.flags)));
      ("timestamp", `String (Int64.to_string t.timestamp));
    ]

let json_of_balance (b : account_balance) =
  `Assoc
    [
      ("debits_pending", `String (U128.to_string b.debits_pending));
      ("debits_posted", `String (U128.to_string b.debits_posted));
      ("credits_pending", `String (U128.to_string b.credits_pending));
      ("credits_posted", `String (U128.to_string b.credits_posted));
      ("timestamp", `String (Int64.to_string b.timestamp));
    ]

let json_of_create_result status_name r =
  `Assoc
    [ ("timestamp", `String (Int64.to_string r.timestamp)); ("status", `String (status_name r.status)) ]

let rec render_json = function
  | `Assoc fields ->
      let lines =
        List.map
          (fun (key, value) -> Printf.sprintf "  %S: %s" key (render_json value))
          fields
      in
      "{\n" ^ String.concat ",\n" lines ^ "\n}"
  | `List values ->
      "[" ^ String.concat "," (List.map render_json values) ^ "]"
  | `String value -> Printf.sprintf "%S" value
  | _ -> failwith "unsupported repl json value"

let print_json json = print_string (render_json json)

let run ~cluster ~address ~command =
  let fd =
    let host, port =
      match String.split_on_char ':' address with
      | [ p ] -> ("127.0.0.1", int_of_string p)
      | [ h; p ] -> (h, int_of_string p)
      | _ -> failwith "invalid address"
    in
    let fd = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
    Unix.connect fd (Unix.ADDR_INET (Unix.inet_addr_of_string host, port));
    fd
  in
  let read_reply fd =
    let header = Codec.parse_reply_header (read_exact_fd fd header_size) in
    let body_len = max 0 (header.size - header_size) in
    let body = if body_len = 0 then Bytes.empty else read_exact_fd fd body_len in
    (header, body)
  in
  let encode_ids ids =
    let out = Bytes.make (List.length ids * id_size) '\x00' in
    List.iteri (fun i id -> Bytes.blit (Codec.encode_id id) 0 out (i * id_size) id_size) ids;
    out
  in
  let client_id = U128.of_int 1 in
  Fun.protect
    ~finally:(fun () -> Unix.close fd)
    (fun () ->
      write_all_fd fd (make_register_request cluster client_id);
      let _register_header, _register_body = read_reply fd in
      let statement = parse_command command in
      let operation, body_payload, result_jsons =
        match statement with
        | CreateAccounts accounts ->
            let payload = Codec.encode_accounts accounts in
            ( op_create_accounts,
              Multibatch.encode ~element_size:account_size [ payload ],
              fun body ->
                Multibatch.decode ~element_size:create_result_size body
                |> List.concat_map (fun batch ->
                       let count = Bytes.length batch / create_result_size in
                       List.init count (fun i ->
                           let r = { timestamp = Codec.get_i64 batch (i * create_result_size); status = Codec.get_i32 batch ((i * create_result_size) + 8) } in
                           json_of_create_result Types.account_status_name r)) )
        | CreateTransfers transfers ->
            let payload = Codec.encode_transfers transfers in
            ( op_create_transfers,
              Multibatch.encode ~element_size:transfer_size [ payload ],
              fun body ->
                Multibatch.decode ~element_size:create_result_size body
                |> List.concat_map (fun batch ->
                       let count = Bytes.length batch / create_result_size in
                       List.init count (fun i ->
                           let r = { timestamp = Codec.get_i64 batch (i * create_result_size); status = Codec.get_i32 batch ((i * create_result_size) + 8) } in
                           json_of_create_result Types.transfer_status_name r)) )
        | LookupAccounts ids ->
            ( op_lookup_accounts,
              Multibatch.encode ~element_size:id_size [ encode_ids ids ],
              fun body ->
                Multibatch.decode ~element_size:account_size body
                |> List.concat_map (fun batch ->
                       let count = Bytes.length batch / account_size in
                       List.init count (fun i -> json_of_account (Codec.decode_account batch (i * account_size)))) )
        | LookupTransfers ids ->
            ( op_lookup_transfers,
              Multibatch.encode ~element_size:id_size [ encode_ids ids ],
              fun body ->
                Multibatch.decode ~element_size:transfer_size body
                |> List.concat_map (fun batch ->
                       let count = Bytes.length batch / transfer_size in
                       List.init count (fun i -> json_of_transfer (Codec.decode_transfer batch (i * transfer_size)))) )
        | QueryAccounts filter ->
            ( op_query_accounts,
              Multibatch.encode ~element_size:query_filter_size [ Codec.encode_query_filter filter ],
              fun body ->
                Multibatch.decode ~element_size:account_size body
                |> List.concat_map (fun batch ->
                       let count = Bytes.length batch / account_size in
                       List.init count (fun i -> json_of_account (Codec.decode_account batch (i * account_size)))) )
        | QueryTransfers filter ->
            ( op_query_transfers,
              Multibatch.encode ~element_size:query_filter_size [ Codec.encode_query_filter filter ],
              fun body ->
                Multibatch.decode ~element_size:transfer_size body
                |> List.concat_map (fun batch ->
                       let count = Bytes.length batch / transfer_size in
                       List.init count (fun i -> json_of_transfer (Codec.decode_transfer batch (i * transfer_size)))) )
        | GetAccountTransfers filter ->
            ( op_get_account_transfers,
              Multibatch.encode ~element_size:account_filter_size [ Codec.encode_account_filter filter ],
              fun body ->
                Multibatch.decode ~element_size:transfer_size body
                |> List.concat_map (fun batch ->
                       let count = Bytes.length batch / transfer_size in
                       List.init count (fun i -> json_of_transfer (Codec.decode_transfer batch (i * transfer_size)))) )
        | GetAccountBalances filter ->
            ( op_get_account_balances,
              Multibatch.encode ~element_size:account_filter_size [ Codec.encode_account_filter filter ],
              fun body ->
                Multibatch.decode ~element_size:account_balance_size body
                |> List.concat_map (fun batch ->
                       let count = Bytes.length batch / account_balance_size in
                       List.init count (fun i ->
                           json_of_balance
                             {
                               debits_pending = U128.of_le_bytes batch (i * account_balance_size);
                               debits_posted = U128.of_le_bytes batch ((i * account_balance_size) + 16);
                               credits_pending = U128.of_le_bytes batch ((i * account_balance_size) + 32);
                               credits_posted = U128.of_le_bytes batch ((i * account_balance_size) + 48);
                               timestamp = Codec.get_i64 batch ((i * account_balance_size) + 64);
                             })) )
      in
      write_all_fd fd (make_request cluster client_id 1L 1 operation body_payload);
      let _reply_header, body = read_reply fd in
      let jsons = result_jsons body in
      begin
        match jsons with
        | [] -> ()
        | [ one ] ->
            print_json one;
            output_char stdout '\n'
        | many ->
            List.iter (fun json ->
                print_json json;
                output_char stdout '\n') many
      end)
