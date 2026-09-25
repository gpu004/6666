open Tigerbeetle_state_machine

let require condition message = if not condition then failwith message

let test_exact_codes () =
  require (Result_code.created_code = 0xffff_ffff) "created code";
  require
    (Result_code.account_to_code Account_created = Some Result_code.created_code)
    "created";
  require
    (Result_code.account_to_code Account_linked_event_failed = Some 1)
    "linked failed";
  require (Result_code.account_to_code Account_exists = Some 21) "account exists";
  require
    (Result_code.transfer_to_code Transfer_created = Some Result_code.created_code)
    "transfer created";
  require (Result_code.transfer_to_code Transfer_exists = Some 46) "transfer exists";
  require
    (Result_code.transfer_to_code Transfer_exceeds_credits = Some 54)
    "exceeds credits";
  require
    (Result_code.transfer_to_code Transfer_pending_transfer_already_posted = Some 33)
    "already posted";
  require (Result_code.account_of_code 2 = Some Account_linked_event_chain_open) "decode";
  require
    (Result_code.transfer_to_code Transfer_pending_id_must_be_zero = Some 13)
    "pending id zero";
  require (Result_code.transfer_of_code 0xffff = None) "unknown decode"
;;

let test_coarse_codes () =
  require
    (Result_code.transfer_to_code Transfer_overflows_balance = None)
    "coarse status has no exact code";
  require
    (List.length (Result_code.transfer_codes Transfer_overflows_balance) > 1)
    "coarse status lists several codes";
  List.iter
    (fun status ->
      let codes = Result_code.transfer_codes status in
      require (codes <> []) "every transfer status maps to a code";
      List.iter
        (fun code ->
          require
            (Result_code.transfer_of_code code = Some status)
            "transfer codes decode back")
        codes)
    Result_code.transfer_statuses;
  List.iter
    (fun status ->
      let codes = Result_code.account_codes status in
      require (codes <> []) "every account status maps to a code";
      List.iter
        (fun code ->
          require
            (Result_code.account_of_code code = Some status)
            "account codes decode back")
        codes)
    Result_code.account_statuses
;;

let test_codes_unique () =
  let all_codes statuses codes = List.concat_map codes statuses in
  let unique codes = List.length (List.sort_uniq compare codes) = List.length codes in
  require
    (unique (all_codes Result_code.account_statuses Result_code.account_codes))
    "account codes are disjoint";
  require
    (unique (all_codes Result_code.transfer_statuses Result_code.transfer_codes))
    "transfer codes are disjoint"
;;

let () =
  test_exact_codes ();
  test_coarse_codes ();
  test_codes_unique ();
  print_endline "result code tests passed"
;;
