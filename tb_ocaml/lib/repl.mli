(** Text REPL parsing and rendering for the prototype CLI.

    Pure parsing helpers are exposed so the CLI grammar can be tested directly,
    while network I/O stays behind {!run}. *)

open Types

type statement =
  | CreateAccounts of account list
  | CreateTransfers of transfer list
  | LookupAccounts of U128.t list
  | LookupTransfers of U128.t list
  | QueryAccounts of query_filter
  | QueryTransfers of query_filter
  | GetAccountTransfers of account_filter
  | GetAccountBalances of account_filter

val parse_command : string -> statement
(** Parse one REPL command string into a typed statement.

    Example:

    {[
      let statement = Repl.parse_command "create_accounts id=1 code=10 ledger=1"
    ]}

    This mirrors the parser unit tests in [tests/unit_tests.ml]. *)

val run : cluster:U128.t -> address:string -> command:string -> unit
(** Execute one REPL command against a running server instance. *)
