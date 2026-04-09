type t

val zero : t
val one : t
val max_value : t
val equal : t -> t -> bool
val compare : t -> t -> int
val is_zero : t -> bool
val of_int : int -> t
val of_int64 : int64 -> t
val of_decimal_string : string -> t
val of_le_bytes : bytes -> int -> t
val add : t -> t -> t
val sub : t -> t -> t
val to_string : t -> string
val to_le_bytes : t -> bytes
val pp : Format.formatter -> t -> unit
