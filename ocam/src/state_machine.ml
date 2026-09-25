module U128 = U128
include Types
module Result_code = Result_code

type t = Ledger.t

let empty = Ledger.empty
let commit_timestamp = Ledger.commit_timestamp
let is_zero = U128.is_zero
let is_max = U128.equal U128.max_value
let account_flags_equal (a : account_flags) (b : account_flags) = a = b
let transfer_flags_equal (a : transfer_flags) (b : transfer_flags) = a = b

let validate_event_timestamp ~commit_timestamp ~timestamp_event ~imported ~timestamp =
  if imported
  then
    if Int64.compare timestamp 0L <= 0 || Int64.compare timestamp timestamp_event > 0
    then Error `Out_of_range
    else if Int64.compare timestamp commit_timestamp <= 0
    then Error `Regressed
    else Ok timestamp
  else if not (Int64.equal timestamp 0L)
  then Error `Must_be_zero
  else Ok timestamp_event
;;

let create_account_one state ~timestamp_event (request : account) =
  let error status = { timestamp = 0L; status } in
  if is_zero request.id
  then error Account_id_must_not_be_zero
  else if is_max request.id
  then error Account_id_must_not_be_int_max
  else (
    match Ledger.find_account state request.id with
    | Some existing ->
      let status =
        if not (account_flags_equal request.flags existing.flags)
        then Account_exists_with_different_flags
        else if not (U128.equal request.user_data_128 existing.user_data_128)
        then Account_exists_with_different_user_data_128
        else if not (Int64.equal request.user_data_64 existing.user_data_64)
        then Account_exists_with_different_user_data_64
        else if not (Int32.equal request.user_data_32 existing.user_data_32)
        then Account_exists_with_different_user_data_32
        else if not (Int32.equal request.ledger existing.ledger)
        then Account_exists_with_different_ledger
        else if request.code <> existing.code
        then Account_exists_with_different_code
        else Account_exists
      in
      { timestamp = (if status = Account_exists then existing.timestamp else 0L); status }
    | None ->
      let status =
        if request.flags.debits_must_not_exceed_credits
           && request.flags.credits_must_not_exceed_debits
        then Some Account_flags_are_mutually_exclusive
        else if not (is_zero request.debits_pending)
        then Some Account_debits_pending_must_be_zero
        else if not (is_zero request.debits_posted)
        then Some Account_debits_posted_must_be_zero
        else if not (is_zero request.credits_pending)
        then Some Account_credits_pending_must_be_zero
        else if not (is_zero request.credits_posted)
        then Some Account_credits_posted_must_be_zero
        else if Int32.equal request.ledger 0l
        then Some Account_ledger_must_not_be_zero
        else if request.code = 0
        then Some Account_code_must_not_be_zero
        else None
      in
      (match status with
       | Some status -> error status
       | None ->
         (match
            validate_event_timestamp
              ~commit_timestamp:(Ledger.commit_timestamp state)
              ~timestamp_event
              ~imported:request.flags.imported
              ~timestamp:request.timestamp
          with
          | Error `Must_be_zero -> error Account_timestamp_must_be_zero
          | Error `Out_of_range -> error Account_imported_timestamp_out_of_range
          | Error `Regressed -> error Account_imported_timestamp_must_not_regress
          | Ok timestamp ->
            Ledger.add_account state { request with timestamp };
            { timestamp; status = Account_created })))
;;

