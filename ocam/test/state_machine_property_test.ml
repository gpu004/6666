open Tigerbeetle_state_machine.State_machine

let u128 = U128.of_int

let account_flags () =
  { linked = false
  ; debits_must_not_exceed_credits = false
  ; credits_must_not_exceed_debits = false
  ; history = true
  ; imported = false
  ; closed = false
  }
;;

let transfer_flags ?(linked = false) ?(pending = false) ?(post = false) ?(void = false) ()
  =
  { linked
  ; pending
  ; post_pending_transfer = post
  ; void_pending_transfer = void
  ; balancing_debit = false
  ; balancing_credit = false
  ; closing_debit = false
  ; closing_credit = false
  ; imported = false
  }
;;

let account ?(user_data_64 = 0L) id =
  { id = u128 id
  ; debits_pending = U128.zero
  ; debits_posted = U128.zero
  ; credits_pending = U128.zero
  ; credits_posted = U128.zero
  ; user_data_128 = U128.zero
  ; user_data_64
  ; user_data_32 = 0l
  ; ledger = 1l
  ; code = 1
  ; flags = account_flags ()
  ; timestamp = 0L
  }
;;

let transfer
      ?(debit_account_id = 1)
      ?(credit_account_id = 2)
      ?(user_data_64 = 0L)
      ?(flags = transfer_flags ())
      ?(pending_id = U128.zero)
      ?(timeout = 0l)
      ~amount
      id
  =
  { id = u128 id
  ; debit_account_id = u128 debit_account_id
  ; credit_account_id = u128 credit_account_id
  ; amount = u128 amount
  ; pending_id
  ; user_data_128 = U128.zero
  ; user_data_64
  ; user_data_32 = 0l
  ; timeout
  ; ledger = 1l
  ; code = 1
  ; flags
  ; timestamp = 0L
  }
;;

let status_is expected result = result.status = expected

let exactly_one = function
  | [ value ] -> value
  | _ -> failwith "expected exactly one result"
;;

let account_of state id = exactly_one (lookup_accounts state [ u128 id ])

