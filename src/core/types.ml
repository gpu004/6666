(* types.ml — Core domain types for TigerOCaml *)

type error =
  | Invalid_u16 of int
  | Invalid_u32 of int64
  | Invalid_u64 of int64
  | Id_must_not_be_zero
  | Id_must_not_be_int_max
  | Ledger_must_not_be_zero
  | Timestamp_must_not_be_negative
  | Padding_must_be_zero
  | Flags_are_mutually_exclusive

type u16 = int
type u32 = int32
type u64 = int64
type u128 = { hi : int64; lo : int64 }

let u128_zero = { hi = 0L; lo = 0L }
let u128_max = { hi = Int64.minus_one; lo = Int64.minus_one }
let u128_equal a b = Int64.equal a.hi b.hi && Int64.equal a.lo b.lo

let u128_compare a b =
  let c = Int64.unsigned_compare a.hi b.hi in
  if c <> 0 then c else Int64.unsigned_compare a.lo b.lo

let u128_of_int n = { hi = 0L; lo = Int64.of_int n }

let u128_to_string { hi; lo } =
  if Int64.equal hi 0L then Printf.sprintf "%Lu" lo
  else Printf.sprintf "0x%Lx%016Lx" hi lo

let is_valid_u16 v = v >= 0 && v <= 0xFFFF

type account_id = u128
type transfer_id = u128
type ledger_id = u32
type amount = u128
type timestamp = u64

let validate_id v =
  if u128_equal v u128_zero then Error Id_must_not_be_zero
  else if u128_equal v u128_max then Error Id_must_not_be_int_max
  else Ok v

let account_id_of_u128 = validate_id
let transfer_id_of_u128 = validate_id
let account_id_to_u128 v = v
let transfer_id_to_u128 v = v

let ledger_id_of_u32 v =
  if Int32.equal v 0l then Error Ledger_must_not_be_zero else Ok v

let ledger_id_to_u32 v = v
let amount_of_u128 v = Ok v
let amount_to_u128 v = v

let timestamp_of_u64 v =
  if Int64.compare v 0L < 0 then Error Timestamp_must_not_be_negative else Ok v

let timestamp_to_u64 v = v

type account_flags = {
  linked : bool;
  debits_must_not_exceed_credits : bool;
  credits_must_not_exceed_debits : bool;
  history : bool;
  imported : bool;
  closed : bool;
  padding : int;
}

let account_flags_default =
  {
    linked = false;
    debits_must_not_exceed_credits = false;
    credits_must_not_exceed_debits = false;
    history = false;
    imported = false;
    closed = false;
    padding = 0;
  }

let account_flags_make ~linked ~debits_must_not_exceed_credits
    ~credits_must_not_exceed_debits ~history ~imported ~closed =
  if debits_must_not_exceed_credits && credits_must_not_exceed_debits then
    Error Flags_are_mutually_exclusive
  else
    Ok
      {
        linked;
        debits_must_not_exceed_credits;
        credits_must_not_exceed_debits;
        history;
        imported;
        closed;
        padding = 0;
      }

let account_flags_to_u16 f =
  let b i v = if v then 1 lsl i else 0 in
  b 0 f.linked
  lor b 1 f.debits_must_not_exceed_credits
  lor b 2 f.credits_must_not_exceed_debits
  lor b 3 f.history
  lor b 4 f.imported
  lor b 5 f.closed

let account_flags_of_u16 bits =
  if bits < 0 || bits > 0xFFFF then Error (Invalid_u16 bits)
  else
    let bit i = bits land (1 lsl i) <> 0 in
    let padding = bits lsr 6 in
    if padding <> 0 then Error Padding_must_be_zero
    else
      account_flags_make ~linked:(bit 0)
        ~debits_must_not_exceed_credits:(bit 1)
        ~credits_must_not_exceed_debits:(bit 2) ~history:(bit 3)
        ~imported:(bit 4) ~closed:(bit 5)

type transfer_flags = {
  linked : bool;
  pending : bool;
  post_pending_transfer : bool;
  void_pending_transfer : bool;
  balancing_debit : bool;
  balancing_credit : bool;
  closing_debit : bool;
  closing_credit : bool;
  imported : bool;
  padding : int;
}

let transfer_flags_default =
  {
    linked = false;
    pending = false;
    post_pending_transfer = false;
    void_pending_transfer = false;
    balancing_debit = false;
    balancing_credit = false;
    closing_debit = false;
    closing_credit = false;
    imported = false;
    padding = 0;
  }

let transfer_flags_mutually_exclusive pending post_pending_transfer
    void_pending_transfer balancing_debit balancing_credit =
  let phase_count =
    (if pending then 1 else 0)
    + (if post_pending_transfer then 1 else 0)
    + (if void_pending_transfer then 1 else 0)
  in
  phase_count > 1 || (balancing_debit && balancing_credit)