let total_balance_overflows pending posted =
  match U128.add pending posted with
  | Ok _ -> false
  | Error `Overflow -> true
;;

let debits_exceed_credits (account : account) amount =
  if not account.flags.debits_must_not_exceed_credits
  then false
  else (
    match U128.add account.debits_pending account.debits_posted with
    | Error _ -> true
    | Ok total ->
      (match U128.add total amount with
       | Error _ -> true
       | Ok after -> U128.compare after account.credits_posted > 0))
;;

let credits_exceed_debits (account : account) amount =
  if not account.flags.credits_must_not_exceed_debits
  then false
  else (
    match U128.add account.credits_pending account.credits_posted with
    | Error _ -> true
    | Ok total ->
      (match U128.add total amount with
       | Error _ -> true
       | Ok after -> U128.compare after account.debits_posted > 0))
;;

let transfer_request_equal state (request : transfer) (existing : transfer) =
  let pending =
    if request.flags.post_pending_transfer || request.flags.void_pending_transfer
    then Ledger.find_transfer state existing.pending_id
    else None
  in
  let optional_u128 request_value existing_value pending_value =
    if is_zero request_value
    then U128.equal existing_value pending_value
    else U128.equal request_value existing_value
  in
  let optional_int64 request_value existing_value pending_value =
    if Int64.equal request_value 0L
    then Int64.equal existing_value pending_value
    else Int64.equal request_value existing_value
  in
  let optional_int32 request_value existing_value pending_value =
    if Int32.equal request_value 0l
    then Int32.equal existing_value pending_value
    else Int32.equal request_value existing_value
  in
  let amount_equal =
    match pending with
    | Some pending when request.flags.post_pending_transfer ->
      if is_max request.amount
      then U128.equal existing.amount pending.amount
      else U128.equal request.amount existing.amount
    | Some pending when request.flags.void_pending_transfer ->
      if is_zero request.amount
      then U128.equal existing.amount pending.amount
      else U128.equal request.amount existing.amount
    | _ when request.flags.balancing_debit || request.flags.balancing_credit ->
      U128.compare request.amount existing.amount >= 0
    | _ -> U128.equal request.amount existing.amount
  in
  transfer_flags_equal request.flags existing.flags
  && (match pending with
      | Some pending ->
        (is_zero request.debit_account_id
         || U128.equal request.debit_account_id existing.debit_account_id)
        && (is_zero request.credit_account_id
            || U128.equal request.credit_account_id existing.credit_account_id)
        && optional_u128
             request.user_data_128
             existing.user_data_128
             pending.user_data_128
        && optional_int64 request.user_data_64 existing.user_data_64 pending.user_data_64
        && optional_int32 request.user_data_32 existing.user_data_32 pending.user_data_32
        && (Int32.equal request.ledger 0l || Int32.equal request.ledger existing.ledger)
        && (request.code = 0 || request.code = existing.code)
      | None ->
        U128.equal request.debit_account_id existing.debit_account_id
        && U128.equal request.credit_account_id existing.credit_account_id
        && U128.equal request.user_data_128 existing.user_data_128
        && Int64.equal request.user_data_64 existing.user_data_64
        && Int32.equal request.user_data_32 existing.user_data_32
        && Int32.equal request.ledger existing.ledger
        && request.code = existing.code)
  && U128.equal request.pending_id existing.pending_id
  && Int32.equal request.timeout existing.timeout
  && amount_equal
;;

let timeout_ns timeout =
  Int64.mul (Int64.logand (Int64.of_int32 timeout) 0xffff_ffffL) 1_000_000_000L
;;

let timeout_nonzero timeout = not (Int32.equal timeout 0l)

let expires_at (transfer : transfer) =
  Int64.add transfer.timestamp (timeout_ns transfer.timeout)
;;

let timeout_overflows ~timestamp ~timeout =
  let duration = timeout_ns timeout in
  Int64.compare timestamp (Int64.sub Int64.max_int duration) > 0
;;

let record_account_history state (transfer : transfer) debit credit =
  let record (account : account) =
    if account.flags.history
    then Ledger.add_history state { account with timestamp = transfer.timestamp } transfer
  in
  record debit;
  record credit
;;

let effective_balancing_amount (request : transfer) (debit : account) (credit : account) =
  let debit_room =
    match U128.add debit.debits_posted debit.debits_pending with
    | Error _ -> U128.zero
    | Ok balance ->
      (match U128.sub debit.credits_posted balance with
       | Ok room -> room
       | Error _ -> U128.zero)
  in
  let credit_room =
    match U128.add credit.credits_posted credit.credits_pending with
    | Error _ -> U128.zero
    | Ok balance ->
      (match U128.sub credit.debits_posted balance with
       | Ok room -> room
       | Error _ -> U128.zero)
  in
  let amount =
    if request.flags.balancing_debit
    then U128.min request.amount debit_room
    else request.amount
  in
  if request.flags.balancing_credit then U128.min amount credit_room else amount
;;

let find_account_exn state id =
  match Ledger.find_account state id with
  | Some account -> account
  | None -> failwith "account referenced by stored transfer is missing"
;;

let post_or_void state ~timestamp_event (request : transfer) =
  let error status = { timestamp = 0L; status } in
  let flags = request.flags in
  if (flags.post_pending_transfer && flags.void_pending_transfer)
     || flags.pending
     || flags.balancing_debit
     || flags.balancing_credit
     || flags.closing_debit
     || flags.closing_credit
  then error Transfer_flags_are_mutually_exclusive
  else if is_zero request.pending_id
  then error Transfer_pending_id_must_not_be_zero
  else if is_max request.pending_id
  then error Transfer_pending_id_must_not_be_int_max
  else if U128.equal request.pending_id request.id
  then error Transfer_pending_id_must_be_different
  else if not (Int32.equal request.timeout 0l)
  then error Transfer_timeout_reserved_for_pending_transfer
  else (
    match Ledger.find_transfer state request.pending_id with
    | None -> error Transfer_pending_transfer_not_found
    | Some pending_transfer ->
      if not pending_transfer.flags.pending
      then error Transfer_pending_transfer_not_pending
      else (
        match Ledger.find_pending state pending_transfer.id with
        | Some Posted -> error Transfer_pending_transfer_already_posted
        | Some Voided -> error Transfer_pending_transfer_already_voided
        | Some Expired -> error Transfer_pending_transfer_expired
        | None -> error Transfer_pending_transfer_not_pending
        | Some Pending ->
          if ((not (is_zero request.debit_account_id))
              && not
                   (U128.equal request.debit_account_id pending_transfer.debit_account_id)
             )
             || ((not (is_zero request.credit_account_id))
                 && not
                      (U128.equal
                         request.credit_account_id
                         pending_transfer.credit_account_id))
          then error Transfer_pending_transfer_has_different_accounts
          else if (not (Int32.equal request.ledger 0l))
                  && not (Int32.equal request.ledger pending_transfer.ledger)
          then error Transfer_pending_transfer_has_different_ledger
          else if request.code <> 0 && request.code <> pending_transfer.code
          then error Transfer_pending_transfer_has_different_code
          else (
            let amount =
              if flags.void_pending_transfer && is_zero request.amount
              then pending_transfer.amount
              else if flags.post_pending_transfer && is_max request.amount
              then pending_transfer.amount
              else request.amount
            in
            if U128.compare amount pending_transfer.amount > 0
            then error Transfer_exceeds_pending_transfer_amount
            else if flags.void_pending_transfer
                    && not (U128.equal amount pending_transfer.amount)
            then error Transfer_pending_transfer_has_different_amount
            else if timeout_nonzero pending_transfer.timeout
                    && Int64.compare timestamp_event (expires_at pending_transfer) >= 0
            then error Transfer_pending_transfer_expired
            else (
              match
                validate_event_timestamp
                  ~commit_timestamp:(Ledger.commit_timestamp state)
                  ~timestamp_event
                  ~imported:flags.imported
                  ~timestamp:request.timestamp
              with
              | Error `Must_be_zero -> error Transfer_timestamp_must_be_zero
              | Error `Out_of_range -> error Transfer_imported_timestamp_out_of_range
              | Error `Regressed -> error Transfer_imported_timestamp_must_not_regress
              | Ok timestamp ->
                let debit = find_account_exn state pending_transfer.debit_account_id in
                let credit = find_account_exn state pending_transfer.credit_account_id in
                if (debit.flags.closed || credit.flags.closed)
                   && not flags.void_pending_transfer
                then error Transfer_account_already_closed
                else (
                  match
                    ( U128.sub debit.debits_pending pending_transfer.amount
                    , U128.sub credit.credits_pending pending_transfer.amount )
                  with
                  | Error _, _ | _, Error _ -> error Transfer_overflows_balance
                  | Ok debits_pending, Ok credits_pending ->
                    let debit_result, credit_result =
                      if flags.post_pending_transfer
                      then
                        ( U128.add debit.debits_posted amount
                        , U128.add credit.credits_posted amount )
                      else Ok debit.debits_posted, Ok credit.credits_posted
                    in
                    (match debit_result, credit_result with
                     | Error _, _ | _, Error _ -> error Transfer_overflows_balance
                     | Ok debits_posted, Ok credits_posted ->
                       let debit_flags =
                         if flags.void_pending_transfer
                            && pending_transfer.flags.closing_debit
                         then { debit.flags with closed = false }
                         else debit.flags
                       in
                       let credit_flags =
                         if flags.void_pending_transfer
                            && pending_transfer.flags.closing_credit
                         then { credit.flags with closed = false }
                         else credit.flags
                       in
                       let debit =
                         { debit with debits_pending; debits_posted; flags = debit_flags }
                       in
                       let credit =
                         { credit with
                           credits_pending
                         ; credits_posted
                         ; flags = credit_flags
                         }
                       in
                       Ledger.update_account state debit;
                       Ledger.update_account state credit;
                       Ledger.set_pending
                         state
                         pending_transfer.id
                         (if flags.post_pending_transfer then Posted else Voided);
                       if timeout_nonzero pending_transfer.timeout
                       then
                         Ledger.remove_expiry
                           state
                           ~expires_at:(expires_at pending_transfer)
                           pending_transfer.id;
                       let transfer =
                         { request with
                           debit_account_id = pending_transfer.debit_account_id
                         ; credit_account_id = pending_transfer.credit_account_id
                         ; amount
                         ; user_data_128 =
                             (if is_zero request.user_data_128
                              then pending_transfer.user_data_128
                              else request.user_data_128)
                         ; user_data_64 =
                             (if Int64.equal request.user_data_64 0L
                              then pending_transfer.user_data_64
                              else request.user_data_64)
                         ; user_data_32 =
                             (if Int32.equal request.user_data_32 0l
                              then pending_transfer.user_data_32
                              else request.user_data_32)
                         ; ledger = pending_transfer.ledger
                         ; code = pending_transfer.code
                         ; timestamp
                         }
                       in
                       Ledger.add_transfer state transfer;
                       record_account_history state transfer debit credit;
                       { timestamp; status = Transfer_created }))))))
