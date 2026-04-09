(** Persistent ledger state and validation rules.

    Prototype note: persistence currently uses [Marshal] snapshots. That keeps
    the test harness simple, but it is temporary scaffolding rather than a
    durable on-disk format to build long-term compatibility claims on. *)

open Types

module U128Tbl = Hashtbl.Make (struct
  type t = U128.t

  let equal = U128.equal
  let hash t = Hashtbl.hash (Bytes.to_string (U128.to_le_bytes t))
end)

type pending_state =
  | Non_pending
  | Pending of {
      expires_at : int64 option;
      closing_debit : bool;
      closing_credit : bool;
    }
  | Posted
  | Voided
  | Expired

type transfer_state = {
  transfer : transfer;
  mutable pending_state : pending_state;
}

type history_entry = {
  timestamp : int64;
  transfer : transfer;
  balance : account_balance;
  direction : [ `Debit | `Credit ];
}

type snapshot_transfer_state = {
  s_transfer : transfer;
  s_pending_state : pending_state;
}

type snapshot = {
  cluster : U128.t;
  next_timestamp : int64;
  next_commit : int64;
  next_session : int64;
  accounts : (U128.t * account) list;
  transfers : (U128.t * snapshot_transfer_state) list;
  histories : (U128.t * history_entry list) list;
}

type t = {
  path : string;
  mutable cluster : U128.t;
  mutable accounts : account U128Tbl.t;
  mutable transfers : transfer_state U128Tbl.t;
  mutable histories : history_entry list U128Tbl.t;
  mutable next_timestamp : int64;
  mutable next_commit : int64;
  mutable next_session : int64;
  mutex : Mutex.t;
}

let empty_tables () =
  (U128Tbl.create 128, U128Tbl.create 128, U128Tbl.create 128)

let make_empty path cluster =
  let accounts, transfers, histories = empty_tables () in
  {
    path;
    cluster;
    accounts;
    transfers;
    histories;
    next_timestamp = 0L;
    next_commit = 0L;
    next_session = 0L;
    mutex = Mutex.create ();
  }

let snapshot_of_state t =
  {
    cluster = t.cluster;
    next_timestamp = t.next_timestamp;
    next_commit = t.next_commit;
    next_session = t.next_session;
    accounts = U128Tbl.to_seq t.accounts |> List.of_seq;
    transfers =
      U128Tbl.to_seq t.transfers
      |> Seq.map (fun (k, (v : transfer_state)) ->
          (k, { s_transfer = v.transfer; s_pending_state = v.pending_state }))
      |> List.of_seq;
    histories = U128Tbl.to_seq t.histories |> List.of_seq;
  }

let state_of_snapshot path (s : snapshot) =
  let t = make_empty path s.cluster in
  t.next_timestamp <- s.next_timestamp;
  t.next_commit <- s.next_commit;
  t.next_session <- s.next_session;
  List.iter (fun (k, v) -> U128Tbl.replace t.accounts k v) s.accounts;
  List.iter
    (fun (k, v) ->
      U128Tbl.replace t.transfers k
        { transfer = v.s_transfer; pending_state = v.s_pending_state })
    s.transfers;
  List.iter (fun (k, v) -> U128Tbl.replace t.histories k v) s.histories;
  t

let save t =
  let tmp = t.path ^ ".tmp" in
  let oc = open_out_bin tmp in
  Marshal.to_channel oc (snapshot_of_state t) [];
  close_out oc;
  Sys.rename tmp t.path

let format ~path ~cluster =
  let t = make_empty path cluster in
  save t

let load path =
  let ic = open_in_bin path in
  let snapshot : snapshot = Marshal.from_channel ic in
  close_in ic;
  state_of_snapshot path snapshot

let clone t = state_of_snapshot t.path (snapshot_of_state t)
let current_timestamp t = t.next_timestamp
let now_ns () = Int64.of_float (Unix.gettimeofday () *. 1_000_000_000.)

let alloc_timestamp t =
  let now = now_ns () in
  let ts =
    if Int64.compare now t.next_timestamp > 0 then now
    else Int64.succ t.next_timestamp
  in
  t.next_timestamp <- ts;
  ts

let accept_imported_timestamp t ts =
  if Int64.compare ts t.next_timestamp > 0 then (
    t.next_timestamp <- ts;
    true)
  else false

