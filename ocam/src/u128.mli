(** An unsigned, fixed-width 128-bit value.

    Used for IDs and monetary amounts. Arithmetic reports overflow or underflow rather
    than wrapping. *)

type t

(** The value [0]. *)
val zero : t

(** The value [1]. *)
val one : t

(** The largest representable unsigned 128-bit value, [2^128 - 1]. *)
val max_value : t

(** [of_int n] converts non-negative [n], rejecting negative input. *)
val of_int : int -> t

(** [of_int64 w] interprets [w] as an unsigned 64-bit word. *)
val of_int64 : int64 -> t

(** Builds a value from its unsigned high and low 64-bit words. *)
val of_int64_pair : hi:int64 -> lo:int64 -> t

(** Returns the unsigned high and low 64-bit words. *)
val to_int64_pair : t -> int64 * int64

(** The low word when the value fits in 64 bits (interpreted unsigned). *)
val to_int64_opt : t -> int64 option

(** The value as a non-negative [int] when it fits. *)
val to_int_opt : t -> int option

(** Unsigned numeric comparison. *)
val compare : t -> t -> int

(** Unsigned numeric equality. *)
val equal : t -> t -> bool

(** [is_zero v] is [equal v zero]. *)
val is_zero : t -> bool

(** Hash consistent with [equal]. *)
val hash : t -> int

(** Adds two values, reporting [`Overflow] instead of wrapping. *)
val add : t -> t -> (t, [ `Overflow ]) result

(** Subtracts two values, reporting [`Underflow] when the result is negative. *)
val sub : t -> t -> (t, [ `Underflow ]) result

(** Multiplies two values, reporting [`Overflow] instead of wrapping. *)
val mul : t -> t -> (t, [ `Overflow ]) result

(** [div_rem a b] is [Ok (a / b, a mod b)], or [Error `Division_by_zero]. *)
val div_rem : t -> t -> (t * t, [ `Division_by_zero ]) result

(** The smaller of two unsigned values. *)
val min : t -> t -> t

(** The larger of two unsigned values. *)
val max : t -> t -> t

(** Logical shift left; bits shifted past position 127 are discarded. *)
val shift_left : t -> int -> t

(** Logical shift right. *)
val shift_right : t -> int -> t

val logor : t -> t -> t
val logand : t -> t -> t

(** Decimal representation. *)
val to_string : t -> string

(** Zero-padded 32-digit hexadecimal representation with a [0x] prefix. *)
val to_hex_string : t -> string

(** Parses a non-empty decimal string; [None] on malformed input or overflow. *)
val of_string_opt : string -> t option

(** Like [of_string_opt], raising [Invalid_argument] on failure. *)
val of_string : string -> t