let transfer_flags_make ~linked ~pending ~post_pending_transfer
    ~void_pending_transfer ~balancing_debit ~balancing_credit ~closing_debit
    ~closing_credit ~imported =
  if
    transfer_flags_mutually_exclusive pending post_pending_transfer
      void_pending_transfer balancing_debit balancing_credit
  then Error Flags_are_mutually_exclusive
  else
    Ok
      {
        linked;
        pending;
        post_pending_transfer;
        void_pending_transfer;
        balancing_debit;
        balancing_credit;
        closing_debit;
        closing_credit;
        imported;
        padding = 0;
      }

let transfer_flags_to_u16 f =
  let b i v = if v then 1 lsl i else 0 in
  b 0 f.linked
  lor b 1 f.pending
  lor b 2 f.post_pending_transfer
  lor b 3 f.void_pending_transfer
  lor b 4 f.balancing_debit
  lor b 5 f.balancing_credit
  lor b 6 f.closing_debit
  lor b 7 f.closing_credit
  lor b 8 f.imported

let transfer_flags_of_u16 bits =
  if bits < 0 || bits > 0xFFFF then Error (Invalid_u16 bits)
  else
    let bit i = bits land (1 lsl i) <> 0 in
    let padding = bits lsr 9 in
    if padding <> 0 then Error Padding_must_be_zero
    else
      transfer_flags_make ~linked:(bit 0) ~pending:(bit 1)
        ~post_pending_transfer:(bit 2) ~void_pending_transfer:(bit 3)
        ~balancing_debit:(bit 4) ~balancing_credit:(bit 5)
        ~closing_debit:(bit 6) ~closing_credit:(bit 7) ~imported:(bit 8)

type transfer_pending_status = None | Pending | Posted | Voided | Expired

let transfer_pending_status_to_u8 = function
  | None -> 0
  | Pending -> 1
  | Posted -> 2
  | Voided -> 3
  | Expired -> 4

let transfer_pending_status_of_u8 = function
  | 0 -> Some None
  | 1 -> Some Pending
  | 2 -> Some Posted
  | 3 -> Some Voided
  | 4 -> Some Expired
  | _ -> None

type account = {
  id : account_id;
  debits_pending : u128;
  debits_posted : u128;
  credits_pending : u128;
  credits_posted : u128;
  user_data_128 : u128;
  user_data_64 : u64;
  user_data_32 : u32;
  reserved : u32;
  ledger : ledger_id;
  code : u16;
  flags : account_flags;
  timestamp : u64;
}

let account_make ~id ~debits_pending ~debits_posted ~credits_pending
    ~credits_posted ~user_data_128 ~user_data_64 ~user_data_32 ~reserved
    ~ledger ~code ~flags ~timestamp =
  if not (is_valid_u16 code) then Error (Invalid_u16 code)
  else if code = 0 then Error (Invalid_u16 code)
  else if not (Int32.equal reserved 0l) then Error Padding_must_be_zero
  else
    Ok
      {
        id;
        debits_pending;
        debits_posted;
        credits_pending;
        credits_posted;
        user_data_128;
        user_data_64;
        user_data_32;
        reserved;
        ledger;
        code;
        flags;
        timestamp;
      }

type transfer = {
  id : transfer_id;
  debit_account_id : account_id;
  credit_account_id : account_id;
  amount : amount;
  pending_id : u128;
  user_data_128 : u128;
  user_data_64 : u64;
  user_data_32 : u32;
  timeout : u32;
  ledger : ledger_id;
  code : u16;
  flags : transfer_flags;
  timestamp : u64;
}

let transfer_make ~id ~debit_account_id ~credit_account_id ~amount ~pending_id
    ~user_data_128 ~user_data_64 ~user_data_32 ~timeout ~ledger ~code ~flags
    ~timestamp =
  if not (is_valid_u16 code) then Error (Invalid_u16 code)
  else if code = 0 then Error (Invalid_u16 code)
  else
    Ok
      {
        id;
        debit_account_id;
        credit_account_id;
        amount;
        pending_id;
        user_data_128;
        user_data_64;
        user_data_32;
        timeout;
        ledger;
        code;
        flags;
        timestamp;
      }

type account_balance = {
  debits_pending : u128;
  debits_posted : u128;
  credits_pending : u128;
  credits_posted : u128;
  timestamp : u64;
  reserved : bytes;
}

let account_balance_make ~debits_pending ~debits_posted ~credits_pending
    ~credits_posted ~timestamp ~reserved =
  if Bytes.length reserved <> 56 then Error Padding_must_be_zero
  else
    Ok
      {
        debits_pending;
        debits_posted;
        credits_pending;
        credits_posted;
        timestamp;
        reserved;
      }