let next_commit t =
  let v = Int64.succ t.next_commit in
  t.next_commit <- v;
  v

let next_session t =
  let v = Int64.succ t.next_session in
  t.next_session <- v;
  v

let with_lock t f =
  Mutex.lock t.mutex;
  Fun.protect ~finally:(fun () -> Mutex.unlock t.mutex) f

let balance_of_account (a : account) ~(timestamp : int64) : account_balance =
  {
    debits_pending = a.debits_pending;
    debits_posted = a.debits_posted;
    credits_pending = a.credits_pending;
    credits_posted = a.credits_posted;
    timestamp;
  }

let update_account (tbl : account U128Tbl.t) (account : account) =
  U128Tbl.replace tbl account.id account

let find_account (tbl : account U128Tbl.t) id = U128Tbl.find_opt tbl id
let find_transfer (tbl : transfer_state U128Tbl.t) id = U128Tbl.find_opt tbl id

let add_history t account_id entry =
  let existing =
    Option.value (U128Tbl.find_opt t.histories account_id) ~default:[]
  in
  U128Tbl.replace t.histories account_id (existing @ [ entry ])

let set_closed_flag (a : account) bit enabled =
  let flags = if enabled then a.flags lor bit else a.flags land lnot bit in
  { a with flags }

let record_transfer_history t (transfer : transfer) (debit : account)
    (credit : account) =
  let debit' = Option.get (find_account t.accounts debit.id) in
  let credit' = Option.get (find_account t.accounts credit.id) in
  add_history t debit.id
    {
      timestamp = transfer.timestamp;
      transfer;
      balance = balance_of_account debit' ~timestamp:transfer.timestamp;
      direction = `Debit;
    };
  add_history t credit.id
    {
      timestamp = transfer.timestamp;
      transfer;
      balance = balance_of_account credit' ~timestamp:transfer.timestamp;
      direction = `Credit;
    }

let restore_pending_effect t pending_transfer ~mark =
  match find_transfer t.transfers pending_transfer.id with
  | None -> ()
  | Some state ->
      let debit =
        Option.get (find_account t.accounts pending_transfer.debit_account_id)
      in
      let credit =
        Option.get (find_account t.accounts pending_transfer.credit_account_id)
      in
      let debit =
        {
          debit with
          debits_pending = U128.sub debit.debits_pending pending_transfer.amount;
        }
      in
      let credit =
        {
          credit with
          credits_pending =
            U128.sub credit.credits_pending pending_transfer.amount;
        }
      in
      let debit =
        if Types.bool_flag pending_transfer.flags transfer_flag_closing_debit
        then set_closed_flag debit account_flag_closed false
        else debit
      in
      let credit =
        if Types.bool_flag pending_transfer.flags transfer_flag_closing_credit
        then set_closed_flag credit account_flag_closed false
        else credit
      in
      update_account t.accounts debit;
      update_account t.accounts credit;
      state.pending_state <- mark

let expire_pending t =
  let changed = ref false in
  let now = now_ns () in
  U128Tbl.iter
    (fun _ state ->
      match state.pending_state with
      | Pending { expires_at = Some expires_at; _ }
        when Int64.compare now expires_at >= 0 ->
          changed := true;
          restore_pending_effect t state.transfer ~mark:Expired
      | Pending _ | Non_pending | Posted | Voided | Expired -> ())
    t.transfers;
  !changed

let account_exact_match (a : account) (b : account) =
  U128.equal a.id b.id
  && U128.equal a.debits_pending b.debits_pending
  && U128.equal a.debits_posted b.debits_posted
  && U128.equal a.credits_pending b.credits_pending
  && U128.equal a.credits_posted b.credits_posted
  && U128.equal a.user_data_128 b.user_data_128
  && a.user_data_64 = b.user_data_64
  && a.user_data_32 = b.user_data_32
  && a.ledger = b.ledger && a.code = b.code && a.flags = b.flags

let transfer_exact_match (a : transfer) (b : transfer) =
  U128.equal a.id b.id
  && U128.equal a.debit_account_id b.debit_account_id
  && U128.equal a.credit_account_id b.credit_account_id
  && U128.equal a.amount b.amount
  && U128.equal a.pending_id b.pending_id
  && U128.equal a.user_data_128 b.user_data_128
  && a.user_data_64 = b.user_data_64
  && a.user_data_32 = b.user_data_32
  && a.timeout = b.timeout && a.ledger = b.ledger && a.code = b.code
  && a.flags = b.flags

