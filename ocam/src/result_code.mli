(** Numeric encoding of create statuses.

    Codes follow the [CreateAccountStatus] and [CreateTransferStatus] enums of the
    pinned TigerBeetle revision. Some OCaml statuses are coarser than upstream and
    stand for several upstream codes; those have no single [to_code] value and are
    listed by [*_codes] instead. Upstream codes with no OCaml counterpart
    ([deprecated_ok], [reserved_field], [reserved_flag], [deprecated_18],
    [imported_event_timestamp_must_postdate_*]) decode to [None]. *)

open Types

(** The [created] code, [maxInt(u32)]. *)
val created_code : int

(** The exact upstream code for a status, or [None] for a coarse status. *)
val account_to_code : create_account_status -> int option

(** Every upstream code an OCaml status stands for. *)
val account_codes : create_account_status -> int list

(** The OCaml status for an upstream code. *)
val account_of_code : int -> create_account_status option

val transfer_to_code : create_transfer_status -> int option
val transfer_codes : create_transfer_status -> int list
val transfer_of_code : int -> create_transfer_status option

(** All statuses, in upstream declaration order. *)
val account_statuses : create_account_status list

val transfer_statuses : create_transfer_status list

(** Whether retrying an identical request can produce a different outcome. *)
val transfer_status_transient : create_transfer_status -> bool
