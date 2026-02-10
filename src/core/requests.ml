(* requests.ml — Request and response types for TigerOCaml API *)

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

let command_to_int = function
  | Cmd_create_accounts -> 1
  | Cmd_create_transfers -> 2
  | Cmd_lookup_accounts -> 3
  | Cmd_lookup_transfers -> 4
  | Cmd_get_account_transfers -> 5
  | Cmd_get_account_balances -> 6
  | Cmd_query_accounts -> 7
  | Cmd_query_transfers -> 8
  | Cmd_get_change_events -> 9

let command_of_int = function
  | 1 -> Some Cmd_create_accounts
  | 2 -> Some Cmd_create_transfers
  | 3 -> Some Cmd_lookup_accounts
  | 4 -> Some Cmd_lookup_transfers
  | 5 -> Some Cmd_get_account_transfers
  | 6 -> Some Cmd_get_account_balances
  | 7 -> Some Cmd_query_accounts
  | 8 -> Some Cmd_query_transfers
  | 9 -> Some Cmd_get_change_events
  | _ -> None

let command_to_string = function
  | Cmd_create_accounts -> "create_accounts"
  | Cmd_create_transfers -> "create_transfers"
  | Cmd_lookup_accounts -> "lookup_accounts"
  | Cmd_lookup_transfers -> "lookup_transfers"
  | Cmd_get_account_transfers -> "get_account_transfers"
  | Cmd_get_account_balances -> "get_account_balances"
  | Cmd_query_accounts -> "query_accounts"
  | Cmd_query_transfers -> "query_transfers"
  | Cmd_get_change_events -> "get_change_events"

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

let request_command = function
  | Create_accounts _ -> Cmd_create_accounts
  | Create_transfers _ -> Cmd_create_transfers
  | Lookup_accounts _ -> Cmd_lookup_accounts
  | Lookup_transfers _ -> Cmd_lookup_transfers
  | Get_account_transfers _ -> Cmd_get_account_transfers
  | Get_account_balances _ -> Cmd_get_account_balances
  | Query_accounts _ -> Cmd_query_accounts
  | Query_transfers _ -> Cmd_query_transfers
  | Get_change_events _ -> Cmd_get_change_events
