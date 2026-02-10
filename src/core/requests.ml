(* requests.ml — Request and response types for TigerOCaml API *)

open Types

(* --- Command identifiers ------------------------------------------------- *)

type command =
  | Create_accounts
  | Create_transfers
  | Lookup_accounts
  | Lookup_transfers
  | Get_account_transfers
  | Get_account_balances
  | Query_accounts
  | Query_transfers

let command_to_int = function
  | Create_accounts -> 1
  | Create_transfers -> 2
  | Lookup_accounts -> 3
  | Lookup_transfers -> 4
  | Get_account_transfers -> 5
  | Get_account_balances -> 6
  | Query_accounts -> 7
  | Query_transfers -> 8

let command_of_int = function
  | 1 -> Some Create_accounts
  | 2 -> Some Create_transfers
  | 3 -> Some Lookup_accounts
  | 4 -> Some Lookup_transfers
  | 5 -> Some Get_account_transfers
  | 6 -> Some Get_account_balances
  | 7 -> Some Query_accounts
  | 8 -> Some Query_transfers
  | _ -> None

let command_to_string = function
  | Create_accounts -> "create_accounts"
  | Create_transfers -> "create_transfers"
  | Lookup_accounts -> "lookup_accounts"
  | Lookup_transfers -> "lookup_transfers"
  | Get_account_transfers -> "get_account_transfers"
  | Get_account_balances -> "get_account_balances"
  | Query_accounts -> "query_accounts"
  | Query_transfers -> "query_transfers"

(* --- Request types ------------------------------------------------------- *)

type request =
  | Req_create_accounts of account list
  | Req_create_transfers of transfer list
  | Req_lookup_accounts of id list
  | Req_lookup_transfers of id list
  | Req_get_account_transfers of account_filter
  | Req_get_account_balances of account_filter
  | Req_query_accounts of query_filter
  | Req_query_transfers of query_filter

(* --- Response types ------------------------------------------------------ *)

type create_accounts_result = {
  index : int;
  result : Errors.create_account_result;
}

type create_transfers_result = {
  index : int;
  result : Errors.create_transfer_result;
}

type response =
  | Res_create_accounts of create_accounts_result list
  | Res_create_transfers of create_transfers_result list
  | Res_lookup_accounts of account list
  | Res_lookup_transfers of transfer list
  | Res_get_account_transfers of transfer list
  | Res_get_account_balances of account list
  | Res_query_accounts of account list
  | Res_query_transfers of transfer list

(* --- Helpers ------------------------------------------------------------- *)

let request_command = function
  | Req_create_accounts _ -> Create_accounts
  | Req_create_transfers _ -> Create_transfers
  | Req_lookup_accounts _ -> Lookup_accounts
  | Req_lookup_transfers _ -> Lookup_transfers
  | Req_get_account_transfers _ -> Get_account_transfers
  | Req_get_account_balances _ -> Get_account_balances
  | Req_query_accounts _ -> Query_accounts
  | Req_query_transfers _ -> Query_transfers