let add_exn left right =
  match U128.add left right with
  | Ok value -> value
  | Error `Overflow -> failwith "test balance total overflowed"
;;

let balances_equal left right = U128.equal left right

let balances_are_conserved state account_ids =
  let accounts = lookup_accounts state (List.map u128 account_ids) in
  let totals field =
    List.fold_left (fun total account -> add_exn total (field account)) U128.zero accounts
  in
  balances_equal
    (totals (fun account -> account.debits_pending))
    (totals (fun account -> account.credits_pending))
  && balances_equal
       (totals (fun account -> account.debits_posted))
       (totals (fun account -> account.credits_posted))
;;

let commands =
  QCheck.list_size
    (QCheck.Gen.int_range 0 24)
    (QCheck.pair QCheck.bool (QCheck.int_range 0 1_000))
;;

let run_commands state commands =
  ignore (create_accounts state ~timestamp:1L [ account 1; account 2 ]);
  List.iteri
    (fun index command ->
       let debit_to_credit, amount = command in
       let debit_account_id, credit_account_id = if debit_to_credit then 1, 2 else 2, 1 in
       ignore
         (create_transfers
            state
            ~timestamp:(Int64.of_int (index + 3))
            [ transfer ~debit_account_id ~credit_account_id ~amount (index + 10) ]))
    commands
;;

let account_snapshot state =
  List.map
    (fun (account : account) ->
       ( U128.to_string account.id
       , U128.to_string account.debits_pending
       , U128.to_string account.debits_posted
       , U128.to_string account.credits_pending
       , U128.to_string account.credits_posted
       , account.timestamp ))
    (lookup_accounts state [ u128 1; u128 2 ])
;;

let transfer_snapshot state commands =
  List.map
    (fun (transfer : transfer) ->
       U128.to_string transfer.id, U128.to_string transfer.amount, transfer.timestamp)
    (lookup_transfers
       state
       (List.init (List.length commands) (fun index -> u128 (index + 10))))
;;

let deterministic_execution =
  QCheck.Test.make ~name:"deterministic execution" ~count:100 commands (fun commands ->
    let left = empty () in
    let right = empty () in
    run_commands left commands;
    run_commands right commands;
    account_snapshot left = account_snapshot right
    && transfer_snapshot left commands = transfer_snapshot right commands)
;;

let balance_conservation =
  QCheck.Test.make
    ~name:"successful transfers conserve pending and posted balances"
    ~count:100
    commands
    (fun commands ->
       let state = empty () in
       run_commands state commands;
       balances_are_conserved state [ 1; 2 ])
;;

let validation_and_idempotency =
  QCheck.Test.make
    ~name:"validation rejects bad ids and exact retries are idempotent"
    ~count:100
    (QCheck.int_range 0 1_000)
    (fun amount ->
       let state = empty () in
       let invalid_account =
         exactly_one (create_accounts state ~timestamp:1L [ account 0 ])
       in
       let accounts = create_accounts state ~timestamp:2L [ account 1; account 2 ] in
       let retry_account =
         exactly_one (create_accounts state ~timestamp:3L [ account 1 ])
       in
       let request = transfer ~amount 10 in
       let created = exactly_one (create_transfers state ~timestamp:4L [ request ]) in
       let debit_after_create = (account_of state 1).debits_posted in
       let retry_transfer =
         exactly_one (create_transfers state ~timestamp:5L [ request ])
       in
       status_is Account_id_must_not_be_zero invalid_account
       && List.for_all (status_is Account_created) accounts
       && status_is Account_exists retry_account
       && status_is Transfer_created created
       && status_is Transfer_exists retry_transfer
       && U128.equal debit_after_create (account_of state 1).debits_posted)
;;

let linked_batch_atomicity =
  QCheck.Test.make
    ~name:"linked transfer batches are atomic"
    ~count:100
    (QCheck.int_range 0 1_000)
    (fun amount ->
       let state = empty () in
       ignore (create_accounts state ~timestamp:1L [ account 1; account 2 ]);
       let valid = transfer ~flags:(transfer_flags ~linked:true ()) ~amount 10 in
       let invalid = { (transfer ~amount 11) with ledger = 0l } in
       let results = create_transfers state ~timestamp:2L [ valid; invalid ] in
       let rolled_back =
         lookup_transfers state [ u128 10 ] = [] && balances_are_conserved state [ 1; 2 ]
       in
       let reusable =
         exactly_one
           (create_transfers
              state
              ~timestamp:3L
              [ { valid with flags = transfer_flags () } ])
       in
       match results with
       | [ first; second ] ->
         status_is Transfer_linked_event_failed first
         && status_is Transfer_ledger_must_not_be_zero second
         && rolled_back
         && status_is Transfer_created reusable
         && balances_are_conserved state [ 1; 2 ]
       | _ -> false)
;;

let pending_post_void_and_expiry =
  QCheck.Test.make
    ~name:"pending transfers post, void, and expire without leaving pending balances"
    ~count:100
    (QCheck.triple
       (QCheck.int_range 0 1_000)
       (QCheck.int_range 0 1_000)
       (QCheck.int_range 0 1_000))
    (fun (post_amount, void_amount, expire_amount) ->
       let state = empty () in
       ignore (create_accounts state ~timestamp:1L [ account 1; account 2 ]);
       let pending id amount timeout =
         transfer
           ~flags:(transfer_flags ~pending:true ())
           ~timeout:(Int32.of_int timeout)
           ~amount
           id
       in
       let first =
         exactly_one (create_transfers state ~timestamp:2L [ pending 10 post_amount 0 ])
       in
       let second =
         exactly_one (create_transfers state ~timestamp:3L [ pending 11 void_amount 0 ])
       in
       let third =
         exactly_one (create_transfers state ~timestamp:4L [ pending 12 expire_amount 1 ])
       in
       let post =
         exactly_one
           (create_transfers
              state
              ~timestamp:5L
              [ transfer
                  ~flags:(transfer_flags ~post:true ())
                  ~pending_id:(u128 10)
                  ~amount:post_amount
                  20
              ])
       in
       let void =
         exactly_one
           (create_transfers
              state
              ~timestamp:6L
              [ transfer
                  ~flags:(transfer_flags ~void:true ())
                  ~pending_id:(u128 11)
                  ~amount:0
                  21
              ])
       in
       let expired = expire_pending_transfers state ~timestamp:1_000_000_004L in
       let post_expired =
         exactly_one
           (create_transfers
              state
              ~timestamp:1_000_000_005L
              [ transfer
                  ~flags:(transfer_flags ~post:true ())
                  ~pending_id:(u128 12)
                  ~amount:expire_amount
                  22
              ])
       in
       status_is Transfer_created first
       && status_is Transfer_created second
       && status_is Transfer_created third
       && status_is Transfer_created post
       && status_is Transfer_created void
       && expired = 1
       && status_is Transfer_pending_transfer_expired post_expired
       && U128.equal (account_of state 1).debits_pending U128.zero
       && U128.equal (account_of state 2).credits_pending U128.zero
       && U128.equal (account_of state 1).debits_posted (u128 post_amount)
       && U128.equal (account_of state 2).credits_posted (u128 post_amount)
       && balances_are_conserved state [ 1; 2 ])
;;

let query_input =
  QCheck.pair
    (QCheck.pair (QCheck.int_range 1 8) (QCheck.int_range 1 2))
    (QCheck.pair (QCheck.int_range 0 8) QCheck.bool)
;;

let take limit values =
  let rec loop remaining output = function
    | _ when remaining = 0 -> List.rev output
    | [] -> List.rev output
    | value :: rest -> loop (remaining - 1) (value :: output) rest
  in
  loop limit [] values
;;

let query_filter ~selected ~limit ~reversed =
  { user_data_128 = U128.zero
  ; user_data_64 = Int64.of_int selected
  ; user_data_32 = 0l
  ; ledger = 0l
  ; code = 0
  ; timestamp_min = 0L
  ; timestamp_max = 0L
  ; limit
  ; reversed
  }
;;

let lookup_query_ordering_and_limits =
  QCheck.Test.make
    ~name:"lookups preserve request order and queries order then limit"
    ~count:100
    query_input
    (fun ((count, selected), (limit, reversed)) ->
       let account_state = empty () in
       let account_requests =
         List.init count (fun index ->
           account ~user_data_64:(Int64.of_int ((index mod 2) + 1)) (index + 1))
       in
       ignore (create_accounts account_state ~timestamp:1L account_requests);
       let expected_ids =
         List.filter_map
           (fun index -> if (index mod 2) + 1 = selected then Some (index + 1) else None)
           (List.init count Fun.id)
         |> fun ids -> take limit (if reversed then List.rev ids else ids)
       in
       let account_results =
         query_accounts account_state (query_filter ~selected ~limit ~reversed)
       in
       let lookup_results =
         lookup_accounts
           account_state
           [ u128 (count + 1); u128 2; u128 1; u128 (count + 2) ]
       in
       let transfer_state = empty () in
       ignore (create_accounts transfer_state ~timestamp:1L [ account 1; account 2 ]);
       let transfer_requests =
         List.init count (fun index ->
           transfer
             ~user_data_64:(Int64.of_int ((index mod 2) + 1))
             ~amount:index
             (index + 10))
       in
       ignore (create_transfers transfer_state ~timestamp:3L transfer_requests);
       let transfer_results =
         query_transfers transfer_state (query_filter ~selected ~limit ~reversed)
       in
       let transfer_lookup_results =
         lookup_transfers
           transfer_state
           [ u128 (count + 10); u128 11; u128 10; u128 (count + 11) ]
       in
       List.map (fun (account : account) -> U128.to_string account.id) account_results
       = List.map (fun id -> U128.to_string (u128 id)) expected_ids
       && List.map (fun (account : account) -> U128.to_string account.id) lookup_results
          = (List.filter (fun id -> id <= count) [ 2; 1 ]
             |> List.map (fun id -> U128.to_string (u128 id)))
       && List.map
            (fun (transfer : transfer) -> U128.to_string transfer.id)
            transfer_results
          = List.map (fun id -> U128.to_string (u128 (id + 9))) expected_ids
       && List.map
            (fun (transfer : transfer) -> U128.to_string transfer.id)
            transfer_lookup_results
          = (List.filter (fun id -> id <= count + 9) [ 11; 10 ]
             |> List.map (fun id -> U128.to_string (u128 id))))
;;

let u128_boundaries =
  QCheck.Test.make
    ~name:"U128 arithmetic preserves round trips at the maximum boundary"
    ~count:100
    (QCheck.int_range 0 1_000_000)
    (fun offset ->
       match
         ( U128.sub U128.max_value (u128 offset)
         , U128.add U128.max_value (u128 1)
         , U128.sub U128.zero (u128 1) )
       with
       | Ok near_max, Error `Overflow, Error `Underflow ->
         (match
            ( U128.add near_max (u128 offset)
            , U128.add (U128.of_int64_pair ~hi:0L ~lo:(-1L)) (u128 1) )
          with
          | Ok value, Ok carry ->
            U128.equal value U128.max_value && U128.to_int64_pair carry = (1L, 0L)
          | Error `Overflow, _ | _, Error `Overflow -> false)
       | _ -> false)
;;

let tests =
  [ deterministic_execution
  ; balance_conservation
  ; validation_and_idempotency
  ; linked_batch_atomicity
  ; pending_post_void_and_expiry
  ; lookup_query_ordering_and_limits
  ; u128_boundaries
  ]
;;

let () =
  let result =
    QCheck_runner.run_tests ~verbose:true ~rand:(Random.State.make [| 6; 6; 6; 6 |]) tests
  in
  if result <> 0 then exit result
;;
