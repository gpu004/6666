module U128 = struct
  type t =
    { hi : int64
    ; lo : int64
    }

  let zero = { hi = 0L; lo = 0L }
  let max_value = { hi = -1L; lo = -1L }

  let of_int value =
    if value < 0 then invalid_arg "U128.of_int: negative value";
    { hi = 0L; lo = Int64.of_int value }
  ;;

  let of_int64_pair ~hi ~lo = { hi; lo }
  let to_int64_pair value = value.hi, value.lo

  let compare a b =
    let high = Int64.unsigned_compare a.hi b.hi in
    if high <> 0 then high else Int64.unsigned_compare a.lo b.lo
  ;;

  let equal a b = compare a b = 0

  let add a b =
    let lo = Int64.add a.lo b.lo in
    let carry = if Int64.unsigned_compare lo a.lo < 0 then 1L else 0L in
    let hi_without_carry = Int64.add a.hi b.hi in
    let hi = Int64.add hi_without_carry carry in
    let overflow =
      Int64.unsigned_compare hi_without_carry a.hi < 0
      || (Int64.equal carry 1L && Int64.unsigned_compare hi hi_without_carry < 0)
    in
    if overflow then Error `Overflow else Ok { hi; lo }
  ;;

  let sub a b =
    if compare a b < 0
    then Error `Underflow
    else (
      let borrow = if Int64.unsigned_compare a.lo b.lo < 0 then 1L else 0L in
      Ok { hi = Int64.sub (Int64.sub a.hi b.hi) borrow; lo = Int64.sub a.lo b.lo })
  ;;

  let min a b = if compare a b <= 0 then a else b

  let to_string value =
    if Int64.equal value.hi 0L
    then Printf.sprintf "%Lu" value.lo
    else Printf.sprintf "0x%Lx%016Lx" value.hi value.lo
  ;;
end

type account_flags =
  { linked : bool
  ; debits_must_not_exceed_credits : bool
  ; credits_must_not_exceed_debits : bool
  ; history : bool
  ; imported : bool
  ; closed : bool
  }

type transfer_flags =
  { linked : bool
  ; pending : bool
  ; post_pending_transfer : bool
  ; void_pending_transfer : bool
  ; balancing_debit : bool
  ; balancing_credit : bool
  ; closing_debit : bool
  ; closing_credit : bool
  ; imported : bool
  }

type account =
  { id : U128.t
  ; debits_pending : U128.t
  ; debits_posted : U128.t
  ; credits_pending : U128.t
  ; credits_posted : U128.t
  ; user_data_128 : U128.t
  ; user_data_64 : int64
  ; user_data_32 : int32
  ; ledger : int32
  ; code : int
  ; flags : account_flags
  ; timestamp : int64
  }

type transfer =
  { id : U128.t
  ; debit_account_id : U128.t
  ; credit_account_id : U128.t
  ; amount : U128.t
  ; pending_id : U128.t
  ; user_data_128 : U128.t
  ; user_data_64 : int64
  ; user_data_32 : int32
  ; timeout : int32
  ; ledger : int32
  ; code : int
  ; flags : transfer_flags
  ; timestamp : int64
  }

type pending_status =
  | Pending
  | Posted
  | Voided
  | Expired

type create_account_status =
  | Account_created
  | Account_exists
  | Account_linked_event_failed
  | Account_linked_event_chain_open
  | Account_timestamp_must_be_zero
  | Account_id_must_not_be_zero
  | Account_id_must_not_be_int_max
  | Account_exists_with_different_flags
  | Account_exists_with_different_user_data_128
  | Account_exists_with_different_user_data_64
  | Account_exists_with_different_user_data_32
  | Account_exists_with_different_ledger
  | Account_exists_with_different_code
  | Account_flags_are_mutually_exclusive
  | Account_debits_pending_must_be_zero
  | Account_debits_posted_must_be_zero
  | Account_credits_pending_must_be_zero
  | Account_credits_posted_must_be_zero
  | Account_ledger_must_not_be_zero
  | Account_code_must_not_be_zero
  | Account_imported_timestamp_out_of_range
  | Account_imported_timestamp_must_not_regress

