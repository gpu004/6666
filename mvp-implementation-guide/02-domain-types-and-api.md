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

2. Define Account record (128 bytes on wire, field order matters)
   - In `types.ml` — field order must match TigerBeetle binary layout exactly:
     - `type account = { id: u128; debits_pending: u128; debits_posted: u128;
                          credits_pending: u128; credits_posted: u128;
                          user_data_128: u128; user_data_64: u64; user_data_32: u32;
                          reserved: u32; ledger: u32; code: u16; flags: account_flags;
                          timestamp: u64 }`
   - Total size: 128 bytes, no padding.
   - Keep fields immutable except balance fields, matching TigerBeetle semantics.

3. Define Transfer record (128 bytes on wire, field order matters)
   - `type transfer = { id: u128; debit_account_id: u128; credit_account_id: u128;
                         amount: u128; pending_id: u128;
                         user_data_128: u128; user_data_64: u64; user_data_32: u32;
                         timeout: u32; ledger: u32; code: u16; flags: transfer_flags;
                         timestamp: u64 }`
   - Total size: 128 bytes, no padding.

4. Define AccountBalance record (128 bytes on wire)
   - `type account_balance = { debits_pending: u128; debits_posted: u128;
                                credits_pending: u128; credits_posted: u128;
                                timestamp: u64; reserved: bytes (* 56 bytes *) }`
   - This is the result type for `get_account_balances`.

5. Define flags as bitfields
   - `type account_flags = { linked: bool; debits_must_not_exceed_credits: bool;
                              credits_must_not_exceed_debits: bool;
                              history: bool; imported: bool; closed: bool;
                              padding: u10 (* must be zero *) }`
   - `type transfer_flags = { linked: bool; pending: bool; post_pending_transfer: bool;
                               void_pending_transfer: bool;
                               balancing_debit: bool; balancing_credit: bool;
                               closing_debit: bool; closing_credit: bool;
                               imported: bool; padding: u7 (* must be zero *) }`
   - Provide functions to convert to and from u16 bitmask.
   - Enforce mutual exclusivity rules from TigerBeetle reference docs.

6. Define TransferPendingStatus
   - `type transfer_pending_status = None | Pending | Posted | Voided | Expired`
   - Maps to u8 values 0–4.

