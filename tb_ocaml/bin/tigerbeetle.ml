let usage () =
  print_endline "TigerBeetle compatibility build (OCaml)";
  print_endline "";
  print_endline "Commands:";
  print_endline
    "  tigerbeetle format --cluster=0 --replica=0 --replica-count=1 <path>";
  print_endline "  tigerbeetle start --addresses=3000 <path>";
  print_endline
    "  tigerbeetle repl --cluster=0 --addresses=3000 --command=<command>";
  print_endline "  tigerbeetle inspect --help";
  print_endline "  tigerbeetle version [--verbose]";
  print_endline "";
  print_endline "Examples:";
  print_endline
    "  tigerbeetle repl --cluster=0 --addresses=3000 --command=create_accounts"

let inspect_help () =
  print_endline "TigerBeetle inspect compatibility help";
  print_endline "";
  print_endline "Available commands:";
  print_endline "  constants";
  print_endline "  metrics";
  print_endline "  superblock";
  print_endline "  wal --slot=0";
  print_endline "  replies --slot=0";
  print_endline "  grid";
  print_endline "  manifest";
  print_endline "  tables --tree=transfers";
  print_endline "  integrity"

let version verbose =
  print_endline "TigerBeetle version 0.0.0-ocaml-compat";
  if verbose then (
    print_endline "process.backoff_min=10ms";
    print_endline "process.backoff_max=1000ms";
    print_endline "process.release=ocaml-compat")

let take_flag prefix args =
  List.find_map
    (fun arg ->
      if String.starts_with ~prefix arg then
        Some
          (String.sub arg (String.length prefix)
             (String.length arg - String.length prefix))
      else None)
    args

let require_flag prefix args =
  match take_flag prefix args with
  | Some v -> v
  | None -> failwith ("missing flag: " ^ prefix)

let positional args =
  List.filter (fun arg -> not (String.starts_with ~prefix:"--" arg)) args

let cluster_of_args args =
  match take_flag "--cluster=" args with
  | Some v -> U128.of_decimal_string v
  | None -> U128.zero

let run_format args =
  let cluster = cluster_of_args args in
  let path =
    match List.rev (positional args) with
    | path :: _ -> path
    | [] -> failwith "missing format path"
  in
  State.format ~path ~cluster

let run_start args =
  let addresses = require_flag "--addresses=" args in
  let path =
    match List.rev (positional args) with
    | path :: _ -> path
    | [] -> failwith "missing data file"
  in
  Server.start ~path ~addresses

let run_repl args =
  let cluster = cluster_of_args args in
  let addresses = require_flag "--addresses=" args in
  let command = require_flag "--command=" args in
  Repl.run ~cluster ~address:addresses ~command

let () =
  match Array.to_list Sys.argv with
  | _ :: ("--help" | "help") :: _ -> usage ()
  | _ :: "format" :: args -> run_format args
  | _ :: "start" :: args -> run_start args
  | _ :: "repl" :: args -> run_repl args
  | _ :: "inspect" :: args ->
      if List.exists (( = ) "--help") args then inspect_help ()
      else failwith "unsupported inspect command in compatibility build"
  | _ :: "version" :: args -> version (List.exists (( = ) "--verbose") args)
  | _ ->
      usage ();
      exit 1
