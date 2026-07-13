open Tigerbeetle_state_machine.State_machine

let u128 = U128.of_int

let account id =
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
      ; history = false
      ; imported = false
      ; closed = false
      }
  ; timestamp = 0L
  }
;;

let () =
  let operations = 30_000 in
  let batch_size = 1 in
  let state = empty () in
  let batches =
    Array.init
      (operations / batch_size)
      (fun batch ->
        let first_id = (batch * batch_size) + 10 in
        List.init batch_size (fun offset -> account (first_id + offset)))
  in
  Gc.full_major ();
  let gc_before = Gc.quick_stat () in
  let started = Unix.gettimeofday () in
  Array.iteri
    (fun batch requests ->
    ignore
      (create_accounts
         state
         ~timestamp:(Int64.of_int ((batch * batch_size) + 3))
         requests))
    batches;
  let elapsed = Unix.gettimeofday () -. started in
  let gc_after = Gc.quick_stat () in
  let allocated_words =
    gc_after.minor_words
    +. gc_after.major_words
    -. gc_before.minor_words
    -. gc_before.major_words
  in
  Printf.printf "implementation=ocaml\n";
  Printf.printf "operations=%d\n" operations;
  Printf.printf "batch_size=%d\n" batch_size;
  Printf.printf "operations_per_second=%.0f\n" (float operations /. elapsed);
  Printf.printf
    "batch_latency_ms=%.6f\n"
    (elapsed *. 1_000. /. float (operations / batch_size));
  Printf.printf "allocated_words=%.0f\n" allocated_words;
  Printf.printf
    "allocated_words_per_operation=%.2f\n"
    (allocated_words /. float operations)
;;
