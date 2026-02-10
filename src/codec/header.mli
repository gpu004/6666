(** TigerBeetle-aligned 256-byte message header.

    All fields are little-endian and fixed-width. Reserved/padding fields are
    zero unless explicitly defined by a command schema. *)

val header_size : int
(** Always 256. *)

val message_size_max : int
(** Maximum total message size (header + body). *)

type t = {
  cluster : Tiger_core.Types.u128;
  epoch : int32;
  view : int32;
  release : int32;
  protocol : int;
  command : Tiger_core.Requests.command;
  replica : int;
  body_size : int;
}
(** Decoded header. [body_size] = total size - header_size. *)

val encode : t -> body:Cstruct.t -> Cstruct.t
(** Encode a header for the given body. Computes both checksums. *)

val decode : Cstruct.t -> (t, string) result
(** Decode and validate a 256-byte header buffer.
    Checks: header checksum, reserved fields are zero, size bounds,
    known command, protocol version. Does NOT validate body checksum
    (caller must do that after reading the body). *)

val body_checksum : Cstruct.t -> bytes
(** Extract the body checksum from an already-read header buffer. *)

val validate_body : header_buf:Cstruct.t -> body:Cstruct.t -> bool
(** Verify that the body matches the body checksum stored in the header. *)
