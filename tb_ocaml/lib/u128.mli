(** Unsigned 128-bit integers used for ids, amounts, and checksums.

    The representation is abstract so callers cannot construct values by
    reaching into internal limbs directly. *)

type t

val zero : t
val one : t
val max_value : t
val equal : t -> t -> bool
val compare : t -> t -> int
val is_zero : t -> bool
val of_int : int -> t
val of_int64 : int64 -> t

(** Parse a base-10 string into a {!t}.

    Example:

    {[
      let cluster = U128.of_decimal_string "42"
    ]}

    This mirrors the round-trip checks in [tests/property_tests.ml]. *)

val of_decimal_string : string -> t
val of_le_bytes : bytes -> int -> t
val add : t -> t -> t
val sub : t -> t -> t
val to_string : t -> string
val to_le_bytes : t -> bytes
val pp : Format.formatter -> t -> unit
