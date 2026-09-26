open Tigerbeetle_state_machine.State_machine

let u128 = U128.of_int

let account ?(history = false) id =
  { id = u128 id
  ; debits_pending = U128.zero
  ; debits_posted = U128.zero
  ; credits_pending = U128.zero
  ; credits_posted = U128.zero
  ; user_data_128 = U128.zero
  ; user_data_64 = 0L
  ; user_data_32 = 0l
  ; ledger = 1l
  ; code = 1
  ; flags =
      { linked = false
      ; debits_must_not_exceed_credits = false
      ; credits_must_not_exceed_debits = false
      ; history
      ; imported = false
      ; closed = false
      }
  ; timestamp = 0L
  }
;;

let flags
  ?(linked = false)
  ?(pending = false)
  ?(post_pending_transfer = false)
  ?(void_pending_transfer = false)
  ()
  =
  { linked
  ; pending
  ; post_pending_transfer
  ; void_pending_transfer
  ; balancing_debit = false
  ; balancing_credit = false
  ; closing_debit = false
  ; closing_credit = false
  ; imported = false
  }
;;

let transfer
  ?(flags = flags ())
  ?(pending_id = U128.zero)
  ?(timeout = 0l)
  ?(debit = 1)
  ?(credit = 2)
  id
  =
  { id = u128 id
  ; debit_account_id = u128 debit
  ; credit_account_id = u128 credit
  ; amount = u128 1
  ; pending_id
  ; user_data_128 = U128.zero
  ; user_data_64 = 0L
  ; user_data_32 = 0l
  ; timeout
  ; ledger = 1l
  ; code = 1
  ; flags
  ; timestamp = 0L
  }
;;

let operations = 30_000
let batch_size = 30
let account_count = 100

let accounts_setup ?history state =
  ignore
    (create_accounts
       state
       ~timestamp:1L
       (List.init account_count (fun i -> account ?history (i + 1))))
;;

let batches make =
  Array.init (operations / batch_size) (fun batch ->
    let first_id = (batch * batch_size) + 10 in
    List.init batch_size (fun offset -> make (first_id + offset)))
;;

let run_batches state ~first_timestamp requests f =
  Array.iteri
    (fun batch requests ->
      f
        state
        ~timestamp:(Int64.add first_timestamp (Int64.of_int (batch * batch_size)))
        requests)
    requests
;;

let spread id = (id mod account_count) + 1, ((id + 1) mod account_count) + 1

let measure name ~setup ~run =
  let state = setup () in
  Gc.full_major ();
  let gc_before = Gc.quick_stat () in
  let started = Unix.gettimeofday () in
  let count = run state in
  let elapsed = Unix.gettimeofday () -. started in
  let gc_after = Gc.quick_stat () in
  let allocated_words =
    gc_after.minor_words
    +. gc_after.major_words
    -. gc_before.minor_words
    -. gc_before.major_words
  in
  Printf.printf "workload=%s\n" name;
  Printf.printf "operations=%d\n" count;
  Printf.printf "operations_per_second=%.0f\n" (float count /. elapsed);
  Printf.printf "allocated_words_per_operation=%.2f\n" (allocated_words /. float count);
  print_newline ()
;;

let expect_created results context =
  List.iter
    (fun result ->
      if result.status <> Transfer_created
      then failwith (Printf.sprintf "%s: unexpected status" context))
    results
;;

let posted_transfers () =
  measure
    "posted_transfers"
    ~setup:(fun () ->
      let state = empty () in
      accounts_setup state;
      state)
    ~run:(fun state ->
      let requests =
        batches (fun id ->
          let debit, credit = spread id in
          transfer ~debit ~credit id)
      in
      run_batches state ~first_timestamp:1_000L requests (fun state ~timestamp requests ->
        expect_created (create_transfers state ~timestamp requests) "posted");
      operations)
;;

let two_phase () =
  measure
    "pending_then_post_or_void"
    ~setup:(fun () ->
      let state = empty () in
      accounts_setup state;
      state)
    ~run:(fun state ->
      let pending =
        batches (fun id ->
          let debit, credit = spread id in
          transfer ~debit ~credit ~flags:(flags ~pending:true ()) id)
      in
      run_batches state ~first_timestamp:1_000L pending (fun state ~timestamp requests ->
        expect_created (create_transfers state ~timestamp requests) "pending");
      let resolve =
        batches (fun id ->
          let pending_id = u128 id in
          let debit, credit = spread id in
          if id mod 2 = 0
          then
            transfer
              ~debit
              ~credit
              ~pending_id
              ~flags:(flags ~post_pending_transfer:true ())
              (id + operations)
          else
            transfer
              ~debit
              ~credit
              ~pending_id
              ~flags:(flags ~void_pending_transfer:true ())
              (id + operations))
      in
      run_batches
        state
        ~first_timestamp:100_000L
        resolve
        (fun state ~timestamp requests ->
           expect_created (create_transfers state ~timestamp requests) "resolve");
      2 * operations)