let validate_imported_account t (a : account) =
  if not (Types.bool_flag a.flags account_flag_imported) then
    if a.timestamp <> 0L then Error create_account_timestamp_must_be_zero
    else Ok (alloc_timestamp t)
  else if a.timestamp = 0L then Error create_account_imported_event_expected
  else if not (accept_imported_timestamp t a.timestamp) then
    Error create_account_imported_event_timestamp_must_not_regress
  else Ok a.timestamp

let create_account_one t (a : account) =
  if U128.is_zero a.id then
    {
      timestamp = alloc_timestamp t;
      status = create_account_id_must_not_be_zero;
    }
  else if a.ledger = 0l then
    {
      timestamp = alloc_timestamp t;
      status = create_account_ledger_must_not_be_zero;
    }
  else if a.code = 0 then
    {
      timestamp = alloc_timestamp t;
      status = create_account_code_must_not_be_zero;
    }
  else if
    not
      (U128.is_zero a.debits_pending
      && U128.is_zero a.debits_posted
      && U128.is_zero a.credits_pending
      && U128.is_zero a.credits_posted)
  then
    {
      timestamp = alloc_timestamp t;
      status = create_account_exists_with_different_flags;
    }
  else
    match find_account t.accounts a.id with
    | Some existing ->
        let status =
          if account_exact_match existing a then create_account_exists
          else if existing.flags <> a.flags then
            create_account_exists_with_different_flags
          else if not (U128.equal existing.user_data_128 a.user_data_128) then
            create_account_exists_with_different_user_data_128
          else if existing.user_data_64 <> a.user_data_64 then
            create_account_exists_with_different_user_data_64
          else if existing.user_data_32 <> a.user_data_32 then
            create_account_exists_with_different_user_data_32
          else if existing.ledger <> a.ledger then
            create_account_exists_with_different_ledger
          else create_account_exists_with_different_code
        in
        { timestamp = alloc_timestamp t; status }
    | None -> (
        match validate_imported_account t a with
        | Error status -> { timestamp = alloc_timestamp t; status }
        | Ok timestamp ->
            let created = { a with timestamp } in
            update_account t.accounts created;
            { timestamp; status = create_account_created })

let pending_not_open_status = function
  | Posted -> create_transfer_pending_transfer_already_posted
  | Voided -> create_transfer_pending_transfer_already_voided
  | Expired -> create_transfer_pending_transfer_expired
  | Non_pending -> create_transfer_pending_transfer_not_pending
  | Pending _ -> create_transfer_created

let validate_transfer_timestamp t (tr : transfer) =
  if not (Types.bool_flag tr.flags transfer_flag_imported) then
    if tr.timestamp <> 0L then Error create_transfer_timestamp_must_be_zero
    else Ok (alloc_timestamp t)
  else if tr.timestamp = 0L then Error create_transfer_imported_event_expected
  else if tr.timeout <> 0l then
    Error create_transfer_imported_event_timeout_must_be_zero
  else if not (accept_imported_timestamp t tr.timestamp) then
    Error create_transfer_imported_event_timestamp_must_not_regress
  else Ok tr.timestamp