7. Define errors and result codes
   - In `errors.ml` define — **every variant must match TigerBeetle exactly**:
   - `type create_account_result =`
     - `| Ok (* 0 *)`
     - `| Linked_event_failed (* 1 *)`
     - `| Linked_event_chain_open (* 2 *)`
     - `| Timestamp_must_be_zero (* 3 *)`
     - `| Reserved_field (* 4 *)`
     - `| Reserved_flag (* 5 *)`
     - `| Id_must_not_be_zero (* 6 *)`
     - `| Id_must_not_be_int_max (* 7 *)`
     - `| Flags_are_mutually_exclusive (* 8 *)`
     - `| Debits_pending_must_be_zero (* 9 *)`
     - `| Debits_posted_must_be_zero (* 10 *)`
     - `| Credits_pending_must_be_zero (* 11 *)`
     - `| Credits_posted_must_be_zero (* 12 *)`
     - `| Ledger_must_not_be_zero (* 13 *)`
     - `| Code_must_not_be_zero (* 14 *)`
     - `| Exists_with_different_flags (* 15 *)`
     - `| Exists_with_different_user_data_128 (* 16 *)`
     - `| Exists_with_different_user_data_64 (* 17 *)`
     - `| Exists_with_different_user_data_32 (* 18 *)`
     - `| Exists_with_different_ledger (* 19 *)`
     - `| Exists_with_different_code (* 20 *)`
     - `| Exists (* 21 *)`
     - `| Imported_event_expected (* 22 *)`
     - `| Imported_event_not_expected (* 23 *)`
     - `| Imported_event_timestamp_out_of_range (* 24 *)`
     - `| Imported_event_timestamp_must_not_advance (* 25 *)`
     - `| Imported_event_timestamp_must_not_regress (* 26 *)`
   - Map these to u32 integers for wire format.

   - `type create_transfer_result =`
     - `| Ok (* 0 *)`
     - `| Linked_event_failed (* 1 *)`
     - `| Linked_event_chain_open (* 2 *)`
     - `| Timestamp_must_be_zero (* 3 *)`
     - `| Reserved_flag (* 4 *)`
     - `| Id_must_not_be_zero (* 5 *)`
     - `| Id_must_not_be_int_max (* 6 *)`
     - `| Flags_are_mutually_exclusive (* 7 *)`
     - `| Debit_account_id_must_not_be_zero (* 8 *)`
     - `| Debit_account_id_must_not_be_int_max (* 9 *)`
     - `| Credit_account_id_must_not_be_zero (* 10 *)`
     - `| Credit_account_id_must_not_be_int_max (* 11 *)`
     - `| Accounts_must_be_different (* 12 *)`
     - `| Pending_id_must_be_zero (* 13 *)`
     - `| Pending_id_must_not_be_zero (* 14 *)`
     - `| Pending_id_must_not_be_int_max (* 15 *)`
     - `| Pending_id_must_be_different (* 16 *)`
     - `| Timeout_reserved_for_pending_transfer (* 17 *)`
     - `| Deprecated_18 (* 18 — was amount_must_not_be_zero *)`
     - `| Ledger_must_not_be_zero (* 19 *)`
     - `| Code_must_not_be_zero (* 20 *)`
     - `| Debit_account_not_found (* 21 *)`
     - `| Credit_account_not_found (* 22 *)`
     - `| Accounts_must_have_the_same_ledger (* 23 *)`
     - `| Transfer_must_have_the_same_ledger_as_accounts (* 24 *)`
     - `| Pending_transfer_not_found (* 25 *)`
     - `| Pending_transfer_not_pending (* 26 *)`
     - `| Pending_transfer_has_different_debit_account_id (* 27 *)`
     - `| Pending_transfer_has_different_credit_account_id (* 28 *)`
     - `| Pending_transfer_has_different_ledger (* 29 *)`
     - `| Pending_transfer_has_different_code (* 30 *)`
     - `| Exceeds_pending_transfer_amount (* 31 *)`
     - `| Pending_transfer_has_different_amount (* 32 *)`
     - `| Pending_transfer_already_posted (* 33 *)`
     - `| Pending_transfer_already_voided (* 34 *)`
     - `| Pending_transfer_expired (* 35 *)`
     - `| Exists_with_different_flags (* 36 *)`
     - `| Exists_with_different_debit_account_id (* 37 *)`
     - `| Exists_with_different_credit_account_id (* 38 *)`
     - `| Exists_with_different_amount (* 39 *)`
     - `| Exists_with_different_pending_id (* 40 *)`
     - `| Exists_with_different_user_data_128 (* 41 *)`
     - `| Exists_with_different_user_data_64 (* 42 *)`
     - `| Exists_with_different_user_data_32 (* 43 *)`
     - `| Exists_with_different_timeout (* 44 *)`
     - `| Exists_with_different_code (* 45 *)`
     - `| Exists (* 46 *)`
     - `| Overflows_debits_pending (* 47 *)`
     - `| Overflows_credits_pending (* 48 *)`
     - `| Overflows_debits_posted (* 49 *)`
     - `| Overflows_credits_posted (* 50 *)`
     - `| Overflows_debits (* 51 *)`
     - `| Overflows_credits (* 52 *)`
     - `| Overflows_timeout (* 53 *)`
     - `| Exceeds_credits (* 54 *)`
     - `| Exceeds_debits (* 55 *)`
     - `| Imported_event_expected (* 56 *)`
     - `| Imported_event_not_expected (* 57 *)`
     - `| Imported_event_timestamp_out_of_range (* 58 *)`
     - `| Imported_event_timestamp_must_not_advance (* 59 *)`
     - `| Imported_event_timestamp_must_not_regress (* 60 *)`
     - `| Imported_event_timestamp_must_postdate_debit_account (* 61 *)`
     - `| Imported_event_timestamp_must_postdate_credit_account (* 62 *)`
     - `| Imported_event_timeout_must_be_zero (* 63 *)`
     - `| Closing_transfer_must_be_pending (* 64 *)`
     - `| Debit_account_already_closed (* 65 *)`
     - `| Credit_account_already_closed (* 66 *)`
     - `| Exists_with_different_ledger (* 67 *)`
     - `| Id_already_failed (* 68 *)`

8. Define sparse result structs
   - Create results use sparse encoding — only errors are returned:
     - `type create_accounts_result = { index: u32; result: create_account_result }`
     (8 bytes on wire)
     - `type create_transfers_result = { index: u32; result: create_transfer_result }`
     (8 bytes on wire)
   - A fully successful batch returns **zero** result items.
   - The `index` field identifies which event in the batch failed.

9. Define filter types
   - `type account_filter = { account_id: u128; user_data_128: u128; user_data_64: u64;
                               user_data_32: u32; code: u16; reserved: bytes (* 58 bytes *);
                               timestamp_min: u64; timestamp_max: u64;
                               limit: u32; flags: account_filter_flags }`
   (128 bytes on wire. Used by `get_account_transfers` and `get_account_balances`.)
   - `type account_filter_flags = { debits: bool; credits: bool; reversed: bool; padding: u29 }` (u32)
   - `type query_filter = { user_data_128: u128; user_data_64: u64; user_data_32: u32;
                             ledger: u32; code: u16; reserved: bytes (* 6 bytes *);
                             timestamp_min: u64; timestamp_max: u64;
                             limit: u32; flags: query_filter_flags }`
   (64 bytes on wire. Used by `query_accounts` and `query_transfers`.)
   - `type query_filter_flags = { reversed: bool; padding: u31 }` (u32)
   - Zero values for filter fields mean "no filter" for that field.

