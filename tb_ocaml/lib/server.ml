(** TCP server loop for the TigerBeetle-compatible wire protocol.

    This module keeps effects at the edge: it reads bytes from sockets, hands
    typed requests to {!State}, and writes encoded replies back to clients.

    Prototype note: request handling currently funnels through one mutex around
    shared state. That keeps the implementation simple and deterministic, but
    benchmark results mostly reflect prototype serialization rather than a
    concurrency-oriented server design. *)

open Types

let request_checksum (header : Codec.request_header) = header.Codec.checksum
let request_size (header : Codec.request_header) = header.Codec.size
let request_command (header : Codec.request_header) = header.Codec.command

let read_exact fd len =
  let buf = Bytes.create len in
  let rec loop off remaining =
    if remaining = 0 then buf
    else
      let n = Unix.read fd buf off remaining in
      if n = 0 then raise End_of_file else loop (off + n) (remaining - n)
  in
  loop 0 len

let write_all fd buf =
  let rec loop off remaining =
    if remaining > 0 then
      let n = Unix.write fd buf off remaining in
      if n <= 0 then raise End_of_file else loop (off + n) (remaining - n)
  in
  loop 0 (Bytes.length buf)

let body_timestamp_from_results state batches result_size =
  if result_size = create_error_result_size then
    if State.current_timestamp state = 0L then 1L
    else State.current_timestamp state
  else
    let extract_timestamp batch off = Codec.get_i64 batch off in
    let timestamps =
      List.concat_map
        (fun batch ->
          if Bytes.length batch = 0 || result_size = 0 then []
          else
            let count = Bytes.length batch / result_size in
            List.init count (fun i -> extract_timestamp batch (i * result_size)))
        batches
    in
    match List.sort_uniq Int64.compare timestamps with
    | [] ->
        if State.current_timestamp state = 0L then 1L
        else State.current_timestamp state
    | xs -> List.hd (List.rev xs)

let process_request state (header : Codec.request_header) body =
  State.ensure_expired_and_saved state;
  let commit = State.next_commit state in
  let create_changed op =
    op = op_deprecated_create_accounts_unbatched
    || op = op_deprecated_create_transfers_unbatched
    || op = op_deprecated_create_accounts_sparse
    || op = op_deprecated_create_transfers_sparse
    || op = op_create_accounts || op = op_create_transfers
  in
  let empty_multibatch_response op =
    let timestamp =
      if State.current_timestamp state = 0L then 1L
      else State.current_timestamp state
    in
    ( Codec.make_reply ~request_header:header ~body:Bytes.empty ~commit
        ~timestamp ~operation:op ~context:(request_checksum header),
      false )
  in
  match header.Codec.operation with
  | op when op = op_register ->
      let session, timestamp = State.register state in
      let body = Codec.encode_register_result () in
      let reply =
        Codec.make_reply ~request_header:header ~body ~commit:session ~timestamp
          ~operation:op_register ~context:(request_checksum header)
      in
      (reply, true)
  | op when op = op_pulse ->
      let body = Bytes.empty in
      let ts =
        if State.current_timestamp state = 0L then 1L
        else State.current_timestamp state
      in
      ( Codec.make_reply ~request_header:header ~body ~commit ~timestamp:ts
          ~operation:op ~context:(request_checksum header),
        false )
  | op ->
      let result_batches, changed =
        if Types.is_multi_batch op && Bytes.length body = 0 then ([], false)
        else if Types.is_multi_batch op then
          let event_batches =
            Multibatch.decode ~element_size:(Types.event_size op) body
          in
          let result_batches =
            match op with
            | o when o = op_deprecated_create_accounts_sparse ->
                List.map
                  (fun batch ->
                    let count = Bytes.length batch / account_size in
                    let events =
                      List.init count (fun i ->
                          Codec.decode_account batch (i * account_size))
                    in
                    Codec.encode_create_account_errors
                      (State.create_accounts_batch state events))
                  event_batches
            | o when o = op_deprecated_create_transfers_sparse ->
                List.map
                  (fun batch ->
                    let count = Bytes.length batch / transfer_size in
                    let events =
                      List.init count (fun i ->
                          Codec.decode_transfer batch (i * transfer_size))
                    in
                    Codec.encode_create_transfer_errors
                      (State.create_transfers_batch state events))
                  event_batches
            | o when o = op_create_accounts ->
                List.map
                  (fun batch ->
                    let count = Bytes.length batch / account_size in
                    let events =
                      List.init count (fun i ->
                          Codec.decode_account batch (i * account_size))
                    in
                    Codec.encode_create_results
                      (State.create_accounts_batch state events))
                  event_batches
            | o when o = op_create_transfers ->
                List.map
                  (fun batch ->
                    let count = Bytes.length batch / transfer_size in
                    let events =
                      List.init count (fun i ->
                          Codec.decode_transfer batch (i * transfer_size))
                    in
                    Codec.encode_create_results
                      (State.create_transfers_batch state events))
                  event_batches
            | o when o = op_lookup_accounts ->
                List.map
                  (fun batch ->
                    Codec.encode_accounts
                      (State.lookup_accounts_batch state
                         (Codec.decode_id_batch batch)))
                  event_batches
            | o when o = op_lookup_transfers ->
                List.map
                  (fun batch ->
                    Codec.encode_transfers
                      (State.lookup_transfers_batch state
                         (Codec.decode_id_batch batch)))
                  event_batches
            | o when o = op_query_accounts ->
                List.map
                  (fun batch ->
                    Codec.encode_accounts
                      (State.query_accounts_batch state
                         (Codec.decode_query_filter batch)))
                  event_batches
            | o when o = op_query_transfers ->
                List.map
                  (fun batch ->
                    Codec.encode_transfers
                      (State.query_transfers_batch state
                         (Codec.decode_query_filter batch)))
                  event_batches
            | o when o = op_get_account_transfers ->
                List.map
                  (fun batch ->
                    Codec.encode_transfers
                      (State.get_account_transfers_batch state
                         (Codec.decode_account_filter batch)))
                  event_batches
            | o when o = op_get_account_balances ->
                List.map
                  (fun batch ->
                    Codec.encode_balances
                      (State.get_account_balances_batch state
                         (Codec.decode_account_filter batch)))
                  event_batches
            | _ -> List.map (fun _ -> Bytes.empty) event_batches
          in
          let changed = create_changed op in
          (result_batches, changed)
        else
          let body, changed =
            match op with
            | o when o = op_deprecated_create_accounts_unbatched ->
                let count = Bytes.length body / account_size in
                let events =
                  List.init count (fun i ->
                      Codec.decode_account body (i * account_size))
                in
                ( Codec.encode_create_account_errors
                    (State.create_accounts_batch state events),
                  true )
            | o when o = op_deprecated_create_transfers_unbatched ->
                let count = Bytes.length body / transfer_size in
                let events =
                  List.init count (fun i ->
                      Codec.decode_transfer body (i * transfer_size))
                in
                ( Codec.encode_create_transfer_errors
                    (State.create_transfers_batch state events),
                  true )
            | o when o = op_deprecated_lookup_accounts_unbatched ->
                ( Codec.encode_accounts
                    (State.lookup_accounts_batch state
                       (Codec.decode_id_batch body)),
                  false )
            | o when o = op_deprecated_lookup_transfers_unbatched ->
                ( Codec.encode_transfers
                    (State.lookup_transfers_batch state
                       (Codec.decode_id_batch body)),
                  false )
            | o when o = op_deprecated_get_account_transfers_unbatched ->
                ( Codec.encode_transfers
                    (State.get_account_transfers_batch state
                       (Codec.decode_account_filter body)),
                  false )
            | o when o = op_deprecated_get_account_balances_unbatched ->
                ( Codec.encode_balances
                    (State.get_account_balances_batch state
                       (Codec.decode_account_filter body)),
                  false )
            | o when o = op_deprecated_query_accounts_unbatched ->
                ( Codec.encode_accounts
                    (State.query_accounts_batch state
                       (Codec.decode_query_filter body)),
                  false )
            | o when o = op_deprecated_query_transfers_unbatched ->
                ( Codec.encode_transfers
                    (State.query_transfers_batch state
                       (Codec.decode_query_filter body)),
                  false )
            | _ -> (Bytes.empty, false)
          in
          ([ body ], changed)
      in
      if Types.is_multi_batch op && Bytes.length body = 0 then
        empty_multibatch_response op
      else (
        if changed then State.save state;
        let body =
          if Types.is_multi_batch op then
            Multibatch.encode ~element_size:(Types.result_size op)
              result_batches
          else
            match result_batches with
            | [ body ] -> body
            | [] -> Bytes.empty
            | _ ->
                invalid_arg
                  "process_request: unexpected non-multibatch batch count"
        in
        let timestamp =
          body_timestamp_from_results state result_batches
            (Types.result_size op)
        in
        ( Codec.make_reply ~request_header:header ~body ~commit ~timestamp
            ~operation:op ~context:(request_checksum header),
          changed ))

