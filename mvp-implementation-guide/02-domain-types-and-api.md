# Step 02 - Domain types and API surface

Goal: Define all core types and invariants in OCaml before any persistence or
networking is implemented.

## Deliverables
- Domain types module with abstract constructors
- Request and response types
- Error/result enum types
- API contract documentation
- Explicit field constraints that match TigerBeetle semantics

## Files to create
- `src/core/types.mli`
- `src/core/types.ml`
- `src/core/errors.mli`
- `src/core/errors.ml`
- `src/core/requests.mli`
- `src/core/requests.ml`
- `docs/api.md`

## Tasks
1. Define primitive wrappers (abstract types)
   - In `types.mli` define opaque types:
     - `type account_id`
     - `type transfer_id`
     - `type ledger_id`
     - `type amount`
     - `type timestamp`
   - Provide constructors returning `('a, error) result`.
   - Enforce TigerBeetle id rules: `id` must not be `0` or `2^128 - 1`.

2. Define Account and Transfer records
   - In `types.ml`:
     - `type account = { id; ledger; code; flags; user_data_128; user_data_64; user_data_32;
                          reserved; debits_posted; credits_posted; debits_pending; credits_pending;
                          timestamp }`
     - `type transfer = { id; debit_account_id; credit_account_id; amount; ledger; code; flags;
                           pending_id; user_data_128; user_data_64; user_data_32; timeout; timestamp }`
   - Keep fields immutable except balance fields, matching TigerBeetle semantics.

3. Define flags as bitfields
   - `type account_flags = { linked: bool; debits_must_not_exceed_credits: bool; credits_must_not_exceed_debits: bool;
                             history: bool; imported: bool; closed: bool }`
   - `type transfer_flags = { linked: bool; pending: bool; post_pending_transfer: bool; void_pending_transfer: bool;
                              balancing_debit: bool; balancing_credit: bool;
                              closing_debit: bool; closing_credit: bool; imported: bool }`
   - Provide functions to convert to and from integer bitmask.
   - Enforce mutual exclusivity rules from TigerBeetle reference docs.

4. Define errors and result codes
   - In `errors.ml` define:
     - `type result_code = Ok | Exists | Not_found | Ledger_mismatch | Insufficient_funds | Invalid_flags
                         | Invalid_amount | Invalid_id | Invalid_ledger | Invalid_code | Invalid_timestamp
                         | Invalid_pending_id | Account_closed | Exceeds_credits | Exceeds_debits | ...`
   - Map these to integers for wire format.

5. Define request and response types
   - In `requests.ml`:
     - `type create_accounts = account list`
     - `type create_transfers = transfer list`
     - `type lookup_accounts = account_id list`
     - `type lookup_transfers = transfer_id list`
     - `type get_account_transfers = account_filter` and `type get_account_balances = account_filter`
     - `type query_accounts = account_filter` and `type query_transfers = transfer_filter`
     - `type request =
         | Create_accounts of create_accounts
         | Create_transfers of create_transfers
         | Lookup_accounts of lookup_accounts
         | Lookup_transfers of lookup_transfers
         | Get_account_transfers of get_account_transfers
         | Get_account_balances of get_account_balances
         | Query_accounts of query_accounts
         | Query_transfers of query_transfers`
     - `type response = { results: result_code list; payload: bytes option }`
   - Define `account_filter` and `transfer_filter` to mirror TigerBeetle query filters.
   - Include range fields for `timestamp`, `user_data_*`, and `ledger`, plus `limit` and `offset` where applicable.

6. Document API contract
   - `docs/api.md` should specify:
     - batch size limits (8189 for most requests; queries are request size 1 but return up to 8189)
     - idempotency rules and `exists` semantics
     - timestamp ownership and imported semantics
     - linked event behavior (atomic chains)
     - error code meanings

## Example type snippet (for reference)
```ocaml
type amount
val amount_of_int64 : int64 -> (amount, error) result
```

## Checklists
- [ ] No invalid records can be constructed without passing validators
- [ ] Errors are explicit and mapped to stable codes
- [ ] API doc exists and matches types
- [ ] All TigerBeetle flag and field constraints are captured in types or validators

## Notes
OCaml types are your primary safety tool here. Use modules and signatures to
prevent construction of invalid values.
