open Tiger_core

let header_size = 256
let message_size_max = 1024 * 1024
let protocol_version = 1

(* TigerBeetle-aligned field offsets. *)
let off_checksum = 0
let off_checksum_padding = 16
let off_checksum_body = 32
let off_checksum_body_padding = 48
let off_nonce_reserved = 64
let off_cluster = 80
let off_size = 96
let off_epoch = 100
let off_view = 104
let off_release = 108
let off_protocol = 112
let off_command = 114
let off_replica = 115
let off_reserved_frame = 116
let reserved_frame_len = 12
let off_reserved_command = 128
let reserved_command_len = 128

type t = {
  cluster : Types.u128;
  epoch : int32;
  view : int32;
  release : int32;
  protocol : int;
  command : Requests.command;
  replica : int;
  body_size : int;
}

let put_u128 buf off (v : Types.u128) =
  Cstruct.LE.set_uint64 buf off v.lo;
  Cstruct.LE.set_uint64 buf (off + 8) v.hi

let get_u128 buf off : Types.u128 =
  let lo = Cstruct.LE.get_uint64 buf off in
  let hi = Cstruct.LE.get_uint64 buf (off + 8) in
  { hi; lo }

let put_checksum_128 buf off sum =
  if Bytes.length sum <> Checksum.checksum_size then
    invalid_arg "checksum size mismatch";
  Cstruct.blit_from_bytes sum 0 buf off Checksum.checksum_size

let decode_checksum_128 buf off =
  Cstruct.to_bytes ~off ~len:Checksum.checksum_size buf

let validate_zeroed_region buf off len =
  let ok = ref true in
  for i = 0 to len - 1 do
    if Cstruct.get_uint8 buf (off + i) <> 0 then ok := false
  done;
  !ok

let encode (h : t) ~(body : Cstruct.t) : Cstruct.t =
  let body_len = Cstruct.length body in
  let total_size = header_size + body_len in
  if total_size > message_size_max then invalid_arg "message exceeds maximum size";
  let buf = Cstruct.create header_size in
  Cstruct.memset buf 0;
  put_checksum_128 buf off_checksum_body (Checksum.compute body);
  put_u128 buf off_cluster h.cluster;
  Cstruct.LE.set_uint32 buf off_size (Int32.of_int total_size);
  Cstruct.LE.set_uint32 buf off_epoch h.epoch;
  Cstruct.LE.set_uint32 buf off_view h.view;
  Cstruct.LE.set_uint32 buf off_release h.release;
  Cstruct.LE.set_uint16 buf off_protocol h.protocol;
  Cstruct.set_uint8 buf off_command (Requests.command_to_int h.command);
  Cstruct.set_uint8 buf off_replica h.replica;
  let checksum_input = Cstruct.sub buf off_checksum_padding (header_size - off_checksum_padding) in
  put_checksum_128 buf off_checksum (Checksum.compute checksum_input);
  buf

let decode (buf : Cstruct.t) : (t, string) result =
  if Cstruct.length buf < header_size then Error "header too short"
  else
    let stored_header_checksum = decode_checksum_128 buf off_checksum in
    let checksum_input = Cstruct.sub buf off_checksum_padding (header_size - off_checksum_padding) in
    if not (Checksum.verify ~expected:stored_header_checksum checksum_input) then
      Error "header checksum mismatch"
    else if not (validate_zeroed_region buf off_checksum_padding Checksum.checksum_size) then
      Error "checksum padding must be zero"
    else if not (validate_zeroed_region buf off_checksum_body_padding Checksum.checksum_size) then
      Error "body checksum padding must be zero"
    else if not (validate_zeroed_region buf off_nonce_reserved 16) then
      Error "nonce_reserved must be zero"
    else if not (validate_zeroed_region buf off_reserved_frame reserved_frame_len) then
      Error "reserved_frame must be zero"
    else if not (validate_zeroed_region buf off_reserved_command reserved_command_len) then
      Error "reserved_command must be zero"
    else
      let protocol = Cstruct.LE.get_uint16 buf off_protocol in
      if protocol <> protocol_version then
        Error (Printf.sprintf "unsupported protocol version %d" protocol)
      else
        let command_raw = Cstruct.get_uint8 buf off_command in
        match Requests.command_of_int command_raw with
        | None -> Error (Printf.sprintf "unknown command %d" command_raw)
        | Some command ->
          let total_size = Int32.to_int (Cstruct.LE.get_uint32 buf off_size) in
          if total_size < header_size then Error "size < header_size"
          else if total_size > message_size_max then Error "message exceeds maximum size"
          else
            let cluster = get_u128 buf off_cluster in
            let epoch = Cstruct.LE.get_uint32 buf off_epoch in
            let view = Cstruct.LE.get_uint32 buf off_view in
            let release = Cstruct.LE.get_uint32 buf off_release in
            let replica = Cstruct.get_uint8 buf off_replica in
            Ok
              {
                cluster;
                epoch;
                view;
                release;
                protocol;
                command;
                replica;
                body_size = total_size - header_size;
              }

let body_checksum (buf : Cstruct.t) : bytes = decode_checksum_128 buf off_checksum_body

let validate_body ~(header_buf : Cstruct.t) ~(body : Cstruct.t) : bool =
  Checksum.verify ~expected:(body_checksum header_buf) body