type create_accounts_result = { index : u32; result : Errors.create_account_result }
type create_transfers_result = { index : u32; result : Errors.create_transfer_result }

type account_filter_flags = {
  debits : bool;
  credits : bool;
  reversed : bool;
  padding : int;
}

let account_filter_flags_default =
  { debits = false; credits = false; reversed = false; padding = 0 }

let account_filter_flags_to_u32 f =
  let b i v = if v then Int32.shift_left 1l i else 0l in
  Int32.logor (b 0 f.debits)
    (Int32.logor (b 1 f.credits) (b 2 f.reversed))

let account_filter_flags_of_u32 bits =
  let bit i = Int32.logand bits (Int32.shift_left 1l i) <> 0l in
  let padding = Int32.shift_right_logical bits 3 in
  if padding <> 0l then Error Padding_must_be_zero
  else Ok { debits = bit 0; credits = bit 1; reversed = bit 2; padding = 0 }

type account_filter = {
  account_id : u128;
  user_data_128 : u128;
  user_data_64 : u64;
  user_data_32 : u32;
  code : u16;
  reserved : bytes;
  timestamp_min : u64;
  timestamp_max : u64;
  limit : u32;
  flags : account_filter_flags;
}

let account_filter_make ~account_id ~user_data_128 ~user_data_64 ~user_data_32
    ~code ~reserved ~timestamp_min ~timestamp_max ~limit ~flags =
  if not (is_valid_u16 code) then Error (Invalid_u16 code)
  else if Bytes.length reserved <> 58 then Error Padding_must_be_zero
  else
    Ok
      {
        account_id;
        user_data_128;
        user_data_64;
        user_data_32;
        code;
        reserved;
        timestamp_min;
        timestamp_max;
        limit;
        flags;
      }

type query_filter_flags = {
  reversed : bool;
  padding : int;
}

let query_filter_flags_default = { reversed = false; padding = 0 }

let query_filter_flags_to_u32 f =
  if f.reversed then 1l else 0l

let query_filter_flags_of_u32 bits =
  let reversed = Int32.logand bits 1l <> 0l in
  let padding = Int32.shift_right_logical bits 1 in
  if padding <> 0l then Error Padding_must_be_zero
  else Ok { reversed; padding = 0 }

type query_filter = {
  user_data_128 : u128;
  user_data_64 : u64;
  user_data_32 : u32;
  ledger : u32;
  code : u16;
  reserved : bytes;
  timestamp_min : u64;
  timestamp_max : u64;
  limit : u32;
  flags : query_filter_flags;
}

let query_filter_make ~user_data_128 ~user_data_64 ~user_data_32 ~ledger ~code
    ~reserved ~timestamp_min ~timestamp_max ~limit ~flags =
  if not (is_valid_u16 code) then Error (Invalid_u16 code)
  else if Bytes.length reserved <> 6 then Error Padding_must_be_zero
  else
    Ok
      {
        user_data_128;
        user_data_64;
        user_data_32;
        ledger;
        code;
        reserved;
        timestamp_min;
        timestamp_max;
        limit;
        flags;
      }

type change_event_type =
  | Single_phase
  | Two_phase_pending
  | Two_phase_posted
  | Two_phase_voided
  | Two_phase_expired

let change_event_type_to_u8 = function
  | Single_phase -> 0
  | Two_phase_pending -> 1
  | Two_phase_posted -> 2
  | Two_phase_voided -> 3
  | Two_phase_expired -> 4

let change_event_type_of_u8 = function
  | 0 -> Some Single_phase
  | 1 -> Some Two_phase_pending
  | 2 -> Some Two_phase_posted
  | 3 -> Some Two_phase_voided
  | 4 -> Some Two_phase_expired
  | _ -> None

type change_event = {
  transfer_id : u128;
  transfer_amount : u128;
  transfer_pending_id : u128;
  transfer_user_data_128 : u128;
  transfer_user_data_64 : u64;
  transfer_user_data_32 : u32;
  transfer_timeout : u32;
  transfer_code : u16;
  transfer_flags : transfer_flags;
  ledger : u32;
  event_type : change_event_type;
  reserved : bytes;
  debit_account_id : u128;
  debit_account_debits_pending : u128;
  debit_account_debits_posted : u128;
  debit_account_credits_pending : u128;
  debit_account_credits_posted : u128;
  debit_account_user_data_128 : u128;
  debit_account_user_data_64 : u64;
  debit_account_user_data_32 : u32;
  debit_account_code : u16;
  debit_account_flags : account_flags;
  credit_account_id : u128;
  credit_account_debits_pending : u128;
  credit_account_debits_posted : u128;
  credit_account_credits_pending : u128;
  credit_account_credits_posted : u128;
  credit_account_user_data_128 : u128;
  credit_account_user_data_64 : u64;
  credit_account_user_data_32 : u32;
  credit_account_code : u16;
  credit_account_flags : account_flags;
  timestamp : u64;
  transfer_timestamp : u64;
  debit_account_timestamp : u64;
  credit_account_timestamp : u64;
}

