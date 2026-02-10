(* request_codec.ml — Binary encoding/decoding for request payloads *)

open Tiger_core.Types
open Tiger_core.Requests

(* --- Wire sizes ---------------------------------------------------------- *)

let account_wire_size = 128
let transfer_wire_size = 128
let id_wire_size = 16

(* --- uint128 helpers ----------------------------------------------------- *)

let put_uint128 buf off (v : uint128) =
  Cstruct.LE.set_uint64 buf off v.lo;
  Cstruct.LE.set_uint64 buf (off + 8) v.hi

let get_uint128 buf off : uint128 =
  let lo = Cstruct.LE.get_uint64 buf off in
  let hi = Cstruct.LE.get_uint64 buf (off + 8) in
  { hi; lo }

(* --- id helpers ---------------------------------------------------------- *)

let put_id buf off id =
  put_uint128 buf off (id_to_uint128 id)

let get_id buf off =
  let v = get_uint128 buf off in
  id_of_uint128 v

(* --- Account encoding ---------------------------------------------------- *)
(* Layout (128 bytes):
   0   : id (16)
   16  : debits_pending (16)
   32  : debits_posted (16)
   48  : credits_pending (16)
   64  : credits_posted (16)
   80  : user_data_128 (16)
   96  : user_data_64 (8)
   104 : user_data_32 (4)
   108 : reserved (4)
   112 : ledger (4)
   116 : code (2)
   118 : flags (2)
   120 : timestamp (8) *)

let encode_account buf off (a : account) =
  put_id buf off a.id;
  put_uint128 buf (off + 16) a.debits_pending;
  put_uint128 buf (off + 32) a.debits_posted;
  put_uint128 buf (off + 48) a.credits_pending;
  put_uint128 buf (off + 64) a.credits_posted;
  put_uint128 buf (off + 80) a.user_data_128;
  Cstruct.LE.set_uint64 buf (off + 96) a.user_data_64;
  Cstruct.LE.set_uint32 buf (off + 104) a.user_data_32;
  Cstruct.LE.set_uint32 buf (off + 108) (Int32.of_int a.reserved);
  Cstruct.LE.set_uint32 buf (off + 112) (ledger_to_int32 a.ledger);
  Cstruct.LE.set_uint16 buf (off + 116) (code_to_int a.code);
  Cstruct.LE.set_uint16 buf (off + 118) (account_flags_to_int a.flags);
  Cstruct.LE.set_uint64 buf (off + 120) a.timestamp

let decode_account buf off : (account, string) result =
  match get_id buf off with
  | Error e -> Error e
  | Ok id ->
    let ledger_raw = Cstruct.LE.get_uint32 buf (off + 112) in
    (match ledger_of_int32 ledger_raw with
     | Error e -> Error e
     | Ok ledger ->
       let code_raw = Cstruct.LE.get_uint16 buf (off + 116) in
       (match code_of_int code_raw with
        | Error e -> Error e
        | Ok code ->
          Ok
            {
              id;
              debits_pending = get_uint128 buf (off + 16);
              debits_posted = get_uint128 buf (off + 32);
              credits_pending = get_uint128 buf (off + 48);
              credits_posted = get_uint128 buf (off + 64);
              user_data_128 = get_uint128 buf (off + 80);
              user_data_64 = Cstruct.LE.get_uint64 buf (off + 96);
              user_data_32 = Cstruct.LE.get_uint32 buf (off + 104);
              reserved = Int32.to_int (Cstruct.LE.get_uint32 buf (off + 108));
              ledger;
              code;
              flags = account_flags_of_int (Cstruct.LE.get_uint16 buf (off + 118));
              timestamp = Cstruct.LE.get_uint64 buf (off + 120);
            }))

(* --- Transfer encoding --------------------------------------------------- *)
(* Layout (128 bytes):
   0   : id (16)
   16  : debit_account_id (16)
   32  : credit_account_id (16)
   48  : amount (16)
   64  : pending_id (16)
   80  : user_data_128 (16)
   96  : user_data_64 (8)
   104 : user_data_32 (4)
   108 : timeout (4)
   112 : ledger (4)
   116 : code (2)
   118 : flags (2)
   120 : timestamp (8) *)

let encode_transfer buf off (t : transfer) =
  put_id buf off t.id;
  put_id buf (off + 16) t.debit_account_id;
  put_id buf (off + 32) t.credit_account_id;
  put_uint128 buf (off + 48) t.amount;
  put_uint128 buf (off + 64) t.pending_id;
  put_uint128 buf (off + 80) t.user_data_128;
  Cstruct.LE.set_uint64 buf (off + 96) t.user_data_64;
  Cstruct.LE.set_uint32 buf (off + 104) t.user_data_32;
  Cstruct.LE.set_uint32 buf (off + 108) t.timeout;
  Cstruct.LE.set_uint32 buf (off + 112) (ledger_to_int32 t.ledger);
  Cstruct.LE.set_uint16 buf (off + 116) (code_to_int t.code);
  Cstruct.LE.set_uint16 buf (off + 118) (transfer_flags_to_int t.flags);
  Cstruct.LE.set_uint64 buf (off + 120) t.timestamp

