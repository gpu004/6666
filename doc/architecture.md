# Ledger-core behavior notes

This page records the behavior implemented by the current OCaml core. It is a
guide to the code, not a claim that every rule is already TigerBeetle
compatible. For the compatibility boundary, see
[`ocam/OCAML_REWRITE.md`](../ocam/OCAML_REWRITE.md).

## State and determinism

`State_machine.t` holds three in-memory tables keyed by `U128` ID:

- accounts;
- transfers; and
- pending-transfer status (`Pending`, `Posted`, `Voided`, or `Expired`).

The only mutable state is inside `t`. Given the same initial state and the same
operations in the same order, the core produces the same result records and
stored values. It does not read the wall clock, perform I/O, schedule Async
work, or persist data.

`commit_timestamp state` reports the latest successful commit timestamp. An
adapter at the replication boundary supplies the timestamp for each operation
batch and persists the resulting state; neither responsibility belongs in this
module.

## Accounts

`create_accounts state ~timestamp requests` processes requests left-to-right.
For a non-imported account, the request timestamp must be zero and the module
assigns the batch timestamp, incrementing it for each request. IDs, ledger,
and code must be non-zero; the initial balance fields must be zero; and the two
"must not exceed" account constraints cannot both be enabled.

An existing account is accepted as an idempotent retry only when its flags and
immutable request fields match. Otherwise the result identifies the first
mismatch. The stored account retains its original timestamp.

Imported accounts use the request timestamp instead. It must be positive, no
greater than the supplied event timestamp, and strictly greater than the
current commit timestamp.

## Transfers and balances

`create_transfers state ~timestamp requests` also processes requests in order.
It verifies identifiers, flags, ledger agreement, account existence and
closure, balance constraints, pending-transfer relationships, and arithmetic
before changing the state.

A normal transfer applies its amount to `debits_posted` on the debit account
and `credits_posted` on the credit account. A pending transfer applies it to
the corresponding pending fields and records `Pending` status. The account
constraints are checked before the update:

- `debits_must_not_exceed_credits` rejects a debit that would make total debit
  balances exceed posted credits.
- `credits_must_not_exceed_debits` rejects a credit that would make total credit
  balances exceed posted debits.

Posting a pending transfer removes its pending amount and adds the posted
amount. Voiding removes the pending amount without adding posted balances. A
pending transfer with a positive `timeout` expires when
`transfer.timestamp + timeout * 1_000_000_000 <= timestamp` passed to
`expire_pending_transfers`; expiry removes its pending balances and prevents a
later post or void.

## Linked batches

The `linked` flag makes adjacent requests atomic. A run ends at the first
request whose `linked` flag is false. The core applies a linked run to a cloned
state and commits that clone only if every request succeeds. If a request
fails, that request keeps its actual error while all other requests in the run
receive `*_linked_event_failed`; no change from the run becomes visible.

A batch whose final request is marked `linked` is an open chain. It is rejected
without applying any request, reporting `*_linked_event_chain_open` for the
last entry and `*_linked_event_failed` for the preceding entries.

## Reads and filters

Lookups preserve the supplied ID order and leave missing IDs out of the
result. Query filters use zero as the wildcard for metadata, ledger, code, and
timestamp bounds. `timestamp_min = 0L` and `timestamp_max = 0L` mean no bound.

Query results are ordered by stored timestamp ascending by default or descending
with `reversed = true`, then truncated to `limit`. A non-positive `limit`
returns no results. `get_account_transfers` additionally selects the debit
and/or credit side, while `get_account_balances` only checks the current stored
account against timestamp bounds.

## Validation and evidence

Run the implementation tests from `ocam/`:

```sh
opam exec -- dune runtest
opam exec -- dune build @doc
```

The first command runs scenario and QCheck property tests. The second produces
the browsable API reference from the interface comments. The tests describe the
implemented behavior; when they disagree with the pinned upstream source,
compare the relevant implementation with `path/to/tigerbeetle` and update the
compatibility plan rather than assuming parity.
