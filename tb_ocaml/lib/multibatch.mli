val trailer_total_size : element_size:int -> batch_count:int -> int
val decode : element_size:int -> bytes -> bytes list
val encode : element_size:int -> bytes list -> bytes