;;

let linked_chains () =
  measure
    "linked_chains"
    ~setup:(fun () ->
      let state = empty () in
      accounts_setup state;
      ignore
        (create_transfers
           state
           ~timestamp:500L
           (List.init 1_000 (fun i -> transfer ~debit:1 ~credit:2 (1_000_000 + i))));
      state)
    ~run:(fun state ->
      let requests =
        batches (fun id ->
          let debit, credit = spread id in
          let linked = id mod batch_size <> 9 in
          transfer ~debit ~credit ~flags:(flags ~linked ()) id)
      in
      run_batches
        state
        ~first_timestamp:100_000L
        requests
        (fun state ~timestamp requests ->
           expect_created (create_transfers state ~timestamp requests) "linked");
      operations)
;;

let failing_linked_chains () =
  measure
    "failing_linked_chains"
    ~setup:(fun () ->
      let state = empty () in
      accounts_setup state;
      ignore
        (create_transfers
           state
           ~timestamp:500L
           (List.init 1_000 (fun i -> transfer ~debit:1 ~credit:2 (1_000_000 + i))));
      state)
    ~run:(fun state ->
      let requests =
        batches (fun id ->
          let debit, credit = spread id in
          let last = id mod batch_size = 9 in
          if last
          then transfer ~debit ~credit:debit id
          else transfer ~debit ~credit ~flags:(flags ~linked:true ()) id)
      in
      run_batches
        state
        ~first_timestamp:100_000L
        requests
        (fun state ~timestamp requests ->
           let results = create_transfers state ~timestamp requests in
           if List.exists (fun result -> result.status = Transfer_created) results
           then failwith "failing chain unexpectedly succeeded");
      operations)
;;

let queries () =
  let filter =
    { user_data_128 = U128.zero
    ; user_data_64 = 0L
    ; user_data_32 = 0l
    ; ledger = 1l
    ; code = 1
    ; timestamp_min = 0L
    ; timestamp_max = 0L
    ; limit = 100
    ; reversed = false
    }
  in
  let account_filter =
    { account_id = u128 1
    ; user_data_128 = U128.zero
    ; user_data_64 = 0L
    ; user_data_32 = 0l
    ; code = 0
    ; timestamp_min = 0L
    ; timestamp_max = 0L
    ; limit = 100
    ; debits = true
    ; credits = true
    ; reversed = true
    }
  in
  measure
    "queries_over_populated_ledger"
    ~setup:(fun () ->
      let state = empty () in
      accounts_setup ~history:true state;
      let requests =
        batches (fun id ->
          let debit, credit = spread id in
          transfer ~debit ~credit id)
      in
      run_batches state ~first_timestamp:1_000L requests (fun state ~timestamp requests ->
        expect_created (create_transfers state ~timestamp requests) "populate");
      state)
    ~run:(fun state ->
      let iterations = 2_000 in
      for i = 1 to iterations do
        let timestamp_min = Int64.of_int (1_000 + (i * 10)) in
        let window =
          { filter with timestamp_min; timestamp_max = Int64.add timestamp_min 5_000L }
        in
        ignore (query_transfers state window);
        ignore (query_accounts state { window with limit = 10; ledger = 1l });
        ignore (get_account_transfers state account_filter);
        ignore (get_account_balances state { account_filter with limit = 10 })
      done;
      4 * iterations)
;;

let expiry () =
  measure
    "pending_expiry"
    ~setup:(fun () ->
      let state = empty () in
      accounts_setup state;
      let requests =
        batches (fun id ->
          let debit, credit = spread id in
          transfer ~debit ~credit ~timeout:1l ~flags:(flags ~pending:true ()) id)
      in
      run_batches state ~first_timestamp:1_000L requests (fun state ~timestamp requests ->
        expect_created (create_transfers state ~timestamp requests) "pending");
      state)
    ~run:(fun state ->
      let step = 2_000_000_000L in
      let expired = ref 0 in
      for i = 1 to 60 do
        expired
        := !expired
           + expire_pending_transfers state ~timestamp:(Int64.mul step (Int64.of_int i))
      done;
      if !expired <> operations then failwith "expiry count mismatch";
      operations)
;;

let () =
  Printf.printf "implementation=ocaml\nbatch_size=%d\n\n" batch_size;
  posted_transfers ();
  two_phase ();
  linked_chains ();
  failing_linked_chains ();
  queries ();
  expiry ()
;;