type create_transfer_status =
  | Transfer_created
  | Transfer_exists
  | Transfer_linked_event_failed
  | Transfer_linked_event_chain_open
  | Transfer_timestamp_must_be_zero
  | Transfer_id_must_not_be_zero
  | Transfer_id_must_not_be_int_max
  | Transfer_exists_with_different_request
  | Transfer_flags_are_mutually_exclusive
  | Transfer_debit_account_id_must_not_be_zero
  | Transfer_credit_account_id_must_not_be_zero
  | Transfer_accounts_must_be_different
  | Transfer_pending_id_must_be_zero
  | Transfer_pending_id_must_not_be_zero
  | Transfer_pending_id_must_be_different
  | Transfer_timeout_reserved_for_pending_transfer
  | Transfer_closing_transfer_must_be_pending
  | Transfer_ledger_must_not_be_zero
  | Transfer_code_must_not_be_zero
  | Transfer_debit_account_not_found
  | Transfer_credit_account_not_found
  | Transfer_accounts_must_have_same_ledger
  | Transfer_must_have_same_ledger_as_accounts
  | Transfer_pending_transfer_not_found
  | Transfer_pending_transfer_not_pending
  | Transfer_pending_transfer_has_different_accounts
  | Transfer_pending_transfer_has_different_ledger
  | Transfer_pending_transfer_has_different_code
  | Transfer_exceeds_pending_transfer_amount
  | Transfer_pending_transfer_has_different_amount
  | Transfer_pending_transfer_already_posted
  | Transfer_pending_transfer_already_voided
  | Transfer_pending_transfer_expired
  | Transfer_account_already_closed
  | Transfer_overflows_balance
  | Transfer_overflows_timeout
  | Transfer_exceeds_credits
  | Transfer_exceeds_debits
  | Transfer_imported_timestamp_out_of_range
  | Transfer_imported_timestamp_must_not_regress
  | Transfer_imported_timeout_must_be_zero

type 'status create_result =
  { timestamp : int64
  ; status : 'status
  }

type query_filter =
  { user_data_128 : U128.t
  ; user_data_64 : int64
  ; user_data_32 : int32
  ; ledger : int32
  ; code : int
  ; timestamp_min : int64
  ; timestamp_max : int64
  ; limit : int
  ; reversed : bool
  }

type account_filter =
  { account_id : U128.t
  ; user_data_128 : U128.t
  ; user_data_64 : int64
  ; user_data_32 : int32
  ; code : int
  ; timestamp_min : int64
  ; timestamp_max : int64
  ; limit : int
  ; debits : bool
  ; credits : bool
  ; reversed : bool
  }

module Id_table = Hashtbl.Make (struct
    type t = U128.t

    let equal = U128.equal
    let hash value = Hashtbl.hash (U128.to_int64_pair value)
  end)

type t =
  { mutable accounts : account Id_table.t
  ; mutable transfers : transfer Id_table.t
  ; mutable pending : pending_status Id_table.t
  ; mutable account_history : (account * transfer) list Id_table.t
  ; mutable commit_timestamp : int64
  }

let empty () =
  { accounts = Id_table.create 1024
  ; transfers = Id_table.create 1024
  ; pending = Id_table.create 256
  ; account_history = Id_table.create 1024
  ; commit_timestamp = 0L
  }
;;

let commit_timestamp state = state.commit_timestamp
let is_zero = U128.equal U128.zero
let is_max = U128.equal U128.max_value
let copy_table table = Id_table.copy table

let clone state =
  { accounts = copy_table state.accounts
  ; transfers = copy_table state.transfers
  ; pending = copy_table state.pending
  ; account_history = copy_table state.account_history
  ; commit_timestamp = state.commit_timestamp
  }
;;

let replace_state destination source =
  destination.accounts <- source.accounts;
  destination.transfers <- source.transfers;
  destination.pending <- source.pending;
  destination.account_history <- source.account_history;
  destination.commit_timestamp <- source.commit_timestamp
