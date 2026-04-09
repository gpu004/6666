(** Checksum helper process integration.

    This module keeps the external Zig-based checksum helper at the edge of the
    OCaml codebase so protocol code can stay pure over bytes.

    Prototype note: every call spawns an external process. That is acceptable
    for compatibility smoke tests, but it materially distorts any benchmark that
    treats this path as representative production architecture. *)

let helper_path () =
  match Sys.getenv_opt "TB_OCAML_CHECKSUM_BIN" with
  | Some path -> path
  | None -> failwith "TB_OCAML_CHECKSUM_BIN is not set"

let compute bytes =
  let cmd = helper_path () in
  let env = Unix.environment () in
  let cin, cout, cerr = Unix.open_process_args_full cmd [| cmd |] env in
  output_string cout (Bytes.unsafe_to_string bytes);
  close_out cout;
  let result = really_input_string cin 16 in
  let _stderr =
    let b = Buffer.create 128 in
    (try
       while true do
         Buffer.add_channel b cerr 1024
       done
     with End_of_file -> ());
    Buffer.contents b
  in
  let status = Unix.close_process_full (cin, cout, cerr) in
  if status = Unix.WEXITED 0 then
    U128.of_le_bytes (Bytes.unsafe_of_string result) 0
  else failwith "checksum helper failed"