let handle_connection state fd =
  Fun.protect
    ~finally:(fun () -> Unix.close fd)
    (fun () ->
      try
        while true do
          let header_bytes = read_exact fd header_size in
          let header = Codec.parse_request_header header_bytes in
          let body_len = max 0 (request_size header - header_size) in
          let body =
            if body_len = 0 then Bytes.empty else read_exact fd body_len
          in
          if request_command header = command_ping_client then ()
          else if request_command header = command_request then
            let reply =
              State.with_lock state (fun () ->
                  fst (process_request state header body))
            in
            write_all fd reply
          else ()
        done
      with End_of_file -> ())

let parse_address value =
  match String.split_on_char ':' value with
  | [ port ] -> ("127.0.0.1", int_of_string port)
  | [ host; port ] -> (host, int_of_string port)
  | _ -> failwith ("invalid address: " ^ value)

let start ~path ~addresses =
  let state = State.load path in
  let address =
    match String.split_on_char ',' addresses with
    | first :: _ -> first
    | [] -> "3000"
  in
  let host, port = parse_address address in
  let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.setsockopt sock Unix.SO_REUSEADDR true;
  let inet_addr =
    Unix.inet_addr_of_string (if host = "0" then "127.0.0.1" else host)
  in
  Unix.bind sock (Unix.ADDR_INET (inet_addr, port));
  Unix.listen sock 128;
  (match Unix.getsockname sock with
  | Unix.ADDR_INET (_, actual_port) when port = 0 ->
      Printf.printf "%d\n%!" actual_port
  | Unix.ADDR_INET _ | Unix.ADDR_UNIX _ -> ());
  let _stdin_thread =
    Thread.create
      (fun () ->
        try
          while input_char stdin <> '\000' do
            ()
          done
        with End_of_file -> Unix.close sock)
      ()
  in
  while true do
    let fd, _ = Unix.accept sock in
    ignore (Thread.create (handle_connection state) fd)
  done
