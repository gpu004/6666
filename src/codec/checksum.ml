(* checksum.ml — deterministic checksum for MVP wire format.
   TigerBeetle uses AEGIS-128L MAC-as-checksum; MVP intentionally diverges and
   uses SHA-256 truncated to 128 bits for a fixed-width u128 checksum. *)

let checksum_size = 16

let compute (cs : Cstruct.t) : bytes =
  let raw =
    Cstruct.to_bytes cs |> Digestif.SHA256.digest_bytes
    |> Digestif.SHA256.to_raw_string |> Bytes.of_string
  in
  Bytes.sub raw 0 checksum_size

let verify ~(expected : bytes) (cs : Cstruct.t) : bool =
  Bytes.length expected = checksum_size && Bytes.equal expected (compute cs)
