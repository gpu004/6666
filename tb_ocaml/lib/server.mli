(** TCP server loop for the TigerBeetle-compatible wire protocol.

    The public API stays small on purpose: callers start a server against a data
    file and address list, and the internal request handling remains hidden. *)

val start : path:string -> addresses:string -> unit
(** Start serving requests for the given data file. *)
