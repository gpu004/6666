(** Binary codecs for the compatibility protocol.

    This module is the boundary between typed OCaml values and the raw
    wire-format used by the prototype client/server surface. *)

open Types

type request_header = {
  checksum : U128.t;
  cluster : U128.t;
  size : int;
  release : int32;
  command : int;
  client : U128.t;
  session : int64;
  timestamp : int64;
  request : int32;
  operation : int;
}

type reply_header = { size : int; operation : int; timestamp : int64 }

val get_i32 : bytes -> int -> int32
val get_i64 : bytes -> int -> int64
val set_u8 : bytes -> int -> int -> unit
val set_i32 : bytes -> int -> int32 -> unit
val set_i64 : bytes -> int -> int64 -> unit
val set_u128 : bytes -> int -> U128.t -> unit
val parse_request_header : bytes -> request_header
val parse_reply_header : bytes -> reply_header
val decode_account : bytes -> int -> account
val encode_account : account -> bytes
val decode_transfer : bytes -> int -> transfer
val encode_transfer : transfer -> bytes
val decode_id_batch : bytes -> U128.t list
val encode_id : U128.t -> bytes
val decode_account_filter : bytes -> account_filter
val decode_query_filter : bytes -> query_filter
val encode_account_balance : account_balance -> bytes
val encode_account_filter : account_filter -> bytes
val encode_query_filter : query_filter -> bytes
val encode_create_results : create_result list -> bytes

(** Encode only non-success account creation results into the sparse error
    format used by older clients.

    Example:

    {[
      let body =
        Codec.encode_create_account_errors
          [
            { Types.timestamp = 1L; status = Types.create_account_created };
            { Types.timestamp = 2L; status = Types.create_account_exists };
          ]
    ]}

    This mirrors the assertion in [tests/unit_tests.ml]. *)

val encode_create_account_errors : create_result list -> bytes
val encode_create_transfer_errors : create_result list -> bytes
val encode_accounts : account list -> bytes
val encode_transfers : transfer list -> bytes
val encode_balances : account_balance list -> bytes
val encode_register_result : unit -> bytes

(** Construct a full reply message, including header checksums. *)

val make_reply :
  request_header:request_header ->
  body:bytes ->
  commit:int64 ->
  timestamp:int64 ->
  operation:int ->
  context:U128.t ->
  bytes
