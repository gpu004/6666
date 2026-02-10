(** Binary encoding/decoding for response payloads and frames. *)

open Tiger_core.Requests

val create_result_wire_size : int
val account_balance_wire_size : int
val change_event_wire_size : int

val encode_payload : response -> Cstruct.t
(** Encode a response payload (without header). *)

val decode_payload : command -> Cstruct.t -> (response, string) result
(** Decode a response payload given the command from the header. *)

val encode_response : response -> Cstruct.t
(** Encode a full response frame (header + payload). *)

val decode_response : Cstruct.t -> (response, string) result
(** Decode and validate a full response frame (header + payload). *)