;;

let create_transfer_one_untracked state ~timestamp_event (request : transfer) =
  let error status = { timestamp = 0L; status } in
  if is_zero request.id
  then error Transfer_id_must_not_be_zero
  else if is_max request.id
  then error Transfer_id_must_not_be_int_max
  else (
    match Ledger.find_transfer state request.id with
    | Some existing ->
      if transfer_request_equal state request existing
      then { timestamp = existing.timestamp; status = Transfer_exists }
      else error Transfer_exists_with_different_request
    | None ->
      if request.flags.post_pending_transfer || request.flags.void_pending_transfer
      then post_or_void state ~timestamp_event request
      else if is_zero request.debit_account_id
      then error Transfer_debit_account_id_must_not_be_zero
      else if is_max request.debit_account_id
      then error Transfer_debit_account_id_must_not_be_int_max
      else if is_zero request.credit_account_id
      then error Transfer_credit_account_id_must_not_be_zero
      else if is_max request.credit_account_id
      then error Transfer_credit_account_id_must_not_be_int_max
      else if U128.equal request.debit_account_id request.credit_account_id
      then error Transfer_accounts_must_be_different
      else if not (is_zero request.pending_id)
      then error Transfer_pending_id_must_be_zero
      else if (not request.flags.pending) && not (Int32.equal request.timeout 0l)
      then error Transfer_timeout_reserved_for_pending_transfer
      else if (request.flags.closing_debit || request.flags.closing_credit)
              && not request.flags.pending
      then error Transfer_closing_transfer_must_be_pending
      else if Int32.equal request.ledger 0l
      then error Transfer_ledger_must_not_be_zero
      else if request.code = 0
      then error Transfer_code_must_not_be_zero
      else (
        match Ledger.find_account state request.debit_account_id with
        | None -> error Transfer_debit_account_not_found
        | Some debit ->
          (match Ledger.find_account state request.credit_account_id with
           | None -> error Transfer_credit_account_not_found
           | Some credit ->
             if not (Int32.equal debit.ledger credit.ledger)
             then error Transfer_accounts_must_have_same_ledger
             else if not (Int32.equal request.ledger debit.ledger)
             then error Transfer_must_have_same_ledger_as_accounts
             else if request.flags.imported
                     && Int64.compare request.timestamp (Ledger.commit_timestamp state)
                        <= 0
             then error Transfer_imported_timestamp_must_not_regress
             else if request.flags.imported && not (Int32.equal request.timeout 0l)
             then error Transfer_imported_timeout_must_be_zero
             else if debit.flags.closed || credit.flags.closed
             then error Transfer_account_already_closed
             else (
               let amount = effective_balancing_amount request debit credit in
               match
                 validate_event_timestamp
                   ~commit_timestamp:(Ledger.commit_timestamp state)
                   ~timestamp_event
                   ~imported:request.flags.imported
                   ~timestamp:request.timestamp
               with
               | Error `Must_be_zero -> error Transfer_timestamp_must_be_zero
               | Error `Out_of_range -> error Transfer_imported_timestamp_out_of_range
               | Error `Regressed -> error Transfer_imported_timestamp_must_not_regress
               | Ok timestamp ->
                 let debit_balance =
                   if request.flags.pending
                   then U128.add debit.debits_pending amount
                   else U128.add debit.debits_posted amount
                 in
                 let credit_balance =
                   if request.flags.pending
                   then U128.add credit.credits_pending amount
                   else U128.add credit.credits_posted amount
                 in
                 (match debit_balance, credit_balance with
                  | Error _, _ | _, Error _ -> error Transfer_overflows_balance
                  | Ok debit_balance, Ok credit_balance ->
                    let debits_pending, debits_posted =
                      if request.flags.pending
                      then debit_balance, debit.debits_posted
                      else debit.debits_pending, debit_balance
                    in
                    let credits_pending, credits_posted =
                      if request.flags.pending
                      then credit_balance, credit.credits_posted
                      else credit.credits_pending, credit_balance
                    in
                    if total_balance_overflows debits_pending debits_posted
                       || total_balance_overflows credits_pending credits_posted
                    then error Transfer_overflows_balance
                    else if request.flags.pending
                            && timeout_overflows ~timestamp ~timeout:request.timeout
                    then error Transfer_overflows_timeout
                    else if debits_exceed_credits debit amount
                    then error Transfer_exceeds_credits
                    else if credits_exceed_debits credit amount
                    then error Transfer_exceeds_debits
                    else (
                      let debit_flags =
                        if request.flags.closing_debit
                        then { debit.flags with closed = true }
                        else debit.flags
                      in
                      let credit_flags =
                        if request.flags.closing_credit
                        then { credit.flags with closed = true }
                        else credit.flags
                      in
                      let debit =
                        { debit with debits_pending; debits_posted; flags = debit_flags }
                      in
                      let credit =
                        { credit with
                          credits_pending
                        ; credits_posted
                        ; flags = credit_flags
                        }
                      in
                      Ledger.update_account state debit;
                      Ledger.update_account state credit;
                      let transfer = { request with amount; timestamp } in
                      Ledger.add_transfer state transfer;
                      if request.flags.pending
                      then (
                        Ledger.set_pending state transfer.id Pending;
                        if timeout_nonzero transfer.timeout
                        then
                          Ledger.add_expiry
                            state
                            ~expires_at:(expires_at transfer)
                            transfer.id);
                      record_account_history state transfer debit credit;
                      { timestamp; status = Transfer_created }))))))
;;

let create_transfer_one state ~timestamp_event (request : transfer) =
  if Ledger.transfer_failed state request.id
  then { timestamp = 0L; status = Transfer_id_already_failed }
  else (
    let result = create_transfer_one_untracked state ~timestamp_event request in
    if Result_code.transfer_status_transient result.status
    then Ledger.mark_failed state request.id;
    result)
;;

(* Batch execution shared by accounts and transfers. *)

let chains events linked =
  let rec loop current output = function
    | [] -> List.rev (if current = [] then output else List.rev current :: output)
    | event :: rest ->
      let current = event :: current in
      if linked event
      then loop current output rest
      else loop [] (List.rev current :: output) rest
  in
  loop [] [] events
;;

type ('request, 'status) batch_spec =
  { linked : 'request -> bool
  ; imported : 'request -> bool
  ; request_timestamp : 'request -> int64
  ; success : 'status
  ; linked_event_failed : 'status
  ; linked_event_chain_open : 'status
  ; imported_event_expected : 'status
  ; imported_event_not_expected : 'status
  ; imported_timestamp_out_of_range : 'status
  ; imported_timestamp_must_not_advance : 'status
  ; timestamp_must_be_zero : 'status
  ; execute : t -> timestamp_event:int64 -> 'request -> 'status create_result
  ; on_chain_failure : t -> 'request -> 'status -> unit
  }

let execute_batch spec state ~timestamp requests =
  let timestamp_cursor = ref timestamp in
  let batch_timestamp_high =
    Int64.add timestamp (Int64.of_int (Int.max 0 (List.length requests - 1)))
  in
  let batch_imported =
    match requests with
    | [] -> false
    | first :: _ -> spec.imported first
  in
  let error status = { timestamp = 0L; status } in
  let execute_one request =
    let imported = spec.imported request in
    let request_timestamp = spec.request_timestamp request in
    let result =
      if imported <> batch_imported
      then
        error
          (if imported
           then spec.imported_event_not_expected
           else spec.imported_event_expected)
      else if imported && Int64.compare request_timestamp 0L <= 0
      then error spec.imported_timestamp_out_of_range
      else if imported && Int64.compare request_timestamp batch_timestamp_high >= 0
      then error spec.imported_timestamp_must_not_advance
      else if (not imported) && not (Int64.equal request_timestamp 0L)
      then error spec.timestamp_must_be_zero
      else spec.execute state ~timestamp_event:!timestamp_cursor request
    in
    result
  in
  let advance () = timestamp_cursor := Int64.succ !timestamp_cursor in
  let execute_chain chain =
    match chain with
    | [ request ] when not (spec.linked request) ->
      let result = execute_one request in
      advance ();
      [ result ]
    | _ ->
      let open_chain =
        match List.rev chain with
        | last :: _ -> spec.linked last
        | [] -> false
      in
      let last_index = List.length chain - 1 in
      let run () =
        let rec loop index failure results = function
          | [] -> List.rev results, failure
          | request :: rest ->
            let result, failure =
              if open_chain && index = last_index
              then error spec.linked_event_chain_open, failure
              else (
                match failure with
                | Some _ -> error spec.linked_event_failed, failure
                | None ->
                  let result = execute_one request in
                  let failure =
                    if result.status = spec.success
                    then None
                    else Some (index, request, result)
                  in
                  result, failure)
            in
            advance ();
            loop (index + 1) failure (result :: results) rest
        in
        loop 0 None [] chain
      in
      let (results, failure), rollback = Ledger.transact state run in
      (match failure, open_chain with
       | None, false -> results
       | _ ->
         rollback ();
         Option.iter
           (fun (_, request, result) -> spec.on_chain_failure state request result.status)
           failure;
         let failure_index = Option.map (fun (index, _, _) -> index) failure in
         List.mapi
           (fun index result ->
             if open_chain && index = last_index
             then error spec.linked_event_chain_open
             else if Some index = failure_index
             then result
             else error spec.linked_event_failed)
           results)
  in
  List.concat_map execute_chain (chains requests spec.linked)
;;

let account_batch : (account, create_account_status) batch_spec =
  { linked = (fun (request : account) -> request.flags.linked)
  ; imported = (fun (request : account) -> request.flags.imported)
  ; request_timestamp = (fun (request : account) -> request.timestamp)
  ; success = Account_created
  ; linked_event_failed = Account_linked_event_failed
  ; linked_event_chain_open = Account_linked_event_chain_open
  ; imported_event_expected = Account_imported_event_expected
  ; imported_event_not_expected = Account_imported_event_not_expected
  ; imported_timestamp_out_of_range = Account_imported_timestamp_out_of_range
  ; imported_timestamp_must_not_advance = Account_imported_timestamp_must_not_advance
  ; timestamp_must_be_zero = Account_timestamp_must_be_zero
  ; execute = create_account_one
  ; on_chain_failure = (fun _ _ _ -> ())
  }
;;

let transfer_batch : (transfer, create_transfer_status) batch_spec =
  { linked = (fun (request : transfer) -> request.flags.linked)
  ; imported = (fun (request : transfer) -> request.flags.imported)
  ; request_timestamp = (fun (request : transfer) -> request.timestamp)
  ; success = Transfer_created
  ; linked_event_failed = Transfer_linked_event_failed
  ; linked_event_chain_open = Transfer_linked_event_chain_open
  ; imported_event_expected = Transfer_imported_event_expected
  ; imported_event_not_expected = Transfer_imported_event_not_expected
  ; imported_timestamp_out_of_range = Transfer_imported_timestamp_out_of_range
  ; imported_timestamp_must_not_advance = Transfer_imported_timestamp_must_not_advance
  ; timestamp_must_be_zero = Transfer_timestamp_must_be_zero
  ; execute = create_transfer_one
  ; on_chain_failure =
      (fun state (request : transfer) status ->
        if Result_code.transfer_status_transient status
        then Ledger.mark_failed state request.id)
  }
;;

let create_accounts state ~timestamp requests =
  execute_batch account_batch state ~timestamp requests
;;

let create_transfers state ~timestamp requests =
  execute_batch transfer_batch state ~timestamp requests
;;

(* Reads *)

let lookup_accounts state ids = List.filter_map (Ledger.find_account state) ids
let lookup_transfers state ids = List.filter_map (Ledger.find_transfer state) ids

let take_matching ~limit predicate sequence =
  if limit <= 0
  then []
  else sequence |> Seq.filter predicate |> Seq.take limit |> List.of_seq
;;

let metadata_matches
  ~user_data_128
  ~user_data_64
  ~user_data_32
  ~code
  ~(value_user_data_128 : U128.t)
  ~value_user_data_64
  ~value_user_data_32
  ~value_code
  =
  (is_zero user_data_128 || U128.equal value_user_data_128 user_data_128)
  && (Int64.equal user_data_64 0L || Int64.equal value_user_data_64 user_data_64)
  && (Int32.equal user_data_32 0l || Int32.equal value_user_data_32 user_data_32)
  && (code = 0 || value_code = code)
;;

let query_matches
  (filter : query_filter)
  ~user_data_128
  ~user_data_64
  ~user_data_32
  ~ledger
  ~code
  =
  metadata_matches
    ~user_data_128:filter.user_data_128
    ~user_data_64:filter.user_data_64
    ~user_data_32:filter.user_data_32
    ~code:filter.code
    ~value_user_data_128:user_data_128
    ~value_user_data_64:user_data_64
    ~value_user_data_32:user_data_32
    ~value_code:code
  && (Int32.equal filter.ledger 0l || Int32.equal ledger filter.ledger)
;;

let account_filter_matches (filter : account_filter) (transfer : transfer) =
  ((filter.debits && U128.equal transfer.debit_account_id filter.account_id)
   || (filter.credits && U128.equal transfer.credit_account_id filter.account_id))
  && metadata_matches
       ~user_data_128:filter.user_data_128
       ~user_data_64:filter.user_data_64
       ~user_data_32:filter.user_data_32
       ~code:filter.code
       ~value_user_data_128:transfer.user_data_128
       ~value_user_data_64:transfer.user_data_64
       ~value_user_data_32:transfer.user_data_32
       ~value_code:transfer.code
;;

let query_accounts state (filter : query_filter) =
  Ledger.to_seq_in_range
    state.Ledger.accounts_by_timestamp
    ~minimum:filter.timestamp_min
    ~maximum:filter.timestamp_max
    ~reversed:filter.reversed
  |> Seq.filter_map (fun (_, id) -> Ledger.find_account state id)
  |> take_matching ~limit:filter.limit (fun (account : account) ->
    query_matches
      filter
      ~user_data_128:account.user_data_128
      ~user_data_64:account.user_data_64
      ~user_data_32:account.user_data_32
      ~ledger:account.ledger
      ~code:account.code)
;;

let query_transfers state (filter : query_filter) =
  Ledger.to_seq_in_range
    state.Ledger.transfers_by_timestamp
    ~minimum:filter.timestamp_min
    ~maximum:filter.timestamp_max
    ~reversed:filter.reversed
  |> Seq.map snd
  |> take_matching ~limit:filter.limit (fun (transfer : transfer) ->
    query_matches
      filter
      ~user_data_128:transfer.user_data_128
      ~user_data_64:transfer.user_data_64
      ~user_data_32:transfer.user_data_32
      ~ledger:transfer.ledger
      ~code:transfer.code)
;;

let get_account_transfers state (filter : account_filter) =
  Ledger.to_seq_in_range
    (Ledger.account_transfers state filter.account_id)
    ~minimum:filter.timestamp_min
    ~maximum:filter.timestamp_max
    ~reversed:filter.reversed
  |> Seq.map snd
  |> take_matching ~limit:filter.limit (account_filter_matches filter)
;;

let get_account_balances state (filter : account_filter) =
  match Ledger.find_account state filter.account_id with
  | None -> []
  | Some account ->
    if (not account.flags.history)
       || ((not filter.debits) && not filter.credits)
       || filter.limit <= 0
       || ((not (Int64.equal filter.timestamp_min 0L))
           && (not (Int64.equal filter.timestamp_max 0L))
           && Int64.compare filter.timestamp_min filter.timestamp_max > 0)
    then []
    else
      Ledger.to_seq_in_range
        (Ledger.account_history state filter.account_id)
        ~minimum:filter.timestamp_min
        ~maximum:filter.timestamp_max
        ~reversed:filter.reversed
      |> Seq.map snd
      |> take_matching ~limit:filter.limit (fun (entry : Ledger.history_entry) ->
        account_filter_matches filter entry.transfer)
      |> List.map (fun (entry : Ledger.history_entry) -> entry.snapshot)
;;

let expire_pending_transfers state ~timestamp =
  let expired = ref 0 in
  List.iter
    (fun (expires_at, id) ->
      match Ledger.find_pending state id, Ledger.find_transfer state id with
      | Some Pending, Some transfer ->
        let debit = find_account_exn state transfer.debit_account_id in
        let credit = find_account_exn state transfer.credit_account_id in
        (match
           ( U128.sub debit.debits_pending transfer.amount
           , U128.sub credit.credits_pending transfer.amount )
         with
         | Ok debits_pending, Ok credits_pending ->
           Ledger.update_account
             state
             { debit with
               debits_pending
             ; flags =
                 (if transfer.flags.closing_debit
                  then { debit.flags with closed = false }
                  else debit.flags)
             };
           Ledger.update_account
             state
             { credit with
               credits_pending
             ; flags =
                 (if transfer.flags.closing_credit
                  then { credit.flags with closed = false }
                  else credit.flags)
             };
           Ledger.set_pending state id Expired;
           Ledger.remove_expiry state ~expires_at id;
           incr expired
         | _ -> failwith "pending-balance invariant violated")
      | _ -> Ledger.remove_expiry state ~expires_at id)
    (Ledger.expired_before state timestamp);
  if !expired > 0 then Ledger.set_commit_timestamp state timestamp;
  !expired
;;
