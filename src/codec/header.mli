(** Message header for TigerOCaml wire format.

    The header is a fixed 256-byte structure at the front of every message.
    Layout (little-endian):

    {v
    Offset  Size  Field
    ------  ----  -----
      0      32   header_checksum  (SHA-256 over bytes 32..255)
     32      32   body_checksum    (SHA-256 over the payload)
     64       4   cluster_id       (uint32)
     68       4   size             (uint32, total message = header + body)
     72       2   protocol_version (uint16)
     74       2   command          (uint16, see Requests.command)
     76       4   reserved_1       (must be 0)
     80     176   reserved_pad     (must be all zeros)
    v}

    Total: 256 bytes. *)

val header_size : int
(** Always 256. *)

val message_size_max : int
(** Maximum total message size (header + body). *)

type t = {
  cluster_id : int32;
  command : Tiger_core.Requests.command;
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