let create_transfer_one t (tr : transfer) =
  if U128.is_zero tr.id then
    {
      timestamp = alloc_timestamp t;
      status = create_transfer_id_must_not_be_zero;
    }
  else if tr.ledger = 0l then
    {
      timestamp = alloc_timestamp t;
      status = create_transfer_ledger_must_not_be_zero;
    }
  else if tr.code = 0 then
    {
      timestamp = alloc_timestamp t;
      status = create_transfer_code_must_not_be_zero;
    }
  else
    match find_transfer t.transfers tr.id with
    | Some existing ->
        let e = existing.transfer in
        let status =
          if transfer_exact_match e tr then create_transfer_exists
          else if e.flags <> tr.flags then
            create_transfer_exists_with_different_flags
          else if not (U128.equal e.debit_account_id tr.debit_account_id) then
            create_transfer_exists_with_different_debit_account_id
          else if not (U128.equal e.credit_account_id tr.credit_account_id) then
            create_transfer_exists_with_different_credit_account_id
          else if not (U128.equal e.amount tr.amount) then
            create_transfer_exists_with_different_amount
          else if not (U128.equal e.pending_id tr.pending_id) then
            create_transfer_exists_with_different_pending_id
          else if not (U128.equal e.user_data_128 tr.user_data_128) then
            create_transfer_exists_with_different_user_data_128
          else if e.user_data_64 <> tr.user_data_64 then
            create_transfer_exists_with_different_user_data_64
          else if e.user_data_32 <> tr.user_data_32 then
            create_transfer_exists_with_different_user_data_32
          else if e.timeout <> tr.timeout then
            create_transfer_exists_with_different_timeout
          else if e.ledger <> tr.ledger then
            create_transfer_exists_with_different_ledger
          else create_transfer_exists_with_different_code
        in
        { timestamp = alloc_timestamp t; status }
    | None -> (
        let pending = Types.bool_flag tr.flags transfer_flag_pending in
        let post_pending =
          Types.bool_flag tr.flags transfer_flag_post_pending_transfer
        in
        let void_pending =
          Types.bool_flag tr.flags transfer_flag_void_pending_transfer
        in
        let closing_debit =
          Types.bool_flag tr.flags transfer_flag_closing_debit
        in
        let closing_credit =
          Types.bool_flag tr.flags transfer_flag_closing_credit
        in
        if
          ((if pending then 1 else 0)
          + (if post_pending then 1 else 0)
          + if void_pending then 1 else 0)
          > 1
        then
          {
            timestamp = alloc_timestamp t;
            status = create_transfer_pending_id_must_be_zero;
          }
        else if closing_debit || closing_credit then
          if not pending then
            {
              timestamp = alloc_timestamp t;
              status = create_transfer_closing_transfer_must_be_pending;
            }
          else
            match validate_transfer_timestamp t tr with
            | Error status -> { timestamp = alloc_timestamp t; status }
            | Ok timestamp -> (
                let debit = find_account t.accounts tr.debit_account_id in
                let credit = find_account t.accounts tr.credit_account_id in
                match (debit, credit) with
                | None, _ ->
                    {
                      timestamp;
                      status = create_transfer_debit_account_not_found;
                    }
                | _, None ->
                    {
                      timestamp;
                      status = create_transfer_credit_account_not_found;
                    }
                | Some debit, Some credit ->
                    let debit =
                      set_closed_flag
                        {
                          debit with
                          debits_pending =
                            U128.add debit.debits_pending tr.amount;
                        }
                        account_flag_closed true
                    in
                    let credit =
                      set_closed_flag
                        {
                          credit with
                          credits_pending =
                            U128.add credit.credits_pending tr.amount;
                        }
                        account_flag_closed true
                    in
                    let created = { tr with timestamp } in
                    update_account t.accounts debit;
                    update_account t.accounts credit;
                    U128Tbl.replace t.transfers tr.id
                      {
                        transfer = created;
                        pending_state =
                          Pending
                            {
                              expires_at =
                                (if tr.timeout = 0l then None
                                 else
                                   Some
                                     Int64.(
                                       add timestamp
                                         (mul (of_int32 tr.timeout)
                                            1_000_000_000L)));
                              closing_debit;
                              closing_credit;
                            };
                      };
                    record_transfer_history t created debit credit;
                    { timestamp; status = create_transfer_created })
        else if post_pending || void_pending then
          if U128.is_zero tr.pending_id then
            {
              timestamp = alloc_timestamp t;
              status = create_transfer_pending_id_must_not_be_zero;
            }
          else
            match find_transfer t.transfers tr.pending_id with
            | None ->
                {
                  timestamp = alloc_timestamp t;
                  status = create_transfer_pending_transfer_not_found;
                }
            | Some pending_state_record ->
                let pending_transfer = pending_state_record.transfer in
                let pending_status = pending_state_record.pending_state in
                begin match pending_status with
                | Pending { expires_at = Some e; _ }
                  when Int64.compare (now_ns ()) e >= 0 ->
                    let ts = alloc_timestamp t in
                    restore_pending_effect t pending_transfer ~mark:Expired;
                    {
                      timestamp = ts;
                      status = create_transfer_pending_transfer_expired;
                    }
                | Pending _ ->
                    let debit =
                      Option.get
                        (find_account t.accounts
                           pending_transfer.debit_account_id)
                    in
                    let credit =
                      Option.get
                        (find_account t.accounts
                           pending_transfer.credit_account_id)
                    in
                    begin match validate_transfer_timestamp t tr with
                    | Error status -> { timestamp = alloc_timestamp t; status }
                    | Ok timestamp ->
                        let created = { tr with timestamp } in
                        if post_pending then (
                          if
                            (not (U128.is_zero tr.debit_account_id))
                            && not
                                 (U128.equal tr.debit_account_id
                                    pending_transfer.debit_account_id)
                          then
                            {
                              timestamp;
                              status =
                                create_transfer_pending_transfer_has_different_debit_account_id;
                            }
                          else if
                            (not (U128.is_zero tr.credit_account_id))
                            && not
                                 (U128.equal tr.credit_account_id
                                    pending_transfer.credit_account_id)
                          then
                            {
                              timestamp;
                              status =
                                create_transfer_pending_transfer_has_different_credit_account_id;
                            }
                          else if
                            tr.ledger <> 0l
                            && tr.ledger <> pending_transfer.ledger
                          then
                            {
                              timestamp;
                              status =
                                create_transfer_pending_transfer_has_different_ledger;
                            }
                          else if
                            tr.code <> 0 && tr.code <> pending_transfer.code
                          then
                            {
                              timestamp;
                              status =
                                create_transfer_pending_transfer_has_different_code;
                            }
                          else
                            let amount =
                              if U128.equal tr.amount amount_max then
                                pending_transfer.amount
                              else tr.amount
                            in
                            if U128.compare amount pending_transfer.amount > 0
                            then
                              {
                                timestamp;
                                status =
                                  create_transfer_exceeds_pending_transfer_amount;
                              }
                            else
                              let debit =
                                {
                                  debit with
                                  debits_pending =
                                    U128.sub debit.debits_pending amount;
                                  debits_posted =
                                    U128.add debit.debits_posted amount;
                                }
                              in
                              let credit =
                                {
                                  credit with
                                  credits_pending =
                                    U128.sub credit.credits_pending amount;
                                  credits_posted =
                                    U128.add credit.credits_posted amount;
                                }
                              in
                              update_account t.accounts debit;
                              update_account t.accounts credit;
                              pending_state_record.pending_state <- Posted;
                              U128Tbl.replace t.transfers tr.id
                                {
                                  transfer = created;
                                  pending_state = Non_pending;
                                };
                              record_transfer_history t created debit credit;
                              { timestamp; status = create_transfer_created })
                        else if
                          (not (U128.is_zero tr.debit_account_id))
                          && not
                               (U128.equal tr.debit_account_id
                                  pending_transfer.debit_account_id)
                        then
                          {
                            timestamp;
                            status =
                              create_transfer_pending_transfer_has_different_debit_account_id;
                          }
                        else if
                          (not (U128.is_zero tr.credit_account_id))
                          && not
                               (U128.equal tr.credit_account_id
                                  pending_transfer.credit_account_id)
                        then
                          {
                            timestamp;
                            status =
                              create_transfer_pending_transfer_has_different_credit_account_id;
                          }
                        else if
                          tr.ledger <> 0l
                          && tr.ledger <> pending_transfer.ledger
                        then
                          {
                            timestamp;
                            status =
                              create_transfer_pending_transfer_has_different_ledger;
                          }
                        else if tr.code <> 0 && tr.code <> pending_transfer.code
                        then
                          {
                            timestamp;
                            status =
                              create_transfer_pending_transfer_has_different_code;
                          }
                        else (
                          restore_pending_effect t pending_transfer ~mark:Voided;
                          let debit =
                            Option.get
                              (find_account t.accounts
                                 pending_transfer.debit_account_id)
                          in
                          let credit =
                            Option.get
                              (find_account t.accounts
                                 pending_transfer.credit_account_id)
                          in
                          U128Tbl.replace t.transfers tr.id
                            { transfer = created; pending_state = Non_pending };
                          record_transfer_history t created debit credit;
                          { timestamp; status = create_transfer_created })
                    end
                | (Non_pending | Posted | Voided | Expired) as other ->
                    {
                      timestamp = alloc_timestamp t;
                      status = pending_not_open_status other;
                    }
                end
        else if U128.is_zero tr.debit_account_id then
          {
            timestamp = alloc_timestamp t;
            status = create_transfer_debit_account_id_must_not_be_zero;
          }
        else if U128.is_zero tr.credit_account_id then
          {
            timestamp = alloc_timestamp t;
            status = create_transfer_credit_account_id_must_not_be_zero;
          }
        else if U128.equal tr.debit_account_id tr.credit_account_id then
          {
            timestamp = alloc_timestamp t;
            status = create_transfer_accounts_must_be_different;
          }
        else
          match validate_transfer_timestamp t tr with
          | Error status -> { timestamp = alloc_timestamp t; status }
          | Ok timestamp -> (
              let debit = find_account t.accounts tr.debit_account_id in
              let credit = find_account t.accounts tr.credit_account_id in
              match (debit, credit) with
              | None, _ ->
                  {
                    timestamp;
                    status = create_transfer_debit_account_not_found;
                  }
              | _, None ->
                  {
                    timestamp;
                    status = create_transfer_credit_account_not_found;
                  }
              | Some debit, Some credit ->
                  if
                    Types.bool_flag tr.flags transfer_flag_imported
                    && Int64.compare timestamp debit.timestamp <= 0
                  then
                    {
                      timestamp;
                      status =
                        create_transfer_imported_event_timestamp_must_postdate_debit_account;
                    }
                  else if
                    Types.bool_flag tr.flags transfer_flag_imported
                    && Int64.compare timestamp credit.timestamp <= 0
                  then
                    {
                      timestamp;
                      status =
                        create_transfer_imported_event_timestamp_must_postdate_credit_account;
                    }
                  else if debit.ledger <> credit.ledger then
                    {
                      timestamp;
                      status =
                        create_transfer_accounts_must_have_the_same_ledger;
                    }
                  else if debit.ledger <> tr.ledger then
                    {
                      timestamp;
                      status =
                        create_transfer_transfer_must_have_the_same_ledger_as_accounts;
                    }
                  else if Types.bool_flag debit.flags account_flag_closed then
                    {
                      timestamp;
                      status = create_transfer_debit_account_already_closed;
                    }
                  else if Types.bool_flag credit.flags account_flag_closed then
                    {
                      timestamp;
                      status = create_transfer_credit_account_already_closed;
                    }
                  else if pending then (
                    let debit =
                      {
                        debit with
                        debits_pending = U128.add debit.debits_pending tr.amount;
                      }
                    in
                    let credit =
                      {
                        credit with
                        credits_pending =
                          U128.add credit.credits_pending tr.amount;
                      }
                    in
                    let created = { tr with timestamp } in
                    update_account t.accounts debit;
                    update_account t.accounts credit;
                    U128Tbl.replace t.transfers tr.id
                      {
                        transfer = created;
                        pending_state =
                          Pending
                            {
                              expires_at =
                                (if tr.timeout = 0l then None
                                 else
                                   Some
                                     Int64.(
                                       add timestamp
                                         (mul (of_int32 tr.timeout)
                                            1_000_000_000L)));
                              closing_debit = false;
                              closing_credit = false;
                            };
                      };
                    record_transfer_history t created debit credit;
                    { timestamp; status = create_transfer_created })
                  else
                    let debit =
                      {
                        debit with
                        debits_posted = U128.add debit.debits_posted tr.amount;
                      }
                    in
                    let credit =
                      {
                        credit with
                        credits_posted =
                          U128.add credit.credits_posted tr.amount;
                      }
                    in
                    let created = { tr with timestamp } in
                    update_account t.accounts debit;
                    update_account t.accounts credit;
                    U128Tbl.replace t.transfers tr.id
                      { transfer = created; pending_state = Non_pending };
                    record_transfer_history t created debit credit;
                    { timestamp; status = create_transfer_created }))