let change_event_make ~transfer_id ~transfer_amount ~transfer_pending_id
    ~transfer_user_data_128 ~transfer_user_data_64 ~transfer_user_data_32
    ~transfer_timeout ~transfer_code ~transfer_flags ~ledger ~event_type
    ~reserved ~debit_account_id ~debit_account_debits_pending
    ~debit_account_debits_posted ~debit_account_credits_pending
    ~debit_account_credits_posted ~debit_account_user_data_128
    ~debit_account_user_data_64 ~debit_account_user_data_32 ~debit_account_code
    ~debit_account_flags ~credit_account_id ~credit_account_debits_pending
    ~credit_account_debits_posted ~credit_account_credits_pending
    ~credit_account_credits_posted ~credit_account_user_data_128
    ~credit_account_user_data_64 ~credit_account_user_data_32 ~credit_account_code
    ~credit_account_flags ~timestamp ~transfer_timestamp
    ~debit_account_timestamp ~credit_account_timestamp =
  if not (is_valid_u16 transfer_code) then Error (Invalid_u16 transfer_code)
  else if not (is_valid_u16 debit_account_code) then Error (Invalid_u16 debit_account_code)
  else if not (is_valid_u16 credit_account_code) then Error (Invalid_u16 credit_account_code)
  else if Bytes.length reserved <> 39 then Error Padding_must_be_zero
  else
    Ok
      {
        transfer_id;
        transfer_amount;
        transfer_pending_id;
        transfer_user_data_128;
        transfer_user_data_64;
        transfer_user_data_32;
        transfer_timeout;
        transfer_code;
        transfer_flags;
        ledger;
        event_type;
        reserved;
        debit_account_id;
        debit_account_debits_pending;
        debit_account_debits_posted;
        debit_account_credits_pending;
        debit_account_credits_posted;
        debit_account_user_data_128;
        debit_account_user_data_64;
        debit_account_user_data_32;
        debit_account_code;
        debit_account_flags;
        credit_account_id;
        credit_account_debits_pending;
        credit_account_debits_posted;
        credit_account_credits_pending;
        credit_account_credits_posted;
        credit_account_user_data_128;
        credit_account_user_data_64;
        credit_account_user_data_32;
        credit_account_code;
        credit_account_flags;
        timestamp;
        transfer_timestamp;
        debit_account_timestamp;
        credit_account_timestamp;
      }

type change_events_filter = {
  timestamp_min : u64;
  timestamp_max : u64;
  limit : u32;
  reserved : bytes;
}

let change_events_filter_make ~timestamp_min ~timestamp_max ~limit ~reserved =
  if Bytes.length reserved <> 44 then Error Padding_must_be_zero
  else Ok { timestamp_min; timestamp_max; limit; reserved }

(* Compatibility aliases used by older modules. *)
type uint128 = u128

let uint128_zero = u128_zero
let uint128_max = u128_max
let uint128_equal = u128_equal
let uint128_compare = u128_compare
let uint128_of_int = u128_of_int
let uint128_to_string = u128_to_string

type id = account_id

let id_of_uint128 v =
  match account_id_of_u128 v with
  | Ok id -> Ok id
  | Error Id_must_not_be_zero -> Error "id must not be zero"
  | Error Id_must_not_be_int_max -> Error "id must not be 2^128 - 1"
  | Error _ -> Error "invalid id"

let id_to_uint128 = account_id_to_u128
let id_equal a b = u128_equal (id_to_uint128 a) (id_to_uint128 b)
let id_compare a b = u128_compare (id_to_uint128 a) (id_to_uint128 b)
let id_to_string id = u128_to_string (id_to_uint128 id)

type ledger = ledger_id

let ledger_of_int32 v =
  match ledger_id_of_u32 v with
  | Ok ledger -> Ok ledger
  | Error _ -> Error "ledger must not be zero"

let ledger_to_int32 = ledger_id_to_u32
let ledger_equal a b = Int32.equal (ledger_to_int32 a) (ledger_to_int32 b)

type code = u16

let code_of_int v =
  if v = 0 then Error "code must not be zero"
  else if not (is_valid_u16 v) then Error "code must be a uint16"
  else Ok v

let code_to_int c = c
let code_equal = Int.equal

let account_flags_to_int = account_flags_to_u16

let account_flags_of_int bits =
  match account_flags_of_u16 bits with
  | Ok flags -> flags
  | Error _ -> account_flags_default

let transfer_flags_to_int = transfer_flags_to_u16

let transfer_flags_of_int bits =
  match transfer_flags_of_u16 bits with
  | Ok flags -> flags
  | Error _ -> transfer_flags_default
