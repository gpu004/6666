(** Request and response types for TigerOCaml API. *)

open Types

type command =
  | Cmd_create_accounts
  | Cmd_create_transfers
  | Cmd_lookup_accounts
  | Cmd_lookup_transfers
  | Cmd_get_account_transfers
  | Cmd_get_account_balances
  | Cmd_query_accounts
  | Cmd_query_transfers
  | Cmd_get_change_events

val command_to_int : command -> int
val command_of_int : int -> command option
val command_to_string : command -> string

type create_accounts = account list
type create_transfers = transfer list
type lookup_accounts = u128 list
type lookup_transfers = u128 list
type get_account_transfers = account_filter
type get_account_balances = account_filter
type query_accounts = query_filter
type query_transfers = query_filter
type get_change_events = change_events_filter

type request =
  | Create_accounts of create_accounts
  | Create_transfers of create_transfers
  | Lookup_accounts of lookup_accounts
  | Lookup_transfers of lookup_transfers
  | Get_account_transfers of get_account_transfers
  | Get_account_balances of get_account_balances
  | Query_accounts of query_accounts
  | Query_transfers of query_transfers
  | Get_change_events of get_change_events

type response =
  | Create_accounts_result of create_accounts_result list
  | Create_transfers_result of create_transfers_result list
  | Lookup_accounts_result of account list
  | Lookup_transfers_result of transfer list
  | Get_account_transfers_result of transfer list
  | Get_account_balances_result of account_balance list
  | Query_accounts_result of account list
  | Query_transfers_result of transfer list
  | Get_change_events_result of change_event list

val request_command : request -> command
