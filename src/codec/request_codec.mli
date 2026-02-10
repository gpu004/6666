(** Binary encoding/decoding for request payloads. *)

open Tiger_core.Requests

val encode_request : request -> Cstruct.t
(** Encode a request into a binary payload (without header). *)

val decode_request :
  command -> Cstruct.t -> (request, string) result
(** Decode a binary payload into a request given the command from the header. *)

(** {1 Wire sizes} *)

val account_wire_size : int
(** 128 bytes *)

val transfer_wire_size : int
(** 128 bytes *)

val id_wire_size : int
(** 16 bytes *)

val account_filter_wire_size : int
val query_filter_wire_size : int
