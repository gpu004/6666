# Step 05 - State machine

Goal: Implement the deterministic business logic for accounts and transfers.

## Deliverables
- In memory state representation
- Pure apply functions for each event
- Idempotency checks

## Files to create
- `src/engine/state.mli`
- `src/engine/state.ml`
- `src/engine/apply.mli`
- `src/engine/apply.ml`
- `test/state_test.ml`

## Tasks
1. Define state structure
   - `type t = { accounts; transfers; account_transfers; last_timestamp }`
   - Use `Hashtbl` for MVP.

2. Implement account creation
   - `apply_create_accounts : state -> account list -> state * result list`
   - For each account:
     - If id exists: result `Exists`.
     - Else validate fields and insert.
   - Assign timestamp sequentially.
   - Enforce TigerBeetle constraints:
     - id not `0` or `2^128-1`
     - ledger and code non-zero
     - balances and `reserved` must be zero on create
     - timestamp must be zero unless `flags.imported` is set
     - if `flags.imported`, validate timestamp rules from TigerBeetle
   - Apply `flags.linked` semantics for account creation chains.

3. Implement transfer creation
   - `apply_create_transfers : state -> transfer list -> state * result list`
   - Validate:
     - debit and credit accounts exist
     - debit and credit are distinct
     - ledger matches both accounts
     - amount > 0
     - flag rules for pending/post/void
     - balancing and closing flags follow TigerBeetle rules
     - imported rules for timestamp and timeout
   - Apply debits and credits.
   - Update index of transfers per account.
   - Apply `flags.linked` semantics for transfer chains.
   - Implement two-phase transfer rules:
     - pending reserves debits/credits
     - post/void resolves pending_id
     - timeout expires pending transfers deterministically

4. Implement lookup
   - `lookup_accounts : state -> account_id list -> account option list`
   - `lookup_transfers : state -> transfer_id list -> transfer option list`
   - Implement query APIs:
     - `get_account_transfers`
     - `get_account_balances`
     - `query_accounts`
     - `query_transfers`

5. Deterministic timestamping
   - `last_timestamp` increments per event.
   - Each applied event gets a unique timestamp.
   - For `flags.imported`, use provided timestamps and keep them strictly increasing.

6. Assertions and invariants
   - Use explicit validation for input errors.
   - Use `assert` for internal invariants (should never fail).

## Checklists
- [ ] Applying the same batch twice yields same results
- [ ] State is deterministic and reproducible
- [ ] All error cases return correct codes
- [ ] Linked chains are atomic
- [ ] Pending, post, void, and timeout semantics match TigerBeetle

## Notes
Keep `apply_*` functions pure where possible. This makes testing simple and
gives you TigerBeetle style determinism.