let commit_clone t clone =
  t.cluster <- clone.cluster;
  t.accounts <- clone.accounts;
  t.transfers <- clone.transfers;
  t.histories <- clone.histories;
  t.next_timestamp <- clone.next_timestamp;
  t.next_commit <- clone.next_commit;
  t.next_session <- clone.next_session

let process_linked_batch t items apply flags_of linked_failed_status =
  let rec loop acc remaining =
    match remaining with
    | [] -> List.rev acc
    | _ :: _ ->
        let group_acc, rest =
          let rec gather rev_group current_tail =
            match current_tail with
            | [] -> (List.rev rev_group, [])
            | x :: xs ->
                let rev_group = x :: rev_group in
                if
                  Types.bool_flag (flags_of x) account_flag_linked
                  || Types.bool_flag (flags_of x) transfer_flag_linked
                then gather rev_group xs
                else (List.rev rev_group, xs)
          in
          gather [] remaining
        in
        let clone = clone t in
        let results = List.map (apply clone) group_acc in
        let chain_open =
          match List.rev group_acc with
          | [] -> false
          | last :: _ ->
              let flags = flags_of last in
              Types.bool_flag flags account_flag_linked
              || Types.bool_flag flags transfer_flag_linked
        in
        let failing =
          if chain_open then
            Some
              {
                timestamp = 0L;
                status = create_transfer_linked_event_chain_open;
              }
          else
            List.find_opt
              (fun r ->
                r.status <> create_account_created
                && r.status <> create_transfer_created)
              results
        in
        let group_results =
          match failing with
          | None ->
              commit_clone t clone;
              results
          | Some failure ->
              let rec mark_prefix built = function
                | [] -> List.rev built
                | [ last ] -> List.rev (last :: built)
                | x :: xs ->
                    if
                      x.status <> create_account_created
                      && x.status <> create_transfer_created
                    then List.rev_append built (x :: xs)
                    else
                      mark_prefix
                        ({ x with status = linked_failed_status } :: built)
                        xs
              in
              if chain_open then
                let chain_open_status =
                  if linked_failed_status = create_account_linked_event_failed
                  then create_account_linked_event_chain_open
                  else create_transfer_linked_event_chain_open
                in
                let rec rewrite built = function
                  | [] -> List.rev built
                  | [ last ] ->
                      List.rev
                        ({ last with status = chain_open_status } :: built)
                  | x :: xs ->
                      rewrite
                        ({ x with status = linked_failed_status } :: built)
                        xs
                in
                rewrite [] results
              else
                let _ = failure in
                mark_prefix [] results
        in
        loop (List.rev_append group_results acc) rest
  in
  loop [] items

