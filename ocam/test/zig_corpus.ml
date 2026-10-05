(* Replays the table-driven scenarios of the upstream TigerBeetle
   [state_machine_tests.zig] against the OCaml core and prints one line per scenario:
   PASS, FAIL (with the first mismatches) or SKIP (uses a feature the OCaml core cannot
   express yet).

   The interpreter mirrors [check_version] in the Zig file for the current client version:
   the same table grammar ([testing/table.zig]), the same expected-reply construction and
   the same prepare/pulse clock, with [batch_max.create_transfers = 30] from the
   [test_min] config used by Zig unit tests. *)

open Tigerbeetle_state_machine.State_machine

exception Parse of string

let parse_error fmt = Printf.ksprintf (fun s -> raise (Parse s)) fmt
let starts_with ~prefix s = String.starts_with ~prefix s

(* Corpus extraction. *)

type scenario =
  { name : string
  ; rows : string list list
  }

let tokens_of_row row =
  let words =
    String.split_on_char ' ' row
    |> List.concat_map (String.split_on_char '\t')
    |> List.filter (fun w -> w <> "")
  in
  let rec take = function
    | [] -> []
    | w :: _ when starts_with ~prefix:"//" w -> []
    | w :: rest -> w :: take rest
  in
  take words
;;

let test_name line =
  let line = String.trim line in
  if starts_with ~prefix:"test \"" line
  then (
    match String.index_from_opt line 6 '"' with
    | Some j -> Some (String.sub line 6 (j - 6))
    | None -> None)
  else None
;;