let decode_transfer buf off : (transfer, string) result =
  match get_id buf off, get_id buf (off + 16), get_id buf (off + 32) with
  | Ok id, Ok debit_account_id, Ok credit_account_id ->
    let ledger_raw = Cstruct.LE.get_uint32 buf (off + 112) in
    (match ledger_of_int32 ledger_raw with
     | Error e -> Error e
     | Ok ledger ->
       let code_raw = Cstruct.LE.get_uint16 buf (off + 116) in
       (match code_of_int code_raw with
        | Error e -> Error e
        | Ok code ->
          Ok
            {
              id;
              debit_account_id;
              credit_account_id;
              amount = get_uint128 buf (off + 48);
              pending_id = get_uint128 buf (off + 64);
              user_data_128 = get_uint128 buf (off + 80);
              user_data_64 = Cstruct.LE.get_uint64 buf (off + 96);
              user_data_32 = Cstruct.LE.get_uint32 buf (off + 104);
              timeout = Cstruct.LE.get_uint32 buf (off + 108);
              ledger;
              code;
              flags =
                transfer_flags_of_int (Cstruct.LE.get_uint16 buf (off + 118));
              timestamp = Cstruct.LE.get_uint64 buf (off + 120);
            }))
  | Error e, _, _ | _, Error e, _ | _, _, Error e -> Error e

(* --- Filter encoding ----------------------------------------------------- *)