let create_accounts_batch t accounts =
  process_linked_batch t accounts create_account_one
    (fun a -> a.flags)
    create_account_linked_event_failed

let create_transfers_batch t transfers =
  process_linked_batch t transfers create_transfer_one
    (fun tr -> tr.flags)
    create_transfer_linked_event_failed

let lookup_accounts_batch t ids = List.filter_map (find_account t.accounts) ids

let lookup_transfers_batch t ids =
  List.filter_map
    (fun id ->
      Option.map
        (fun (x : transfer_state) -> x.transfer)
        (find_transfer t.transfers id))
    ids

let sort_accounts ?(reversed = false) (xs : account list) =
  List.sort
    (fun (a : account) (b : account) ->
      let c = Int64.compare a.timestamp b.timestamp in
      if reversed then -c else c)
    xs

let sort_transfers ?(reversed = false) (xs : transfer list) =
  List.sort
    (fun (a : transfer) (b : transfer) ->
      let c = Int64.compare a.timestamp b.timestamp in
      if reversed then -c else c)
    xs

let sort_history ?(reversed = false) (xs : history_entry list) =
  List.sort
    (fun (a : history_entry) (b : history_entry) ->
      let c = Int64.compare a.timestamp b.timestamp in
      if reversed then -c else c)
    xs

