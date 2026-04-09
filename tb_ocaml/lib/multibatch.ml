let trailer_total_size ~element_size ~batch_count =
  if batch_count <= 0 then invalid_arg "MultiBatch.trailer_total_size";
  let trailer_unpadded_size = (batch_count * 2) + 2 in
  if element_size = 0 then trailer_unpadded_size
  else
    let blocks = (trailer_unpadded_size + element_size - 1) / element_size in
    blocks * element_size

let decode ~element_size body =
  let len = Bytes.length body in
  if len < 2 then invalid_arg "MultiBatch.decode";
  let read_u16 off =
    Char.code (Bytes.get body off)
    lor (Char.code (Bytes.get body (off + 1)) lsl 8)
  in
  let batch_count = read_u16 (len - 2) in
  if batch_count <= 0 || batch_count >= 0xFFFF then
    invalid_arg "MultiBatch.decode";
  let trailer_size = trailer_total_size ~element_size ~batch_count in
  if trailer_size > len then invalid_arg "MultiBatch.decode";
  let trailer_start = len - trailer_size in
  let total_items = (trailer_size - 2) / 2 in
  let padding_items = total_items - batch_count in
  for i = 0 to padding_items - 1 do
    let v = read_u16 (trailer_start + (i * 2)) in
    if v <> 0xFFFF then invalid_arg "MultiBatch.decode"
  done;
  let counts =
    Array.init batch_count (fun i ->
        read_u16 (trailer_start + ((padding_items + i) * 2)))
  in
  let payload_size =
    Array.fold_left (fun acc n -> acc + (n * element_size)) 0 counts
  in
  if payload_size <> trailer_start then invalid_arg "MultiBatch.decode";
  let cursor = ref 0 in
  Array.to_list
    (Array.map
       (fun count ->
         let bytes = count * element_size in
         let out = Bytes.sub body !cursor bytes in
         cursor := !cursor + bytes;
         out)
       counts)

let encode ~element_size batches =
  match batches with
  | [] -> invalid_arg "MultiBatch.encode"
  | _ ->
      let batch_count = List.length batches in
      let payload_size =
        List.fold_left (fun acc b -> acc + Bytes.length b) 0 batches
      in
      let trailer_size = trailer_total_size ~element_size ~batch_count in
      let total = payload_size + trailer_size in
      let out = Bytes.make total '\x00' in
      let cursor = ref 0 in
      List.iter
        (fun batch ->
          Bytes.blit batch 0 out !cursor (Bytes.length batch);
          cursor := !cursor + Bytes.length batch)
        batches;
      let trailer_start = payload_size in
      let total_items = (trailer_size - 2) / 2 in
      let padding_items = total_items - batch_count in
      let write_u16 off v =
        Bytes.set out off (Char.chr (v land 0xFF));
        Bytes.set out (off + 1) (Char.chr ((v lsr 8) land 0xFF))
      in
      for i = 0 to padding_items - 1 do
        write_u16 (trailer_start + (i * 2)) 0xFFFF
      done;
      List.iteri
        (fun i batch ->
          let count =
            if element_size = 0 then 0 else Bytes.length batch / element_size
          in
          write_u16 (trailer_start + ((padding_items + i) * 2)) count)
        batches;
      write_u16 (total - 2) batch_count;
      out
