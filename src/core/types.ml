(* types.ml — Core domain types for TigerOCaml *)

(* --- uint128 ------------------------------------------------------------ *)

type uint128 = { hi : int64; lo : int64 }

let uint128_zero = { hi = 0L; lo = 0L }

let uint128_max =
  { hi = Int64.minus_one (* 0xFFFFFFFFFFFFFFFF *); lo = Int64.minus_one }

let uint128_equal a b = Int64.equal a.hi b.hi && Int64.equal a.lo b.lo
let uint128_compare a b =
  let c = Int64.unsigned_compare a.hi b.hi in
  if c <> 0 then c else Int64.unsigned_compare a.lo b.lo

let uint128_of_int n = { hi = 0L; lo = Int64.of_int n }

let uint128_to_string { hi; lo } =
  if Int64.equal hi 0L then Printf.sprintf "%Lu" lo
  else Printf.sprintf "0x%Lx%016Lx" hi lo

(* --- id ------------------------------------------------------------------ *)

type id = uint128

let id_of_uint128 v =
  if uint128_equal v uint128_zero then Error "id must not be zero"
  else if uint128_equal v uint128_max then Error "id must not be 2^128 - 1"
  else Ok v

let id_to_uint128 id = id
let id_equal = uint128_equal
let id_compare = uint128_compare
let id_to_string = uint128_to_string

(* --- ledger -------------------------------------------------------------- *)

type ledger = int32

let ledger_of_int32 v =
  if Int32.equal v 0l then Error "ledger must not be zero" else Ok v

let ledger_to_int32 l = l
let ledger_equal = Int32.equal

(* --- code ---------------------------------------------------------------- *)

type code = int

let code_of_int v =
  if v = 0 then Error "code must not be zero"
  else if v < 0 || v > 0xFFFF then Error "code must be a uint16"
  else Ok v

let code_to_int c = c
let code_equal = Int.equal

(* --- amount & timestamp -------------------------------------------------- *)

type amount = uint128
type timestamp = int64

(* --- account_flags ------------------------------------------------------- *)

type account_flags = {
  linked : bool;
  debits_must_not_exceed_credits : bool;
  credits_must_not_exceed_debits : bool;
  history : bool;
  imported : bool;
  closed : bool;
}

let account_flags_default =
  {
    linked = false;
    debits_must_not_exceed_credits = false;
    credits_must_not_exceed_debits = false;
    history = false;
    imported = false;
    closed = false;
  }

let account_flags_to_int f =
  let b i v = if v then 1 lsl i else 0 in
  b 0 f.linked
  lor b 1 f.debits_must_not_exceed_credits
  lor b 2 f.credits_must_not_exceed_debits
  lor b 3 f.history
  lor b 4 f.imported
  lor b 5 f.closed

let account_flags_of_int bits =
  let bit i = bits land (1 lsl i) <> 0 in
  {
    linked = bit 0;
    debits_must_not_exceed_credits = bit 1;
    credits_must_not_exceed_debits = bit 2;
    history = bit 3;
    imported = bit 4;
    closed = bit 5;
  }

(* --- transfer_flags ------------------------------------------------------ *)

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
  }

let transfer_flags_to_int f =
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

let transfer_flags_of_int bits =
  let bit i = bits land (1 lsl i) <> 0 in
  {
    linked = bit 0;
    pending = bit 1;
    post_pending_transfer = bit 2;
    void_pending_transfer = bit 3;
    balancing_debit = bit 4;
    balancing_credit = bit 5;
    closing_debit = bit 6;
    closing_credit = bit 7;
    imported = bit 8;
  }

(* --- domain records ------------------------------------------------------ *)

type account = {
  id : id;
  debits_pending : uint128;
  debits_posted : uint128;
  credits_pending : uint128;
  credits_posted : uint128;
  user_data_128 : uint128;
  user_data_64 : int64;
  user_data_32 : int32;
  reserved : int;
  ledger : ledger;
  code : code;
  flags : account_flags;
  timestamp : timestamp;
}

type transfer = {
  id : id;
  debit_account_id : id;
  credit_account_id : id;
  amount : amount;
  pending_id : uint128;
  user_data_128 : uint128;
  user_data_64 : int64;
  user_data_32 : int32;
  timeout : int32;
  ledger : ledger;
  code : code;
  flags : transfer_flags;
  timestamp : timestamp;
}

(* --- query filters ------------------------------------------------------- *)

type account_filter = {
  account_id : id;
  timestamp_min : timestamp;
  timestamp_max : timestamp;
  limit : int32;
  flags : int32;
}

type query_filter = {
  user_data_128 : uint128;
  user_data_64 : int64;
  user_data_32 : int32;
  ledger : int32;
  code : int;
  timestamp_min : timestamp;
  timestamp_max : timestamp;
  limit : int32;
  flags : int32;
}