let valid_query_filter (filter : query_filter) =
  let flags = Int32.to_int filter.flags in
  filter.limit > 0l && filter.timestamp_min >= 0L && filter.timestamp_max >= 0L
  && (filter.timestamp_max = 0L || filter.timestamp_min = 0L
     || filter.timestamp_min <= filter.timestamp_max)
  && flags land lnot query_filter_reversed = 0

let valid_account_filter (filter : account_filter) =
  let flags = Int32.to_int filter.flags in
  filter.limit > 0l && filter.timestamp_min >= 0L && filter.timestamp_max >= 0L
  && (filter.timestamp_max = 0L || filter.timestamp_min = 0L
     || filter.timestamp_min <= filter.timestamp_max)
  && flags <> 0
  && flags
     land lnot
            (account_filter_debits lor account_filter_credits
           lor account_filter_reversed)
     = 0

let query_accounts_batch t (filter : query_filter) =
  if not (valid_query_filter filter) then []
  else
    let results =
      U128Tbl.to_seq_values t.accounts
      |> List.of_seq
      |> List.filter (fun (a : account) ->
          (U128.is_zero filter.user_data_128
          || U128.equal a.user_data_128 filter.user_data_128)
          && (filter.user_data_64 = 0L || a.user_data_64 = filter.user_data_64)
          && (filter.user_data_32 = 0l || a.user_data_32 = filter.user_data_32)
          && (filter.ledger = 0l || a.ledger = filter.ledger)
          && (filter.code = 0 || a.code = filter.code)
          && (filter.timestamp_min = 0L
             || Int64.compare a.timestamp filter.timestamp_min >= 0)
          && (filter.timestamp_max = 0L
             || Int64.compare a.timestamp filter.timestamp_max <= 0))
    in
    let results =
      sort_accounts
        ~reversed:
          (Int32.to_int filter.flags land Types.query_filter_reversed <> 0)
        results
    in
    let limit = max 0 (Int32.to_int filter.limit) in
    if limit = 0 then [] else Stdlib.List.filteri (fun i _ -> i < limit) results

