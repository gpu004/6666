(** Binary encoding/decoding for request payloads. *)

open Tiger_core.Requests

val encode_payload : request -> Cstruct.t
(** Encode a request payload (without header). *)

val decode_payload :
  command -> Cstruct.t -> (request, string) result
(** Decode a request payload given the command from the header. *)

val encode_request : request -> Cstruct.t
(** Encode a full request frame (header + payload). *)

val decode_request : Cstruct.t -> (request, string) result
(** Decode and validate a full request frame (header + payload). *)

(** {1 Wire sizes} *)

val account_wire_size : int
(** 128 bytes *)

val transfer_wire_size : int
(** 128 bytes *)

val id_wire_size : int
(** 16 bytes *)

val account_filter_wire_size : int
val query_filter_wire_size : int