;;

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
    match Id_table.find_opt state.accounts request.id with
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
        if
          request.flags.debits_must_not_exceed_credits
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
              ~commit_timestamp:state.commit_timestamp
              ~timestamp_event
              ~imported:request.flags.imported
              ~timestamp:request.timestamp
          with
          | Error `Must_be_zero -> error Account_timestamp_must_be_zero
          | Error `Out_of_range -> error Account_imported_timestamp_out_of_range
          | Error `Regressed -> error Account_imported_timestamp_must_not_regress
          | Ok timestamp ->
            let account = { request with timestamp } in
            Id_table.add state.accounts account.id account;
            state.commit_timestamp <- timestamp;
            { timestamp; status = Account_created })))
;;

let sum_or_error a b = U128.add a b

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
    then Id_table.find_opt state.transfers existing.pending_id
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

let timeout_overflows ~timestamp ~timeout =
  let duration = timeout_ns timeout in
  Int64.compare timestamp (Int64.sub Int64.max_int duration) > 0
;;

let record_account_history state (transfer : transfer) debit credit =
  let record (account : account) =
    if account.flags.history
    then (
      let snapshot = { account with timestamp = transfer.timestamp } in
      let history =
        Option.value (Id_table.find_opt state.account_history account.id) ~default:[]
      in
      Id_table.replace state.account_history account.id ((snapshot, transfer) :: history))
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

let store_transfer state transfer =
  Id_table.add state.transfers transfer.id transfer;
  state.commit_timestamp <- transfer.timestamp
;;

let post_or_void state ~timestamp_event (request : transfer) =
  let error status = { timestamp = 0L; status } in
  let flags = request.flags in
  if
    (flags.post_pending_transfer && flags.void_pending_transfer)
    || flags.pending
    || flags.balancing_debit
    || flags.balancing_credit
    || flags.closing_debit
    || flags.closing_credit
  then error Transfer_flags_are_mutually_exclusive
  else if is_zero request.pending_id
  then error Transfer_pending_id_must_not_be_zero
  else if U128.equal request.pending_id request.id
  then error Transfer_pending_id_must_be_different
  else if not (Int32.equal request.timeout 0l)
  then error Transfer_timeout_reserved_for_pending_transfer
  else (
    match Id_table.find_opt state.transfers request.pending_id with
    | None -> error Transfer_pending_transfer_not_found
    | Some pending_transfer ->
      if not pending_transfer.flags.pending
      then error Transfer_pending_transfer_not_pending
      else (
        match Id_table.find_opt state.pending pending_transfer.id with
        | Some Posted -> error Transfer_pending_transfer_already_posted
        | Some Voided -> error Transfer_pending_transfer_already_voided
        | Some Expired -> error Transfer_pending_transfer_expired
        | None -> error Transfer_pending_transfer_not_pending
        | Some Pending ->
          if
            ((not (is_zero request.debit_account_id))
             && not
                  (U128.equal request.debit_account_id pending_transfer.debit_account_id)
            )
            || ((not (is_zero request.credit_account_id))
                && not
                     (U128.equal
                        request.credit_account_id
                        pending_transfer.credit_account_id))
          then error Transfer_pending_transfer_has_different_accounts
          else if
            (not (Int32.equal request.ledger 0l))
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
            else if
              flags.void_pending_transfer
              && not (U128.equal amount pending_transfer.amount)
            then error Transfer_pending_transfer_has_different_amount
            else (
              let expires_at =
                Int64.add pending_transfer.timestamp (timeout_ns pending_transfer.timeout)
              in
              if
                Int32.compare pending_transfer.timeout 0l > 0
                && Int64.compare timestamp_event expires_at >= 0
              then error Transfer_pending_transfer_expired
              else (
                match
                  validate_event_timestamp
                    ~commit_timestamp:state.commit_timestamp
                    ~timestamp_event
                    ~imported:flags.imported
                    ~timestamp:request.timestamp
                with
                | Error `Must_be_zero -> error Transfer_timestamp_must_be_zero
                | Error `Out_of_range -> error Transfer_imported_timestamp_out_of_range
                | Error `Regressed -> error Transfer_imported_timestamp_must_not_regress
                | Ok timestamp ->
                  let debit =
                    Id_table.find state.accounts pending_transfer.debit_account_id
                  in
                  let credit =
                    Id_table.find state.accounts pending_transfer.credit_account_id
                  in
                  if
                    (debit.flags.closed || credit.flags.closed)
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
                          ( sum_or_error debit.debits_posted amount
                          , sum_or_error credit.credits_posted amount )
                        else Ok debit.debits_posted, Ok credit.credits_posted
                      in
                      (match debit_result, credit_result with
                       | Error _, _ | _, Error _ -> error Transfer_overflows_balance
                       | Ok debits_posted, Ok credits_posted ->
                         let debit_flags =
                           if
                             flags.void_pending_transfer
                             && pending_transfer.flags.closing_debit
                           then { debit.flags with closed = false }
                           else debit.flags
                         in
                         let credit_flags =
                           if
                             flags.void_pending_transfer
                             && pending_transfer.flags.closing_credit
                           then { credit.flags with closed = false }
                           else credit.flags
                         in
                         Id_table.replace
                           state.accounts
                           debit.id
                           { debit with
                             debits_pending
                           ; debits_posted
                           ; flags = debit_flags
                           };
                         Id_table.replace
                           state.accounts
                           credit.id
                           { credit with
                             credits_pending
                           ; credits_posted
                           ; flags = credit_flags
                           };
                         Id_table.replace
                           state.pending
                           pending_transfer.id
                           (if flags.post_pending_transfer then Posted else Voided);
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
                         store_transfer state transfer;
                         record_account_history
                           state
                           transfer
                           (Id_table.find state.accounts debit.id)
                           (Id_table.find state.accounts credit.id);
                         { timestamp; status = Transfer_created })))))))
