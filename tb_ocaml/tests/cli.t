  $ ../bin/tigerbeetle.exe --help
  TigerBeetle compatibility build (OCaml)
  
  Commands:
    tigerbeetle format --cluster=0 --replica=0 --replica-count=1 <path>
    tigerbeetle start --addresses=3000 <path>
    tigerbeetle repl --cluster=0 --addresses=3000 --command=<command>
    tigerbeetle inspect --help
    tigerbeetle version [--verbose]
  
  Examples:
    tigerbeetle repl --cluster=0 --addresses=3000 --command=create_accounts

  $ ../bin/tigerbeetle.exe inspect --help
  TigerBeetle inspect compatibility help
  
  Available commands:
    constants
    metrics
    superblock
    wal --slot=0
    replies --slot=0
    grid
    manifest
    tables --tree=transfers
    integrity

  $ ../bin/tigerbeetle.exe version
  TigerBeetle version 0.0.0-ocaml-compat

  $ ../bin/tigerbeetle.exe version --verbose
  TigerBeetle version 0.0.0-ocaml-compat
  process.backoff_min=10ms
  process.backoff_max=1000ms
  process.release=ocaml-compat

  $ db=$(mktemp -t tb_ocaml_cli.XXXXXX)
  $ ../bin/tigerbeetle.exe format --cluster=0 --replica=0 --replica-count=1 "$db"
  $ test -f "$db"
  $ rm -f "$db"

  $ ../bin/tigerbeetle.exe inspect constants
  Fatal error: exception Failure("unsupported inspect command in compatibility build")
  [2]
