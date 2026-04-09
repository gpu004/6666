(** TigerBeetle-compatible multibatch payload encoding.

    The key invariant is that the trailer fully describes how the payload is
    partitioned into batches, so malformed payloads fail fast on decode. *)

val trailer_total_size : element_size:int -> batch_count:int -> int

(** Decode a multibatch payload into its original batch slices.

    Example:

    {[
      let payload =
        Multibatch.encode ~element_size:16
          [ Bytes.of_string "abcdefghijklmnop" ]

      let decoded = Multibatch.decode ~element_size:16 payload
    ]}

    This mirrors the round-trip tests in [tests/unit_tests.ml] and
    [tests/property_tests.ml]. *)

val decode : element_size:int -> bytes -> bytes list

(** Encode already-split batches into one payload.

    Each batch is expected to be aligned to [element_size]. *)

val encode : element_size:int -> bytes list -> bytes
