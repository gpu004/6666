(* header.ml — 256-byte message header for TigerOCaml wire format *)

let header_size = 256
let message_size_max = 1024 * 1024 (* 1 MiB for MVP *)
let protocol_version = 1

(* Field offsets *)
let off_header_checksum = 0
let off_body_checksum = 32
let off_cluster_id = 64
let off_size = 68
let off_protocol_version = 72
let off_command = 74
let off_reserved_1 = 76
let off_reserved_pad = 80
let reserved_pad_len = header_size - off_reserved_pad (* 176 bytes *)

type t = {
  cluster_id : int32;
  command : Tiger_core.Requests.command;
  body_size : int;
}

let encode (h : t) ~(body : Cstruct.t) : Cstruct.t =
  let body_len = Cstruct.length body in
  let total_size = header_size + body_len in
  let buf = Cstruct.create header_size in
  (* Zero-fill the entire header first (ensures reserved fields are 0) *)
  Cstruct.memset buf 0;
  (* Write body checksum *)
  let body_cksum = Checksum.compute body in
  Cstruct.blit_from_bytes body_cksum 0 buf off_body_checksum
    Checksum.checksum_size;
  (* Write fields *)
  Cstruct.LE.set_uint32 buf off_cluster_id h.cluster_id;
  Cstruct.LE.set_uint32 buf off_size (Int32.of_int total_size);
  Cstruct.LE.set_uint16 buf off_protocol_version protocol_version;
  Cstruct.LE.set_uint16 buf off_command
    (Tiger_core.Requests.command_to_int h.command);
  (* Compute header checksum over bytes 32..255 *)
  let header_rest = Cstruct.sub buf 32 (header_size - 32) in
  let hdr_cksum = Checksum.compute header_rest in
  Cstruct.blit_from_bytes hdr_cksum 0 buf off_header_checksum
    Checksum.checksum_size;
  buf

let decode (buf : Cstruct.t) : (t, string) result =
  if Cstruct.length buf < header_size then Error "header too short"
  else begin
    (* Verify header checksum *)
    let stored_cksum =
      Cstruct.to_bytes ~off:off_header_checksum ~len:Checksum.checksum_size buf
    in
    let header_rest = Cstruct.sub buf 32 (header_size - 32) in
    if not (Checksum.verify ~expected:stored_cksum header_rest) then
      Error "header checksum mismatch"
    else begin
      (* Check protocol version *)
      let pv = Cstruct.LE.get_uint16 buf off_protocol_version in
      if pv <> protocol_version then
        Error (Printf.sprintf "unsupported protocol version %d" pv)
      else begin
        (* Check command *)
        let cmd_int = Cstruct.LE.get_uint16 buf off_command in
        match Tiger_core.Requests.command_of_int cmd_int with
        | None -> Error (Printf.sprintf "unknown command %d" cmd_int)
        | Some command -> begin
            (* Check reserved fields *)
            let r1 = Cstruct.LE.get_uint32 buf off_reserved_1 in
            if not (Int32.equal r1 0l) then Error "reserved_1 must be zero"
            else begin
              (* Check reserved pad is all zeros *)
              let pad = Cstruct.sub buf off_reserved_pad reserved_pad_len in
              let pad_ok = ref true in
              for i = 0 to reserved_pad_len - 1 do
                if Cstruct.get_uint8 pad i <> 0 then pad_ok := false
              done;
              if not !pad_ok then Error "reserved padding must be zero"
              else begin
                (* Check size *)
                let total_size =
                  Int32.to_int (Cstruct.LE.get_uint32 buf off_size)
                in
                if total_size < header_size then Error "size < header_size"
                else if total_size > message_size_max then
                  Error "message exceeds maximum size"
                else begin
                  let body_size = total_size - header_size in
                  let cluster_id = Cstruct.LE.get_uint32 buf off_cluster_id in
                  Ok { cluster_id; command; body_size }
                end
              end
            end
          end
      end
    end
  end

let body_checksum (buf : Cstruct.t) : bytes =
  Cstruct.to_bytes ~off:off_body_checksum ~len:Checksum.checksum_size buf

let validate_body ~(header_buf : Cstruct.t) ~(body : Cstruct.t) : bool =
  let expected = body_checksum header_buf in
  Checksum.verify ~expected body