;;

let create_transfer_one state ~timestamp_event (request : transfer) =
  let error status = { timestamp = 0L; status } in
  if is_zero request.id
  then error Transfer_id_must_not_be_zero
  else if is_max request.id
  then error Transfer_id_must_not_be_int_max
  else (
    match Id_table.find_opt state.transfers request.id with
    | Some existing ->
      if transfer_request_equal state request existing
      then { timestamp = existing.timestamp; status = Transfer_exists }
      else error Transfer_exists_with_different_request
    | None ->
      if request.flags.post_pending_transfer || request.flags.void_pending_transfer
      then post_or_void state ~timestamp_event request
      else if is_zero request.debit_account_id
      then error Transfer_debit_account_id_must_not_be_zero
      else if is_zero request.credit_account_id
      then error Transfer_credit_account_id_must_not_be_zero
      else if U128.equal request.debit_account_id request.credit_account_id
      then error Transfer_accounts_must_be_different
      else if not (is_zero request.pending_id)
      then error Transfer_pending_id_must_be_zero
      else if (not request.flags.pending) && not (Int32.equal request.timeout 0l)
      then error Transfer_timeout_reserved_for_pending_transfer
      else if
        (request.flags.closing_debit || request.flags.closing_credit)
        && not request.flags.pending
      then error Transfer_closing_transfer_must_be_pending
      else if Int32.equal request.ledger 0l
      then error Transfer_ledger_must_not_be_zero
      else if request.code = 0
      then error Transfer_code_must_not_be_zero
      else (
        match Id_table.find_opt state.accounts request.debit_account_id with
        | None -> error Transfer_debit_account_not_found
        | Some debit ->
          (match Id_table.find_opt state.accounts request.credit_account_id with
           | None -> error Transfer_credit_account_not_found
           | Some credit ->
             if not (Int32.equal debit.ledger credit.ledger)
             then error Transfer_accounts_must_have_same_ledger
             else if not (Int32.equal request.ledger debit.ledger)
             then error Transfer_must_have_same_ledger_as_accounts
             else if debit.flags.closed || credit.flags.closed
             then error Transfer_account_already_closed
             else (
               let amount = effective_balancing_amount request debit credit in
               if debits_exceed_credits debit amount
               then error Transfer_exceeds_credits
               else if credits_exceed_debits credit amount
               then error Transfer_exceeds_debits
               else (
                 match
                   validate_event_timestamp
                     ~commit_timestamp:state.commit_timestamp
                     ~timestamp_event
                     ~imported:request.flags.imported
                     ~timestamp:request.timestamp
                 with
                 | Error `Must_be_zero -> error Transfer_timestamp_must_be_zero
                 | Error `Out_of_range -> error Transfer_imported_timestamp_out_of_range
                 | Error `Regressed -> error Transfer_imported_timestamp_must_not_regress
                 | Ok timestamp ->
                   if request.flags.imported && not (Int32.equal request.timeout 0l)
                   then error Transfer_imported_timeout_must_be_zero
                   else if
                     request.flags.pending
                     && timeout_overflows ~timestamp ~timeout:request.timeout
                   then error Transfer_overflows_timeout
                   else (
                     let debit_balance =
                       if request.flags.pending
                       then sum_or_error debit.debits_pending amount
                       else sum_or_error debit.debits_posted amount
                     in
                     let credit_balance =
                       if request.flags.pending
                       then sum_or_error credit.credits_pending amount
                       else sum_or_error credit.credits_posted amount
                     in
                     match debit_balance, credit_balance with
                     | Error _, _ | _, Error _ -> error Transfer_overflows_balance
                     | Ok debit_balance, Ok credit_balance ->
                       let debit =
                         if request.flags.pending
                         then { debit with debits_pending = debit_balance }
                         else { debit with debits_posted = debit_balance }
                       in
                       let credit =
                         if request.flags.pending
                         then { credit with credits_pending = credit_balance }
                         else { credit with credits_posted = credit_balance }
                       in
                       let debit =
                         if request.flags.closing_debit
                         then { debit with flags = { debit.flags with closed = true } }
                         else debit
                       in
                       let credit =
                         if request.flags.closing_credit
                         then { credit with flags = { credit.flags with closed = true } }
                         else credit
                       in
                       Id_table.replace state.accounts debit.id debit;
                       Id_table.replace state.accounts credit.id credit;
                       let transfer = { request with amount; timestamp } in
                       store_transfer state transfer;
                       if request.flags.pending
                       then Id_table.add state.pending transfer.id Pending;
                       record_account_history state transfer debit credit;
                       { timestamp; status = Transfer_created }))))))
;;

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

let create_accounts state ~timestamp (requests : account list) =
  let timestamp_cursor = ref timestamp in
  let execute_chain chain =
    match chain with
    | [ (request : account) ] when not request.flags.linked ->
      let result = create_account_one state ~timestamp_event:!timestamp_cursor request in
      timestamp_cursor := Int64.succ !timestamp_cursor;
      [ result ]
    | _ ->
      let trial = clone state in
      let results =
        List.map
          (fun request ->
             let result =
               create_account_one trial ~timestamp_event:!timestamp_cursor request
             in
             timestamp_cursor := Int64.succ !timestamp_cursor;
             result)
          chain
      in
      (match List.find_opt (fun result -> result.status <> Account_created) results with
       | None ->
         replace_state state trial;
         results
       | Some failure ->
         List.map
           (fun result ->
              if result == failure
              then result
              else { timestamp = 0L; status = Account_linked_event_failed })
           results)
  in
  let request_chains =
    chains requests (fun (account : account) -> account.flags.linked)
  in
  match List.rev request_chains with
  | open_chain :: complete_chains
    when open_chain <> [] && (List.hd (List.rev open_chain)).flags.linked ->
    let complete_results = List.concat_map execute_chain (List.rev complete_chains) in
    let open_results =
      List.mapi
        (fun index _ ->
           timestamp_cursor := Int64.succ !timestamp_cursor;
           { timestamp = 0L
           ; status =
               (if index = List.length open_chain - 1
                then Account_linked_event_chain_open
                else Account_linked_event_failed)
           })
        open_chain
    in
    complete_results @ open_results
  | _ -> List.concat_map execute_chain request_chains
;;

let create_transfers state ~timestamp (requests : transfer list) =
  let timestamp_cursor = ref timestamp in
  let execute_chain chain =
    match chain with
    | [ (request : transfer) ] when not request.flags.linked ->
      let result = create_transfer_one state ~timestamp_event:!timestamp_cursor request in
      timestamp_cursor := Int64.succ !timestamp_cursor;
      [ result ]
    | _ ->
      let trial = clone state in
      let results =
        List.map
          (fun request ->
             let result =
               create_transfer_one trial ~timestamp_event:!timestamp_cursor request
             in
             timestamp_cursor := Int64.succ !timestamp_cursor;
             result)
          chain
      in
      (match List.find_opt (fun result -> result.status <> Transfer_created) results with
       | None ->
         replace_state state trial;
         results
       | Some failure ->
         List.map
           (fun result ->
              if result == failure
              then result
              else { timestamp = 0L; status = Transfer_linked_event_failed })
           results)
  in
  let request_chains =
    chains requests (fun (transfer : transfer) -> transfer.flags.linked)
  in
  match List.rev request_chains with
  | open_chain :: complete_chains
    when open_chain <> [] && (List.hd (List.rev open_chain)).flags.linked ->
    let complete_results = List.concat_map execute_chain (List.rev complete_chains) in
    let open_results =
      List.mapi
        (fun index _ ->
           timestamp_cursor := Int64.succ !timestamp_cursor;
           { timestamp = 0L
           ; status =
               (if index = List.length open_chain - 1
                then Transfer_linked_event_chain_open
                else Transfer_linked_event_failed)
           })
        open_chain
    in
    complete_results @ open_results
  | _ -> List.concat_map execute_chain request_chains
;;

let lookup_accounts state ids = List.filter_map (Id_table.find_opt state.accounts) ids
let lookup_transfers state ids = List.filter_map (Id_table.find_opt state.transfers) ids

let bounded_timestamp ~minimum ~maximum timestamp =
  (Int64.equal minimum 0L || Int64.compare timestamp minimum >= 0)
  && (Int64.equal maximum 0L || Int64.compare timestamp maximum <= 0)
;;

let take limit list =
  let rec loop count acc = function
    | _ when count = 0 -> List.rev acc
    | [] -> List.rev acc
    | head :: tail -> loop (count - 1) (head :: acc) tail
  in
  if limit <= 0 then [] else loop limit [] list
;;

let sorted_by_timestamp ~reversed timestamp values =
  List.sort
    (fun a b ->
       let order = Int64.compare (timestamp a) (timestamp b) in
       if reversed then -order else order)
    values
;;

let query_accounts state (filter : query_filter) =
  Id_table.to_seq_values state.accounts
  |> List.of_seq
  |> List.filter (fun (account : account) ->
    (is_zero filter.user_data_128 || U128.equal account.user_data_128 filter.user_data_128)
    && (Int64.equal filter.user_data_64 0L
        || Int64.equal account.user_data_64 filter.user_data_64)
    && (Int32.equal filter.user_data_32 0l
        || Int32.equal account.user_data_32 filter.user_data_32)
    && (Int32.equal filter.ledger 0l || Int32.equal account.ledger filter.ledger)
    && (filter.code = 0 || account.code = filter.code)
    && bounded_timestamp
         ~minimum:filter.timestamp_min
         ~maximum:filter.timestamp_max
         account.timestamp)
  |> sorted_by_timestamp ~reversed:filter.reversed (fun (account : account) ->
    account.timestamp)
  |> take filter.limit
;;

let query_transfers state (filter : query_filter) =
  Id_table.to_seq_values state.transfers
  |> List.of_seq
  |> List.filter (fun (transfer : transfer) ->
    (is_zero filter.user_data_128
     || U128.equal transfer.user_data_128 filter.user_data_128)
    && (Int64.equal filter.user_data_64 0L
        || Int64.equal transfer.user_data_64 filter.user_data_64)
    && (Int32.equal filter.user_data_32 0l
        || Int32.equal transfer.user_data_32 filter.user_data_32)
    && (Int32.equal filter.ledger 0l || Int32.equal transfer.ledger filter.ledger)
    && (filter.code = 0 || transfer.code = filter.code)
    && bounded_timestamp
         ~minimum:filter.timestamp_min
         ~maximum:filter.timestamp_max
         transfer.timestamp)
  |> sorted_by_timestamp ~reversed:filter.reversed (fun (transfer : transfer) ->
    transfer.timestamp)
  |> take filter.limit
;;

let get_account_transfers state (filter : account_filter) =
  Id_table.to_seq_values state.transfers
  |> List.of_seq
  |> List.filter (fun (transfer : transfer) ->
    ((filter.debits && U128.equal transfer.debit_account_id filter.account_id)
     || (filter.credits && U128.equal transfer.credit_account_id filter.account_id))
    && (is_zero filter.user_data_128
        || U128.equal transfer.user_data_128 filter.user_data_128)
    && (Int64.equal filter.user_data_64 0L
        || Int64.equal transfer.user_data_64 filter.user_data_64)
    && (Int32.equal filter.user_data_32 0l
        || Int32.equal transfer.user_data_32 filter.user_data_32)
    && (filter.code = 0 || transfer.code = filter.code)
    && bounded_timestamp
         ~minimum:filter.timestamp_min
         ~maximum:filter.timestamp_max
         transfer.timestamp)
  |> sorted_by_timestamp ~reversed:filter.reversed (fun (transfer : transfer) ->
    transfer.timestamp)
  |> take filter.limit
;;

let get_account_balances state (filter : account_filter) =
  match Id_table.find_opt state.accounts filter.account_id with
  | None -> []
  | Some account ->
    if
      (not account.flags.history)
      || ((not filter.debits) && not filter.credits)
      || filter.limit <= 0
      || ((not (Int64.equal filter.timestamp_min 0L))
          && (not (Int64.equal filter.timestamp_max 0L))
          && Int64.compare filter.timestamp_min filter.timestamp_max > 0)
    then []
    else
      Option.value (Id_table.find_opt state.account_history filter.account_id) ~default:[]
      |> List.filter (fun ((snapshot : account), transfer) ->
        ((filter.debits && U128.equal transfer.debit_account_id filter.account_id)
         || (filter.credits && U128.equal transfer.credit_account_id filter.account_id))
        && (is_zero filter.user_data_128
            || U128.equal transfer.user_data_128 filter.user_data_128)
        && (Int64.equal filter.user_data_64 0L
            || Int64.equal transfer.user_data_64 filter.user_data_64)
        && (Int32.equal filter.user_data_32 0l
            || Int32.equal transfer.user_data_32 filter.user_data_32)
        && (filter.code = 0 || transfer.code = filter.code)
        && bounded_timestamp
             ~minimum:filter.timestamp_min
             ~maximum:filter.timestamp_max
             snapshot.timestamp)
      |> List.map fst
      |> sorted_by_timestamp ~reversed:filter.reversed (fun (snapshot : account) ->
        snapshot.timestamp)
      |> take filter.limit
;;

let expire_pending_transfers state ~timestamp =
  let expired = ref 0 in
  Id_table.iter
    (fun id status ->
       match status, Id_table.find_opt state.transfers id with
       | Pending, Some transfer when Int32.compare transfer.timeout 0l > 0 ->
         let expires_at = Int64.add transfer.timestamp (timeout_ns transfer.timeout) in
         if Int64.compare expires_at timestamp <= 0
         then (
           let debit = Id_table.find state.accounts transfer.debit_account_id in
           let credit = Id_table.find state.accounts transfer.credit_account_id in
           match
             ( U128.sub debit.debits_pending transfer.amount
             , U128.sub credit.credits_pending transfer.amount )
           with
           | Ok debits_pending, Ok credits_pending ->
             let debit =
               { debit with
                 debits_pending
               ; flags =
                   (if transfer.flags.closing_debit
                    then { debit.flags with closed = false }
                    else debit.flags)
               }
             in
             let credit =
               { credit with
                 credits_pending
               ; flags =
                   (if transfer.flags.closing_credit
                    then { credit.flags with closed = false }
                    else credit.flags)
               }
             in
             Id_table.replace state.accounts debit.id debit;
             Id_table.replace state.accounts credit.id credit;
             Id_table.replace state.pending id Expired;
             record_account_history state { transfer with timestamp } debit credit;
             incr expired
           | _ -> failwith "pending-balance invariant violated")
       | _ -> ())
    state.pending;
  if !expired > 0 then state.commit_timestamp <- timestamp;
  !expired
;;