let extract_scenarios lines =
  let rec loop name index rows acc = function
    | [] -> List.rev acc
    | line :: rest ->
      let t = String.trim line in
      (match rows with
       | Some rows ->
         if starts_with ~prefix:");" t
         then (
           let name' =
             if index = 0 then name else Printf.sprintf "%s #%d" name (index + 1)
           in
           loop name (index + 1) None ({ name = name'; rows = List.rev rows } :: acc) rest)
         else if starts_with ~prefix:"\\\\" t
         then (
           let tokens = tokens_of_row (String.sub t 2 (String.length t - 2)) in
           loop name index (Some (if tokens = [] then rows else tokens :: rows)) acc rest)
         else loop name index (Some rows) acc rest
       | None ->
         (match test_name line with
          | Some name -> loop name 0 None acc rest
          | None ->
            if starts_with ~prefix:"try check(" t
            then loop name index (Some []) acc rest
            else loop name index None acc rest))
  in
  loop "" 0 None [] lines
;;

(* Status enums, read from tigerbeetle.zig so the codes are never transcribed by hand. *)

let status_table lines enum_name =
  let header = Printf.sprintf "pub const %s = enum(u32) {" enum_name in
  let rec find = function
    | [] -> failwith ("enum not found: " ^ enum_name)
    | line :: rest -> if String.trim line = header then collect [] rest else find rest
  and collect acc = function
    | [] -> acc
    | line :: rest ->
      let t = String.trim line in
      if starts_with ~prefix:"}" t
      then acc
      else (
        match String.index_opt t '=' with
        | Some i when String.ends_with ~suffix:"," t && not (starts_with ~prefix:"//" t)
          ->
          let name = String.trim (String.sub t 0 i) in
          let value = String.trim (String.sub t (i + 1) (String.length t - i - 2)) in
          let code =
            if name = "created"
            then Some Result_code.created_code
            else int_of_string_opt value
          in
          (match code with
           | Some code -> collect ((name, code) :: acc) rest
           | None -> collect acc rest)
        | _ -> collect acc rest)
  in
  find lines
;;

type statuses =
  { codes : (string * int) list
  ; supported : int list
  }

let code_of statuses name =
  match List.assoc_opt name statuses.codes with
  | Some code -> code
  | None -> parse_error "unknown status %s" name
;;

let name_of statuses code =
  match List.find_opt (fun (_, c) -> c = code) statuses.codes with
  | Some (name, _) -> name
  | None -> string_of_int code
;;

(* Table grammar: whitespace-separated columns, [_] selects the default, a leading letter
   is a visual comment, and [-n] for an unsigned column means [maxInt - n]. *)

type cursor = { mutable tokens : string list }

let peek c =
  match c.tokens with
  | t :: _ -> Some t
  | [] -> None
;;

let next c =
  match c.tokens with
  | t :: rest ->
    c.tokens <- rest;
    t
  | [] -> parse_error "row ended early"
;;

let strip_letter t =
  if t <> ""
     &&
     match t.[0] with
     | 'a' .. 'z' | 'A' .. 'Z' -> true
     | _ -> false
  then String.sub t 1 (String.length t - 1)
  else t
;;

let unsigned_max bits =
  if bits = 128
  then U128.max_value
  else Result.get_ok (U128.sub (U128.shift_left U128.one bits) U128.one)
;;

let parse_unsigned bits token =
  let t = strip_letter token in
  let of_string s =
    match U128.of_string_opt s with
    | Some v -> v
    | None -> parse_error "bad integer %s" token
  in
  if t <> "" && t.[0] = '-'
  then (
    match
      U128.sub (unsigned_max bits) (of_string (String.sub t 1 (String.length t - 1)))
    with
    | Ok v -> v
    | Error `Underflow -> parse_error "bad integer %s" token)
  else of_string t
;;

let field c ~default parse =
  match peek c with
  | Some "_" ->
    ignore (next c);
    default
  | _ -> parse (next c)
;;

let low64 x = snd (U128.to_int64_pair x)
let u128 c = field c ~default:U128.zero (parse_unsigned 128)
let u64 c = field c ~default:0L (fun t -> low64 (parse_unsigned 64 t))
let u32 c = field c ~default:0l (fun t -> Int64.to_int32 (low64 (parse_unsigned 32 t)))

let uint bits c =
  field c ~default:0 (fun t -> Int64.to_int (low64 (parse_unsigned bits t)))
;;

let opt c parse =
  match peek c with
  | Some "_" ->
    ignore (next c);
    None
  | None -> None
  | Some _ -> Some (parse c)
;;

let flag c tag =
  field c ~default:false (fun t ->
    if t = tag then true else parse_error "expected %s or _, got %s" tag t)
;;

type balances =
  { b_debits_pending : U128.t
  ; b_debits_posted : U128.t
  ; b_credits_pending : U128.t
  ; b_credits_posted : U128.t
  ; b_closed : bool
  }

type lookup_transfer_data =
  | Exists of bool
  | Amount of U128.t
  | Timestamp of int64

type account_filter_spec =
  { a_filter : account_filter
  ; a_min_id : U128.t option
  ; a_max_id : U128.t option
  }

type query_filter_spec =
  { q_filter : query_filter
  ; q_min_id : U128.t option
  ; q_max_id : U128.t option
  }

type action =
  | Setup of U128.t * balances
  | Tick of int64
  | Commit of string
  | Create_account of account * string
  | Create_transfer of transfer * string
  | Lookup_account of U128.t * balances option
  | Lookup_transfer of U128.t * lookup_transfer_data
  | Get_account_balances of account_filter_spec
  | Get_account_balances_result of U128.t * balances
  | Get_account_transfers of account_filter_spec
  | Get_account_transfers_result of U128.t
  | Query_accounts of query_filter_spec
  | Query_accounts_result of U128.t * balances option
  | Query_transfers of query_filter_spec
  | Query_transfers_result of U128.t
  | Get_change_events
  | Unrepresentable of string

let balances ~closed c =
  let b_debits_pending = u128 c in
  let b_debits_posted = u128 c in
  let b_credits_pending = u128 c in
  let b_credits_posted = u128 c in
  let b_closed = if closed then flag c "CLSD" else false in
  { b_debits_pending; b_debits_posted; b_credits_pending; b_credits_posted; b_closed }
;;

let parse_account c =
  let id = u128 c in
  let debits_pending = u128 c in
  let debits_posted = u128 c in
  let credits_pending = u128 c in
  let credits_posted = u128 c in
  let user_data_128 = u128 c in
  let user_data_64 = u64 c in
  let user_data_32 = u32 c in
  let reserved = uint 1 c in
  let ledger = u32 c in
  let code = uint 16 c in
  let linked = flag c "LNK" in
  let debits_must_not_exceed_credits = flag c "D<C" in
  let credits_must_not_exceed_debits = flag c "C<D" in
  let history = flag c "HIST" in
  let imported = flag c "IMP" in
  let closed = flag c "CLSD" in
  let padding = uint 10 c in
  let timestamp = u64 c in
  let status = next c in
  if reserved <> 0 || padding <> 0
  then Unrepresentable "account reserved/padding bits"
  else
    Create_account
      ( { id
        ; debits_pending
        ; debits_posted
        ; credits_pending
        ; credits_posted
        ; user_data_128
        ; user_data_64
        ; user_data_32
        ; ledger
        ; code
        ; flags =
            { linked
            ; debits_must_not_exceed_credits
            ; credits_must_not_exceed_debits
            ; history
            ; imported
            ; closed
            }
        ; timestamp
        }
      , status )
;;

let parse_transfer c =
  let id = u128 c in
  let debit_account_id = u128 c in
  let credit_account_id = u128 c in
  let amount = u128 c in
  let pending_id = u128 c in
  let user_data_128 = u128 c in
  let user_data_64 = u64 c in
  let user_data_32 = u32 c in
  let timeout = u32 c in
  let ledger = u32 c in
  let code = uint 16 c in
  let linked = flag c "LNK" in
  let pending = flag c "PEN" in
  let post_pending_transfer = flag c "POS" in
  let void_pending_transfer = flag c "VOI" in
  let balancing_debit = flag c "BDR" in
  let balancing_credit = flag c "BCR" in
  let imported = flag c "IMP" in
  let closing_debit = flag c "CDR" in
  let closing_credit = flag c "CCR" in
  let padding = uint 5 c in
  let timestamp = u64 c in
  let status = next c in
  if padding <> 0
  then Unrepresentable "transfer padding bits"
  else
    Create_transfer
      ( { id
        ; debit_account_id
        ; credit_account_id
        ; amount
        ; pending_id
        ; user_data_128
        ; user_data_64
        ; user_data_32
        ; timeout
        ; ledger
        ; code
        ; flags =
            { linked
            ; pending
            ; post_pending_transfer
            ; void_pending_transfer
            ; balancing_debit
            ; balancing_credit
            ; closing_debit
            ; closing_credit
            ; imported
            }
        ; timestamp
        }
      , status )
;;

let parse_account_filter c =
  let account_id = u128 c in
  let user_data_128 = u128 c in
  let user_data_64 = u64 c in
  let user_data_32 = u32 c in
  let code = uint 16 c in
  let a_min_id = opt c u128 in
  let a_max_id = opt c u128 in
  let limit = uint 32 c in
  let debits = flag c "DR" in
  let credits = flag c "CR" in
  let reversed = flag c "REV" in
  { a_filter =
      { account_id
      ; user_data_128
      ; user_data_64
      ; user_data_32
      ; code
      ; timestamp_min = 0L
      ; timestamp_max = 0L
      ; limit
      ; debits
      ; credits
      ; reversed
      }
  ; a_min_id
  ; a_max_id
  }
;;

let parse_query_filter c =
  let user_data_128 = u128 c in
  let user_data_64 = u64 c in
  let user_data_32 = u32 c in
  let ledger = u32 c in
  let code = uint 16 c in
  let q_min_id = opt c u128 in
  let q_max_id = opt c u128 in
  let limit = uint 32 c in
  let reversed = flag c "REV" in
  { q_filter =
      { user_data_128
      ; user_data_64
      ; user_data_32
      ; ledger
      ; code
      ; timestamp_min = 0L
      ; timestamp_max = 0L
      ; limit
      ; reversed
      }
  ; q_min_id
  ; q_max_id
  }
;;

let parse_row row =
  let c = { tokens = row } in
  let action =
    match next c with
    | "setup" ->
      let id = u128 c in
      Setup (id, balances ~closed:false c)
    | "tick" ->
      let value =
        match Int64.of_string_opt (strip_letter (next c)) with
        | Some v -> v
        | None -> parse_error "bad tick"
      in
      let unit =
        match next c with
        | "nanoseconds" -> 1L
        | "seconds" -> 1_000_000_000L
        | u -> parse_error "bad tick unit %s" u
      in
      Tick (Int64.mul value unit)
    | "commit" -> Commit (next c)
    | "account" -> parse_account c
    | "transfer" -> parse_transfer c
    | "lookup_account" ->
      let id = u128 c in
      Lookup_account (id, opt c (balances ~closed:true))
    | "lookup_transfer" ->
      let id = u128 c in
      let data =
        match next c with
        | "exists" -> Exists (not (List.mem (next c) [ "0"; "false"; "F" ]))
        | "amount" -> Amount (u128 c)
        | "timestamp" -> Timestamp (u64 c)
        | v -> parse_error "bad lookup_transfer variant %s" v
      in
      Lookup_transfer (id, data)
    | "get_account_balances" -> Get_account_balances (parse_account_filter c)
    | "get_account_balances_result" ->
      let id = u128 c in
      Get_account_balances_result (id, balances ~closed:false c)
    | "get_account_transfers" -> Get_account_transfers (parse_account_filter c)
    | "get_account_transfers_result" -> Get_account_transfers_result (u128 c)
    | "query_accounts" -> Query_accounts (parse_query_filter c)
    | "query_accounts_result" ->
      let id = u128 c in
      Query_accounts_result (id, opt c (balances ~closed:true))
    | "query_transfers" -> Query_transfers (parse_query_filter c)
    | "query_transfers_result" -> Query_transfers_result (u128 c)
    | "get_change_events" | "get_change_events_result" ->
      c.tokens <- [];
      Get_change_events
    | v -> parse_error "unknown action %s" v
  in
  if c.tokens <> [] then parse_error "trailing columns: %s" (String.concat " " c.tokens);
  action
;;

(* Rendering, so mismatches are readable and comparison is structural. *)

let s = U128.to_string

let render_account (a : account) =
  let f = a.flags in
  let flags =
    [ f.linked, "LNK"
    ; f.debits_must_not_exceed_credits, "D<C"
    ; f.credits_must_not_exceed_debits, "C<D"
    ; f.history, "HIST"
    ; f.imported, "IMP"
    ; f.closed, "CLSD"
    ]
    |> List.filter_map (fun (on, n) -> if on then Some n else None)
    |> String.concat ","
  in
  Printf.sprintf
    "account(id=%s %s/%s/%s/%s u=%s/%Lu/%lu L%lu C%d [%s] ts=%Lu)"
    (s a.id)
    (s a.debits_pending)
    (s a.debits_posted)
    (s a.credits_pending)
    (s a.credits_posted)
    (s a.user_data_128)
    a.user_data_64
    a.user_data_32
    a.ledger
    a.code
    flags
    a.timestamp
;;

let render_transfer (t : transfer) =
  let f = t.flags in
  let flags =
    [ f.linked, "LNK"
    ; f.pending, "PEN"
    ; f.post_pending_transfer, "POS"
    ; f.void_pending_transfer, "VOI"
    ; f.balancing_debit, "BDR"
    ; f.balancing_credit, "BCR"
    ; f.imported, "IMP"
    ; f.closing_debit, "CDR"
    ; f.closing_credit, "CCR"
    ]
    |> List.filter_map (fun (on, n) -> if on then Some n else None)
    |> String.concat ","
  in
  Printf.sprintf
    "transfer(id=%s %s->%s amount=%s pending=%s u=%s/%Lu/%lu timeout=%lu L%lu C%d [%s] \
     ts=%Lu)"
    (s t.id)
    (s t.debit_account_id)
    (s t.credit_account_id)
    (s t.amount)
    (s t.pending_id)
    (s t.user_data_128)
    t.user_data_64
    t.user_data_32
    t.timeout
    t.ledger
    t.code
    flags
    t.timestamp
;;

let render_balance (a : account) =
  Printf.sprintf
    "balance(%s/%s/%s/%s ts=%Lu)"
    (s a.debits_pending)
    (s a.debits_posted)
    (s a.credits_pending)
    (s a.credits_posted)
    a.timestamp
;;

(* Execution, mirroring TestContext's prepare/pulse clock. *)

let timestamp_max = Int64.max_int
let pulse_batch_max = 30L

let timeout_ns timeout =
  Int64.mul (Int64.logand (Int64.of_int32 timeout) 0xffff_ffffL) 1_000_000_000L
;;

type request =
  | R_account of account
  | R_transfer of transfer
  | R_id of U128.t
  | R_account_filter of account_filter
  | R_query_filter of query_filter

type expected =
  | E_create of string * int64
  | E_render of string

type ctx =
  { sm : t
  ; accounts_status : statuses
  ; transfers_status : statuses
  ; mutable prepare_timestamp : int64
  ; mutable pulse_next_timestamp : int64
  ; mutable expiries : (int64 * U128.t) list
  ; accounts : (U128.t, account) Hashtbl.t
  ; transfers : (U128.t, transfer) Hashtbl.t
  ; linked_events_failed : (U128.t, int64) Hashtbl.t
  ; mutable requests : request list
  ; mutable expected : expected list
  ; mutable commits : int
  ; mutable mismatches : string list
  ; mutable status_mismatches : int
  ; mutable timestamp_mismatches : int
  }

let find table id =
  match Hashtbl.find_opt table id with
  | Some v -> v
  | None -> failwith ("model has no object " ^ s id)
;;

let mismatch ctx fmt =
  Printf.ksprintf (fun m -> ctx.mismatches <- m :: ctx.mismatches) fmt
;;

let push ctx request expected =
  ctx.requests <- request :: ctx.requests;
  ctx.expected <- List.rev_append expected ctx.expected
;;

let with_balances (a : account) b =
  { a with
    debits_pending = b.b_debits_pending
  ; debits_posted = b.b_debits_posted
  ; credits_pending = b.b_credits_pending
  ; credits_posted = b.b_credits_posted
  ; flags = { a.flags with closed = b.b_closed }
  }
;;

let pulse ctx =
  if Int64.compare ctx.pulse_next_timestamp ctx.prepare_timestamp <= 0
  then (
    ctx.prepare_timestamp <- Int64.add ctx.prepare_timestamp (Int64.succ pulse_batch_max);
    let timestamp = ctx.prepare_timestamp in
    ignore (expire_pending_transfers ctx.sm ~timestamp : int);
    ctx.expiries
    <- List.filter
         (fun (expires_at, _) -> Int64.compare expires_at timestamp > 0)
         ctx.expiries;
    ctx.pulse_next_timestamp
    <- List.fold_left (fun m (e, _) -> Int64.min m e) timestamp_max ctx.expiries)
;;

(* Expected [create_*] result for the next event, following [check_version]: every result
   carries the event's own commit timestamp except [exists], which echoes the original
   object (or the rolled-back event of the same id in the current linked chain). *)
let expected_create ctx ~existing ~id ~linked ~status ~timestamp =
  let count = List.length ctx.requests + 1 in
  let timestamp_commit = Int64.add ctx.prepare_timestamp (Int64.of_int (count + 1)) in
  let event_timestamp =
    if Int64.equal timestamp 0L then timestamp_commit else timestamp
  in
  let expected_timestamp =
    if status = "created" || status = "linked_event_failed"
    then event_timestamp
    else if status = "exists"
    then (
      match existing with
      | Some existing -> existing
      | None -> find ctx.linked_events_failed id)
    else timestamp_commit
  in
  if linked
  then (
    if status = "linked_event_failed"
    then Hashtbl.replace ctx.linked_events_failed id event_timestamp)
  else Hashtbl.reset ctx.linked_events_failed;
  event_timestamp, expected_timestamp
;;

let add_account ctx (a : account) status =
  let existing =
    Option.map (fun (e : account) -> e.timestamp) (Hashtbl.find_opt ctx.accounts a.id)
  in
  let event_timestamp =
    Int64.add ctx.prepare_timestamp (Int64.of_int (List.length ctx.requests + 2))
  in
  let event_timestamp =
    if Int64.equal a.timestamp 0L then event_timestamp else a.timestamp
  in
  if status = "created"
  then Hashtbl.replace ctx.accounts a.id { a with timestamp = event_timestamp };
  let existing = if status = "created" then Some event_timestamp else existing in
  let _, expected_timestamp =
    expected_create
      ctx
      ~existing
      ~id:a.id
      ~linked:a.flags.linked
      ~status
      ~timestamp:a.timestamp
  in
  push ctx (R_account a) [ E_create (status, expected_timestamp) ]
;;

let add_transfer ctx (t : transfer) status =
  let existing =
    Option.map (fun (e : transfer) -> e.timestamp) (Hashtbl.find_opt ctx.transfers t.id)
  in
  let event_timestamp =
    Int64.add ctx.prepare_timestamp (Int64.of_int (List.length ctx.requests + 2))
  in
  let event_timestamp =
    if Int64.equal t.timestamp 0L then event_timestamp else t.timestamp
  in
  let event = { t with timestamp = event_timestamp } in
  if status = "created"
  then (
    let event =
      if U128.is_zero event.pending_id
      then event
      else (
        let p = find ctx.transfers event.pending_id in
        let pick a b = if U128.is_zero a then b else a in
        let event =
          { event with
            debit_account_id = pick event.debit_account_id p.debit_account_id
          ; credit_account_id = pick event.credit_account_id p.credit_account_id
          ; ledger = (if event.ledger = 0l then p.ledger else event.ledger)
          ; code = (if event.code = 0 then p.code else event.code)
          ; user_data_128 = pick event.user_data_128 p.user_data_128
          ; user_data_64 =
              (if event.user_data_64 = 0L then p.user_data_64 else event.user_data_64)
          ; user_data_32 =
              (if event.user_data_32 = 0l then p.user_data_32 else event.user_data_32)
          }
        in
        if event.flags.void_pending_transfer && U128.is_zero event.amount
        then { event with amount = p.amount }
        else event)
    in
    Hashtbl.replace ctx.transfers t.id event);
  let existing = if status = "created" then Some event_timestamp else existing in
  let _, expected_timestamp =
    expected_create
      ctx
      ~existing
      ~id:t.id
      ~linked:t.flags.linked
      ~status
      ~timestamp:t.timestamp
  in
  push ctx (R_transfer t) [ E_create (status, expected_timestamp) ]
;;

let timestamp_of_transfer ctx = function
  | None -> 0L
  | Some id -> (find ctx.transfers id).timestamp
;;

let timestamp_of_account ctx = function
  | None -> 0L
  | Some id -> (find ctx.accounts id).timestamp
;;

let compare_rendered ctx op expected actual =
  let expected =
    List.filter_map
      (function
        | E_render r -> Some r
        | E_create _ -> None)
      expected
  in
  if expected <> actual
  then (
    let rec first i = function
      | e :: es, a :: as_ -> if e = a then first (i + 1) (es, as_) else Some (i, e, a)
      | e :: _, [] -> Some (i, e, "<missing>")
      | [], a :: _ -> Some (i, "<missing>", a)
      | [], [] -> None
    in
    match first 0 (expected, actual) with
    | Some (i, e, a) ->
      mismatch
        ctx
        "commit %d %s: %d results expected, %d returned; [%d] expected %s got %s"
        ctx.commits
        op
        (List.length expected)
        (List.length actual)
        i
        e
        a
    | None -> ())
;;

let compare_creates ctx op statuses expected actual =
  let expected =
    List.filter_map
      (function
        | E_create (n, t) -> Some (n, t)
        | E_render _ -> None)
      expected
  in
  if List.length expected <> List.length actual
  then mismatch ctx "commit %d %s: result count differs" ctx.commits op
  else
    List.iteri
      (fun i ((name, ts), (codes, actual_ts)) ->
        let code = code_of statuses name in
        let status_ok = List.mem code codes in
        let ts_ok = Int64.equal ts actual_ts in
        if not status_ok
        then ctx.status_mismatches <- ctx.status_mismatches + 1
        else if not ts_ok
        then ctx.timestamp_mismatches <- ctx.timestamp_mismatches + 1;
        if not (status_ok && ts_ok)
        then
          mismatch
            ctx
            "commit %d %s: [%d] expected %s@%Lu got %s@%Lu"
            ctx.commits
            op
            i
            name
            ts
            (String.concat "|" (List.map (name_of statuses) codes))
            actual_ts)
      (List.combine expected actual)
;;

let track_expiries ctx transfers results =
  List.iter2
    (fun (t : transfer) (r : create_transfer_status create_result) ->
      if r.status = Transfer_created
      then
        if t.flags.pending && t.timeout <> 0l && not t.flags.imported
        then (
          let expires_at = Int64.add r.timestamp (timeout_ns t.timeout) in
          ctx.expiries <- (expires_at, t.id) :: ctx.expiries;
          ctx.pulse_next_timestamp <- Int64.min ctx.pulse_next_timestamp expires_at)
        else if t.flags.post_pending_transfer || t.flags.void_pending_transfer
        then (
          match
            List.find_opt (fun (_, id) -> U128.equal id t.pending_id) ctx.expiries
          with
          | Some (expires_at, _) ->
            ctx.expiries
            <- List.filter (fun (_, id) -> not (U128.equal id t.pending_id)) ctx.expiries;
            if Int64.equal expires_at ctx.pulse_next_timestamp
            then ctx.pulse_next_timestamp <- 1L
          | None -> ()))
    transfers
    results
;;

let commit ctx op =
  ctx.commits <- ctx.commits + 1;
  let requests = List.rev ctx.requests in
  let expected = List.rev ctx.expected in
  ctx.requests <- [];
  ctx.expected <- [];
  let count = List.length requests in
  let delta = if op = "create_accounts" || op = "create_transfers" then count else 0 in
  ctx.prepare_timestamp <- Int64.add ctx.prepare_timestamp (Int64.of_int (1 + delta));
  let pulse_needed = Int64.compare ctx.pulse_next_timestamp ctx.prepare_timestamp <= 0 in
  let timestamp = ctx.prepare_timestamp in
  let first_event_timestamp = Int64.succ (Int64.sub timestamp (Int64.of_int count)) in
  let ids =
    List.filter_map
      (function
        | R_id id -> Some id
        | _ -> None)
      requests
  in
  let one_filter f =
    match requests with
    | [ request ] -> f request
    | _ -> failwith "query operations take exactly one filter"
  in
  (match op with
   | "create_accounts" ->
     let accounts =
       List.filter_map
         (function
           | R_account a -> Some a
           | _ -> None)
         requests
     in
     let results = create_accounts ctx.sm ~timestamp:first_event_timestamp accounts in
     compare_creates
       ctx
       op
       ctx.accounts_status
       expected
       (List.map
          (fun (r : create_account_status create_result) ->
            Result_code.account_codes r.status, r.timestamp)
          results)
   | "create_transfers" ->
     let transfers =
       List.filter_map
         (function
           | R_transfer t -> Some t
           | _ -> None)
         requests
     in
     let results = create_transfers ctx.sm ~timestamp:first_event_timestamp transfers in
     track_expiries ctx transfers results;
     compare_creates
       ctx
       op
       ctx.transfers_status
       expected
       (List.map
          (fun (r : create_transfer_status create_result) ->
            Result_code.transfer_codes r.status, r.timestamp)
          results)
   | "lookup_accounts" ->
     compare_rendered
       ctx
       op
       expected
       (List.map render_account (lookup_accounts ctx.sm ids))
   | "lookup_transfers" ->
     compare_rendered
       ctx
       op
       expected
       (List.map render_transfer (lookup_transfers ctx.sm ids))
   | "get_account_balances" ->
     one_filter (function
       | R_account_filter f ->
         compare_rendered
           ctx
           op
           expected
           (List.map render_balance (get_account_balances ctx.sm f))
       | _ -> failwith "expected an account filter")
   | "get_account_transfers" ->
     one_filter (function
       | R_account_filter f ->
         compare_rendered
           ctx
           op
           expected
           (List.map render_transfer (get_account_transfers ctx.sm f))
       | _ -> failwith "expected an account filter")
   | "query_accounts" ->
     one_filter (function
       | R_query_filter f ->
         compare_rendered
           ctx
           op
           expected
           (List.map render_account (query_accounts ctx.sm f))
       | _ -> failwith "expected a query filter")
   | "query_transfers" ->
     one_filter (function
       | R_query_filter f ->
         compare_rendered
           ctx
           op
           expected
           (List.map render_transfer (query_transfers ctx.sm f))
       | _ -> failwith "expected a query filter")
   | op -> failwith ("unsupported operation " ^ op));
  if pulse_needed then pulse ctx
;;

let step ctx = function
  | Setup (id, b) ->
    (match lookup_accounts ctx.sm [ id ] with
     | [ account ] ->
       unsafe_replace_account_for_testing
         ctx.sm
         (with_balances account { b with b_closed = account.flags.closed })
     | _ -> failwith ("setup: no account " ^ s id))
  | Tick interval ->
    ctx.prepare_timestamp
    <- Int64.add
         ctx.prepare_timestamp
         (if Int64.compare interval 0L > 0
          then interval
          else Int64.sub timestamp_max (Int64.neg interval));
    pulse ctx
  | Commit op -> commit ctx op
  | Create_account (a, status) -> add_account ctx a status
  | Create_transfer (t, status) -> add_transfer ctx t status
  | Lookup_account (id, data) ->
    push
      ctx
      (R_id id)
      (match data with
       | None -> []
       | Some b -> [ E_render (render_account (with_balances (find ctx.accounts id) b)) ])
  | Lookup_transfer (id, data) ->
    let expected =
      match data with
      | Exists false -> []
      | Exists true -> [ find ctx.transfers id ]
      | Amount amount -> [ { (find ctx.transfers id) with amount } ]
      | Timestamp timestamp -> [ { (find ctx.transfers id) with timestamp } ]
    in
    push ctx (R_id id) (List.map (fun t -> E_render (render_transfer t)) expected)
  | Get_account_balances f | Get_account_transfers f ->
    push
      ctx
      (R_account_filter
         { f.a_filter with
           timestamp_min = timestamp_of_transfer ctx f.a_min_id
         ; timestamp_max = timestamp_of_transfer ctx f.a_max_id
         })
      []
  | Get_account_balances_result (id, b) ->
    let rendered =
      Printf.sprintf
        "balance(%s/%s/%s/%s ts=%Lu)"
        (s b.b_debits_pending)
        (s b.b_debits_posted)
        (s b.b_credits_pending)
        (s b.b_credits_posted)
        (find ctx.transfers id).timestamp
    in
    ctx.expected <- E_render rendered :: ctx.expected
  | Get_account_transfers_result id | Query_transfers_result id ->
    ctx.expected <- E_render (render_transfer (find ctx.transfers id)) :: ctx.expected
  | Query_accounts f ->
    push
      ctx
      (R_query_filter
         { f.q_filter with
           timestamp_min = timestamp_of_account ctx f.q_min_id
         ; timestamp_max = timestamp_of_account ctx f.q_max_id
         })
      []
  | Query_accounts_result (id, data) ->
    let account = find ctx.accounts id in
    let account =
      match data with
      | None -> account
      | Some b -> with_balances account b
    in
    ctx.expected <- E_render (render_account account) :: ctx.expected
  | Query_transfers f ->
    push
      ctx
      (R_query_filter
         { f.q_filter with
           timestamp_min = timestamp_of_transfer ctx f.q_min_id
         ; timestamp_max = timestamp_of_transfer ctx f.q_max_id
         })
      []
  | Get_change_events | Unrepresentable _ -> assert false
;;

let unsupported ctx actions =
  List.find_map
    (function
      | Get_change_events -> Some "get_change_events (CDC) is not implemented"
      | Unrepresentable what -> Some (what ^ " are not representable")
      | Create_account (_, status)
        when not
               (List.mem
                  (code_of ctx.accounts_status status)
                  ctx.accounts_status.supported) ->
        Some ("account status " ^ status ^ " has no OCaml equivalent")
      | Create_transfer (_, status)
        when not
               (List.mem
                  (code_of ctx.transfers_status status)
                  ctx.transfers_status.supported) ->
        Some ("transfer status " ^ status ^ " has no OCaml equivalent")
      | _ -> None)
    actions
;;

type outcome =
  | Pass
  | Fail of string list
  | Skip of string

let run_scenario ~accounts_status ~transfers_status scenario =
  let ctx =
    { sm = empty ()
    ; accounts_status
    ; transfers_status
    ; prepare_timestamp = 0L
    ; pulse_next_timestamp = timestamp_max
    ; expiries = []
    ; accounts = Hashtbl.create 16
    ; transfers = Hashtbl.create 16
    ; linked_events_failed = Hashtbl.create 16
    ; requests = []
    ; expected = []
    ; commits = 0
    ; mismatches = []
    ; status_mismatches = 0
    ; timestamp_mismatches = 0
    }
  in
  let outcome =
    match List.map parse_row scenario.rows with
    | exception Parse message -> Skip ("table parse error: " ^ message)
    | actions ->
      (match unsupported ctx actions with
       | Some reason -> Skip reason
       | None ->
         (match List.iter (step ctx) actions with
          | () -> if ctx.mismatches = [] then Pass else Fail (List.rev ctx.mismatches)
          | exception (Failure m | Invalid_argument m) ->
            Fail (List.rev (("exception: " ^ m) :: ctx.mismatches))
          | exception Parse m -> Fail (List.rev (("exception: " ^ m) :: ctx.mismatches))))
  in
  outcome, ctx.status_mismatches, ctx.timestamp_mismatches
;;

let () =
  let read path = In_channel.with_open_text path In_channel.input_lines in
  let corpus, tigerbeetle =
    match Sys.argv with
    | [| _; corpus; tigerbeetle |] -> read corpus, read tigerbeetle
    | _ -> failwith "usage: zig_corpus STATE_MACHINE_TESTS_ZIG TIGERBEETLE_ZIG"
  in
  let statuses enum supported =
    { codes = status_table tigerbeetle enum
    ; supported = List.concat_map Fun.id supported
    }
  in
  let accounts_status =
    statuses
      "CreateAccountStatus"
      (List.map Result_code.account_codes Result_code.account_statuses)
  in
  let transfers_status =
    statuses
      "CreateTransferStatus"
      (List.map Result_code.transfer_codes Result_code.transfer_statuses)
  in
  let scenarios = extract_scenarios corpus in
  let pass = ref 0
  and fail = ref 0
  and skip = ref 0
  and status_mismatches = ref 0
  and timestamp_mismatches = ref 0 in
  List.iter
    (fun scenario ->
      let outcome, sm, tm = run_scenario ~accounts_status ~transfers_status scenario in
      status_mismatches := !status_mismatches + sm;
      timestamp_mismatches := !timestamp_mismatches + tm;
      match outcome with
      | Pass ->
        incr pass;
        Printf.printf "PASS %s\n" scenario.name
      | Skip reason ->
        incr skip;
        Printf.printf "SKIP %s: %s\n" scenario.name reason
      | Fail mismatches ->
        incr fail;
        Printf.printf "FAIL %s (%d mismatches)\n" scenario.name (List.length mismatches);
        List.iteri (fun i m -> if i < 3 then Printf.printf "  %s\n" m) mismatches)
    scenarios;
  Printf.printf
    "\n\
     %d scenarios: %d pass, %d fail, %d skip\n\
     create results: %d status mismatches, %d timestamp-only mismatches\n"
    (List.length scenarios)
    !pass
    !fail
    !skip
    !status_mismatches
    !timestamp_mismatches
;;