(* account_filter: 36 bytes
   0  : account_id (16)
   16 : timestamp_min (8)
   24 : timestamp_max (8)
   32 : limit (4)
   (we omit the flags field for simplicity -- store in last 4 bytes)
   Actually let's be consistent:
   32 : limit (4)
   No room for flags in 36 easily, let's use 40 bytes *)

(* Correction: let's use a clean layout:
   account_filter_wire_size = 40
   0  : account_id (16)
   16 : timestamp_min (8)
   24 : timestamp_max (8)
   32 : limit (4)
   36 : flags (4) *)

let account_filter_wire_size = 40

let encode_account_filter buf off (f : account_filter) =
  put_id buf off f.account_id;
  Cstruct.LE.set_uint64 buf (off + 16) f.timestamp_min;
  Cstruct.LE.set_uint64 buf (off + 24) f.timestamp_max;
  Cstruct.LE.set_uint32 buf (off + 32) f.limit;
  Cstruct.LE.set_uint32 buf (off + 36) f.flags

let decode_account_filter buf off : (account_filter, string) result =
  match get_id buf off with
  | Error e -> Error e
  | Ok account_id ->
    Ok
      {
        account_id;
        timestamp_min = Cstruct.LE.get_uint64 buf (off + 16);
        timestamp_max = Cstruct.LE.get_uint64 buf (off + 24);
        limit = Cstruct.LE.get_uint32 buf (off + 32);
        flags = Cstruct.LE.get_uint32 buf (off + 36);
      }

(* query_filter: 56 bytes
   0  : user_data_128 (16)
   16 : user_data_64 (8)
   24 : user_data_32 (4)
   28 : ledger (4)
   32 : code (2)
   34 : padding (2)
   36 : timestamp_min (8)
   44 : timestamp_max (8)
   52 : limit (4)
   (we need flags too, so 60 bytes) *)

let query_filter_wire_size = 60

let encode_query_filter buf off (f : query_filter) =
  put_uint128 buf off f.user_data_128;
  Cstruct.LE.set_uint64 buf (off + 16) f.user_data_64;
  Cstruct.LE.set_uint32 buf (off + 24) f.user_data_32;
  Cstruct.LE.set_uint32 buf (off + 28) f.ledger;
  Cstruct.LE.set_uint16 buf (off + 32) f.code;
  Cstruct.LE.set_uint16 buf (off + 34) 0;
  (* padding *)
  Cstruct.LE.set_uint64 buf (off + 36) f.timestamp_min;
  Cstruct.LE.set_uint64 buf (off + 44) f.timestamp_max;
  Cstruct.LE.set_uint32 buf (off + 52) f.limit;
  Cstruct.LE.set_uint32 buf (off + 56) f.flags

let decode_query_filter buf off : query_filter =
  {
    user_data_128 = get_uint128 buf off;
    user_data_64 = Cstruct.LE.get_uint64 buf (off + 16);
    user_data_32 = Cstruct.LE.get_uint32 buf (off + 24);
    ledger = Cstruct.LE.get_uint32 buf (off + 28);
    code = Cstruct.LE.get_uint16 buf (off + 32);
    timestamp_min = Cstruct.LE.get_uint64 buf (off + 36);
    timestamp_max = Cstruct.LE.get_uint64 buf (off + 44);
    limit = Cstruct.LE.get_uint32 buf (off + 52);
    flags = Cstruct.LE.get_uint32 buf (off + 56);
  }

(* --- Encode list helper -------------------------------------------------- *)

let encode_list items item_size encode_fn =
  let n = List.length items in
  let buf = Cstruct.create (n * item_size) in
  Cstruct.memset buf 0;
  List.iteri (fun i item -> encode_fn buf (i * item_size) item) items;
  buf

let decode_list buf item_size decode_fn =
  let len = Cstruct.length buf in
  if len mod item_size <> 0 then Error "payload size not aligned to item size"
  else begin
    let n = len / item_size in
    let rec aux acc i =
      if i < 0 then Ok (List.rev acc)
      else
        match decode_fn buf (i * item_size) with
        | Ok item -> aux (item :: acc) (i - 1)
        | Error e -> Error (Printf.sprintf "item %d: %s" i e)
    in
    aux [] (n - 1)
  end

(* --- Encode / decode request --------------------------------------------- *)

let encode_request (req : request) : Cstruct.t =
  match req with
  | Req_create_accounts accounts ->
    encode_list accounts account_wire_size encode_account
  | Req_create_transfers transfers ->
    encode_list transfers transfer_wire_size encode_transfer
  | Req_lookup_accounts ids ->
    encode_list ids id_wire_size (fun buf off id -> put_id buf off id)
  | Req_lookup_transfers ids ->
    encode_list ids id_wire_size (fun buf off id -> put_id buf off id)
  | Req_get_account_transfers f ->
    let buf = Cstruct.create account_filter_wire_size in
    Cstruct.memset buf 0;
    encode_account_filter buf 0 f;
    buf
  | Req_get_account_balances f ->
    let buf = Cstruct.create account_filter_wire_size in
    Cstruct.memset buf 0;
    encode_account_filter buf 0 f;
    buf
  | Req_query_accounts f ->
    let buf = Cstruct.create query_filter_wire_size in
    Cstruct.memset buf 0;
    encode_query_filter buf 0 f;
    buf
  | Req_query_transfers f ->
    let buf = Cstruct.create query_filter_wire_size in
    Cstruct.memset buf 0;
    encode_query_filter buf 0 f;
    buf

let decode_id_list buf =
  let len = Cstruct.length buf in
  if len mod id_wire_size <> 0 then
    Error "payload size not aligned to id size"
  else begin
    let n = len / id_wire_size in
    let rec aux acc i =
      if i < 0 then Ok (List.rev acc)
      else
        match get_id buf (i * id_wire_size) with
        | Ok id -> aux (id :: acc) (i - 1)
        | Error e -> Error (Printf.sprintf "id %d: %s" i e)
    in
    aux [] (n - 1)
  end

let decode_request (cmd : command) (buf : Cstruct.t) :
    (request, string) result =
  match cmd with
  | Create_accounts ->
    (match decode_list buf account_wire_size decode_account with
     | Ok accounts -> Ok (Req_create_accounts accounts)
     | Error e -> Error e)
  | Create_transfers ->
    (match decode_list buf transfer_wire_size decode_transfer with
     | Ok transfers -> Ok (Req_create_transfers transfers)
     | Error e -> Error e)
  | Lookup_accounts ->
    (match decode_id_list buf with
     | Ok ids -> Ok (Req_lookup_accounts ids)
     | Error e -> Error e)
  | Lookup_transfers ->
    (match decode_id_list buf with
     | Ok ids -> Ok (Req_lookup_transfers ids)
     | Error e -> Error e)
  | Get_account_transfers ->
    if Cstruct.length buf <> account_filter_wire_size then
      Error "invalid account_filter size"
    else
      (match decode_account_filter buf 0 with
       | Ok f -> Ok (Req_get_account_transfers f)
       | Error e -> Error e)
  | Get_account_balances ->
    if Cstruct.length buf <> account_filter_wire_size then
      Error "invalid account_filter size"
    else
      (match decode_account_filter buf 0 with
       | Ok f -> Ok (Req_get_account_balances f)
       | Error e -> Error e)
  | Query_accounts ->
    if Cstruct.length buf <> query_filter_wire_size then
      Error "invalid query_filter size"
    else Ok (Req_query_accounts (decode_query_filter buf 0))
  | Query_transfers ->
    if Cstruct.length buf <> query_filter_wire_size then
      Error "invalid query_filter size"
    else Ok (Req_query_transfers (decode_query_filter buf 0))