10. Define ChangeEvent and ChangeEventsFilter types
    - `type change_event_type = Single_phase | Two_phase_pending | Two_phase_posted
                                | Two_phase_voided | Two_phase_expired` (u8, values 0–4)
    - `type change_event = { transfer_id: u128; transfer_amount: u128;
                              transfer_pending_id: u128; transfer_user_data_128: u128;
                              transfer_user_data_64: u64; transfer_user_data_32: u32;
                              transfer_timeout: u32; transfer_code: u16;
                              transfer_flags: transfer_flags;
                              ledger: u32; event_type: change_event_type;
                              reserved: bytes (* 39 bytes *);
                              debit_account_id: u128;
                              debit_account_debits_pending: u128;
                              debit_account_debits_posted: u128;
                              debit_account_credits_pending: u128;
                              debit_account_credits_posted: u128;
                              debit_account_user_data_128: u128;
                              debit_account_user_data_64: u64;
                              debit_account_user_data_32: u32;
                              debit_account_code: u16;
                              debit_account_flags: account_flags;
                              credit_account_id: u128;
                              credit_account_debits_pending: u128;
                              credit_account_debits_posted: u128;
                              credit_account_credits_pending: u128;
                              credit_account_credits_posted: u128;
                              credit_account_user_data_128: u128;
                              credit_account_user_data_64: u64;
                              credit_account_user_data_32: u32;
                              credit_account_code: u16;
                              credit_account_flags: account_flags;
                              timestamp: u64;
                              transfer_timestamp: u64;
                              debit_account_timestamp: u64;
                              credit_account_timestamp: u64 }`
    (384 bytes on wire. Size = Transfer(128) + 2×Account(128).)
    - `type change_events_filter = { timestamp_min: u64; timestamp_max: u64;
                                      limit: u32; reserved: bytes (* 44 bytes *) }`
    (64 bytes on wire.)

11. Define request and response types
    - In `requests.ml`:
      - `type create_accounts = account list`
      - `type create_transfers = transfer list`
      - `type lookup_accounts = u128 list`
      - `type lookup_transfers = u128 list`
      - `type get_account_transfers = account_filter`
      - `type get_account_balances = account_filter`
      - `type query_accounts = query_filter`
      - `type query_transfers = query_filter`
      - `type get_change_events = change_events_filter`
      - `type request =
          | Create_accounts of create_accounts
          | Create_transfers of create_transfers
          | Lookup_accounts of lookup_accounts
          | Lookup_transfers of lookup_transfers
          | Get_account_transfers of get_account_transfers
          | Get_account_balances of get_account_balances
          | Query_accounts of query_accounts
          | Query_transfers of query_transfers
          | Get_change_events of get_change_events`
    - Response types differ per operation:
      - `create_accounts` → `create_accounts_result list` (sparse, only errors)
      - `create_transfers` → `create_transfers_result list` (sparse, only errors)
      - `lookup_accounts` → `account list` (found entries only)
      - `lookup_transfers` → `transfer list` (found entries only)
      - `get_account_transfers` → `transfer list`
      - `get_account_balances` → `account_balance list`
      - `query_accounts` → `account list`
      - `query_transfers` → `transfer list`
      - `get_change_events` → `change_event list`

12. Document API contract
    - `docs/api.md` should specify:
      - batch size limits are dynamic: `batch_size_limit / event_size` (negotiated at session registration, default message_size_max = 1 MiB minus 256-byte header)
      - batchable operations: `create_accounts`, `create_transfers`, `lookup_accounts`, `lookup_transfers`
      - non-batchable (single filter per request): `get_account_transfers`, `get_account_balances`, `query_accounts`, `query_transfers`, `get_change_events`
      - idempotency rules and `exists` semantics
      - timestamp ownership and imported semantics
      - linked event behavior (atomic chains)
      - error code meanings
      - sparse result format for create operations

## Example type snippet (for reference)
```ocaml
type amount
val amount_of_int64 : int64 -> (amount, error) result
```

## Checklists
- [ ] No invalid records can be constructed without passing validators
- [ ] Errors are explicit and mapped to stable u32 codes matching TigerBeetle
- [ ] API doc exists and matches types
- [ ] All TigerBeetle flag and field constraints are captured in types or validators
- [ ] Field order in records matches TigerBeetle binary layout exactly
- [ ] Sparse result format implemented for create operations

## Notes
OCaml types are your primary safety tool here. Use modules and signatures to
prevent construction of invalid values.

**Divergences from TigerBeetle**: The MVP omits the `pulse` operation (internal
to VR protocol). All other operations and types should match TigerBeetle exactly.
