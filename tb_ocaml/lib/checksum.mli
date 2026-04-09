(** Checksum helper process integration.

    This module isolates the external checksum helper behind a typed OCaml API
    so the rest of the codebase can treat checksums as pure values. *)

val compute : bytes -> U128.t
(** Compute the TigerBeetle wire checksum for the given bytes. *)
