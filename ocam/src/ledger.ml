open Types

module Id_table = Hashtbl.Make (struct
    type t = U128.t

    let equal = U128.equal
    let hash = U128.hash
  end)

module Timestamp_map = Map.Make (Int64)

type history_entry =
  { snapshot : account
  ; transfer : transfer
  }

type t =
  { accounts : account Id_table.t
  ; transfers : transfer Id_table.t
  ; pending : pending_status Id_table.t
  ; failed_transfers : unit Id_table.t
  ; account_transfers : transfer Timeline.t Id_table.t
  ; account_history : history_entry Timeline.t Id_table.t
  ; accounts_by_timestamp : U128.t Timeline.t
  ; transfers_by_timestamp : transfer Timeline.t
  ; mutable pending_by_expiry : U128.t list Timestamp_map.t
  ; mutable commit_timestamp : int64
  ; mutable journal : (unit -> unit) list option
  }

let empty () =
  { accounts = Id_table.create 1024
  ; transfers = Id_table.create 1024
  ; pending = Id_table.create 256
  ; failed_transfers = Id_table.create 256
  ; account_transfers = Id_table.create 1024
  ; account_history = Id_table.create 1024
  ; accounts_by_timestamp = Timeline.create ()
  ; transfers_by_timestamp = Timeline.create ()
  ; pending_by_expiry = Timestamp_map.empty
  ; commit_timestamp = 0L
  ; journal = None
  }
;;

let commit_timestamp state = state.commit_timestamp

(* Journal *)

let record state undo =
  match state.journal with
  | None -> ()
  | Some undos -> state.journal <- Some (undo :: undos)
;;

let table_replace state table key value =
  (match state.journal with
   | None -> ()
   | Some _ ->
     (match Id_table.find_opt table key with
      | None -> record state (fun () -> Id_table.remove table key)
      | Some previous -> record state (fun () -> Id_table.replace table key previous)));
  Id_table.replace table key value
;;

let table_remove state table key =
  (match state.journal, Id_table.find_opt table key with
   | None, _ | Some _, None -> ()
   | Some _, Some previous -> record state (fun () -> Id_table.replace table key previous));
  Id_table.remove table key
;;

let set_commit_timestamp state timestamp =
  let previous = state.commit_timestamp in
  record state (fun () -> state.commit_timestamp <- previous);
  state.commit_timestamp <- timestamp
;;

let timeline_append state timeline timestamp value =
  (match state.journal with
   | None -> ()
   | Some _ ->
     let previous = Timeline.length timeline in
     record state (fun () -> Timeline.truncate timeline previous));
  Timeline.append timeline timestamp value
;;

let account_timeline state table id =
  match Id_table.find_opt table id with
  | Some timeline -> timeline
  | None ->
    let timeline = Timeline.create () in
    table_replace state table id timeline;
    timeline
;;

let set_pending_by_expiry state index =
  let previous = state.pending_by_expiry in
  record state (fun () -> state.pending_by_expiry <- previous);
  state.pending_by_expiry <- index
;;

let transact state f =
  assert (Option.is_none state.journal);
  state.journal <- Some [];
  let finish () =
    let undos = Option.value state.journal ~default:[] in
    state.journal <- None;
    fun () -> List.iter (fun undo -> undo ()) undos
  in
  match f () with
  | result ->
    let rollback = finish () in
    result, rollback
  | exception exn ->
    let rollback = finish () in
    rollback ();
    raise exn
;;

(* Reads *)

let find_account state id = Id_table.find_opt state.accounts id
let find_transfer state id = Id_table.find_opt state.transfers id
let find_pending state id = Id_table.find_opt state.pending id
let transfer_failed state id = Id_table.mem state.failed_transfers id

let account_transfers state id =
  match Id_table.find_opt state.account_transfers id with
  | Some timeline -> timeline
  | None -> Timeline.create ()
;;

let account_history state id =
  match Id_table.find_opt state.account_history id with
  | Some timeline -> timeline
  | None -> Timeline.create ()
;;

(* Writes *)

let add_account state (account : account) =
  table_replace state state.accounts account.id account;
  timeline_append state state.accounts_by_timestamp account.timestamp account.id;
  set_commit_timestamp state account.timestamp
;;

let update_account state (account : account) =
  table_replace state state.accounts account.id account
;;

let index_account_transfer state account_id (transfer : transfer) =
  timeline_append
    state
    (account_timeline state state.account_transfers account_id)
    transfer.timestamp
    transfer
;;

let add_transfer state (transfer : transfer) =
  table_replace state state.transfers transfer.id transfer;
  timeline_append state state.transfers_by_timestamp transfer.timestamp transfer;
  index_account_transfer state transfer.debit_account_id transfer;
  index_account_transfer state transfer.credit_account_id transfer;
  set_commit_timestamp state transfer.timestamp
;;

let add_expiry state ~expires_at id =
  let ids =
    Option.value (Timestamp_map.find_opt expires_at state.pending_by_expiry) ~default:[]
  in
  set_pending_by_expiry
    state
    (Timestamp_map.add expires_at (id :: ids) state.pending_by_expiry)
;;

let remove_expiry state ~expires_at id =
  match Timestamp_map.find_opt expires_at state.pending_by_expiry with
  | None -> ()
  | Some ids ->
    let remaining = List.filter (fun other -> not (U128.equal other id)) ids in
    set_pending_by_expiry
      state
      (if remaining = []
       then Timestamp_map.remove expires_at state.pending_by_expiry
       else Timestamp_map.add expires_at remaining state.pending_by_expiry)
;;

let set_pending state id status = table_replace state state.pending id status
let mark_failed state id = table_replace state state.failed_transfers id ()

let add_history state (snapshot : account) transfer =
  timeline_append
    state
    (account_timeline state state.account_history snapshot.id)
    snapshot.timestamp
    { snapshot; transfer }
;;

(* Ordered iteration *)

let to_seq_in_range = Timeline.to_seq_in_range

let expired_before state timestamp =
  let due, at, _ = Timestamp_map.split timestamp state.pending_by_expiry in
  let due =
    match at with
    | Some ids -> Timestamp_map.add timestamp ids due
    | None -> due
  in
  Timestamp_map.fold
    (fun expires_at ids acc ->
      List.fold_left (fun acc id -> (expires_at, id) :: acc) acc ids)
    due
    []
  |> List.rev
;;
