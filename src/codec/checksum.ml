(* checksum.ml — SHA-256 based checksums for TigerOCaml *)

let hash_bytes (b : bytes) : bytes =
  let digest = Digestif.SHA256.digest_bytes b in
  Digestif.SHA256.to_raw_string digest |> Bytes.of_string

let hash_cstruct (cs : Cstruct.t) : bytes =
  let b = Cstruct.to_bytes cs in
  hash_bytes b

(** Compute a 32-byte checksum of a Cstruct region. *)
let compute (cs : Cstruct.t) : bytes = hash_cstruct cs

(** Verify that a 32-byte checksum matches the given data. *)
let verify ~(expected : bytes) (cs : Cstruct.t) : bool =
  let actual = hash_cstruct cs in
  Bytes.equal expected actual

let checksum_size = Digestif.SHA256.digest_size (* 32 bytes *)
