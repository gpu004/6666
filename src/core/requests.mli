(** Request and response types for TigerOCaml API.

    All API operations are batched. Each request variant carries a list of
    events or a single filter. *)

open Types

(** {1 Command identifiers} *)

type command =
  | Create_accounts
  | Create_transfers
  | Lookup_accounts
  | Lookup_transfers
  | Get_account_transfers
  | Get_account_balances
  | Query_accounts
  | Query_transfers

val command_to_int : command -> int
val command_of_int : int -> command option
val command_to_string : command -> string

(** {1 Request types} *)

type request =
  | Req_create_accounts of account list
  | Req_create_transfers of transfer list
  | Req_lookup_accounts of id list
  | Req_lookup_transfers of id list
  | Req_get_account_transfers of account_filter
  | Req_get_account_balances of account_filter
  | Req_query_accounts of query_filter
  | Req_query_transfers of query_filter

(** {1 Response types} *)

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

(** {1 Helpers} *)

val request_command : request -> command