let query_transfers_batch t (filter : query_filter) =
  if not (valid_query_filter filter) then []
  else
    let results =
      U128Tbl.to_seq_values t.transfers
      |> Seq.map (fun (s : transfer_state) -> s.transfer)
      |> List.of_seq
      |> List.filter (fun (tr : transfer) ->
          (U128.is_zero filter.user_data_128
          || U128.equal tr.user_data_128 filter.user_data_128)
          && (filter.user_data_64 = 0L || tr.user_data_64 = filter.user_data_64)
          && (filter.user_data_32 = 0l || tr.user_data_32 = filter.user_data_32)
          && (filter.ledger = 0l || tr.ledger = filter.ledger)
          && (filter.code = 0 || tr.code = filter.code)
          && (filter.timestamp_min = 0L
             || Int64.compare tr.timestamp filter.timestamp_min >= 0)
          && (filter.timestamp_max = 0L
             || Int64.compare tr.timestamp filter.timestamp_max <= 0))
    in
    let results =
      sort_transfers
        ~reversed:
          (Int32.to_int filter.flags land Types.query_filter_reversed <> 0)
        results
    in
    let limit = max 0 (Int32.to_int filter.limit) in
    if limit = 0 then [] else Stdlib.List.filteri (fun i _ -> i < limit) results

let get_account_history t (filter : account_filter) =
  if not (valid_account_filter filter) then []
  else
    match U128Tbl.find_opt t.histories filter.account_id with
    | None -> []
    | Some entries ->
        entries
        |> List.filter (fun (h : history_entry) ->
            (Int32.to_int filter.flags land account_filter_debits <> 0
             && h.direction = `Debit
            || Int32.to_int filter.flags land account_filter_credits <> 0
               && h.direction = `Credit)
            && (U128.is_zero filter.user_data_128
               || U128.equal h.transfer.user_data_128 filter.user_data_128)
            && (filter.user_data_64 = 0L
               || h.transfer.user_data_64 = filter.user_data_64)
            && (filter.user_data_32 = 0l
               || h.transfer.user_data_32 = filter.user_data_32)
            && (filter.code = 0 || h.transfer.code = filter.code)
            && (filter.timestamp_min = 0L
               || Int64.compare h.timestamp filter.timestamp_min >= 0)
            && (filter.timestamp_max = 0L
               || Int64.compare h.timestamp filter.timestamp_max <= 0))
        |> sort_history
             ~reversed:
               (Int32.to_int filter.flags land account_filter_reversed <> 0)

let limit_list limit xs =
  let limit = max 0 (Int32.to_int limit) in
  Stdlib.List.filteri (fun i _ -> i < limit) xs

let get_account_transfers_batch t (filter : account_filter) =
  get_account_history t filter
  |> limit_list filter.limit
  |> List.map (fun h -> h.transfer)

let get_account_balances_batch t (filter : account_filter) =
  get_account_history t filter
  |> limit_list filter.limit
  |> List.map (fun h -> h.balance)

let ensure_expired_and_saved t = if expire_pending t then save t

let register t =
  let session = next_session t in
  let ts = if t.next_timestamp = 0L then now_ns () else t.next_timestamp in
  (session, ts)
