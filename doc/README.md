# OCaml ledger core

This is the reader's guide for the experimental OCaml rewrite in
[`ocam/src/state_machine.ml`](../ocam/src/state_machine.ml). It is a
deterministic, in-memory implementation of a portion of TigerBeetle's ledger
state-machine behavior. It is not a TigerBeetle server and it does not yet
replace the pinned upstream Zig implementation.

Read this guide first, then use [the architecture and behavior notes](architecture.md)
while reading the code. The detailed implementation boundary and test coverage
are tracked in [`ocam/OCAML_REWRITE.md`](../ocam/OCAML_REWRITE.md).

## Generate the API reference

The public interface is [`ocam/src/state_machine.mli`](../ocam/src/state_machine.mli).
It is rendered with `odoc`, which is already declared as the package's
documentation dependency:

```sh
cd ocam
opam install . --deps-only --with-doc
opam exec -- dune build @doc
open _build/default/_doc/_html/index.html
```

`_build/default/_doc/_html/` is generated output. Do not edit or commit it;
change the `.mli` comments or these Markdown guides instead.

## The public model

Call `State_machine.empty ()` to make a state. The state owns accounts,
transfers, pending-transfer status, and the most recently committed timestamp.
All public operations are synchronous and mutate that state in the caller's
thread. There is deliberately no Async, storage, network, or clock dependency
in this layer.

Identifiers and amounts are `U128.t`. `U128` exposes construction, comparison,
addition, and subtraction explicitly so balance arithmetic can report overflow
or underflow rather than silently wrapping.

An account has four monotonic balance fields:

| Debit side | Credit side |
| --- | --- |
| `debits_pending` | `credits_pending` |
| `debits_posted` | `credits_posted` |

A normal transfer increases posted debit and credit balances by the same
amount. A pending transfer increases the pending fields instead. Consequently,
across a set of accounts participating in successful transfers, total pending
debits equal total pending credits and total posted debits equal total posted
credits.

## Operations at a glance

| Operation | What it does |
| --- | --- |
| `create_accounts` | Validates and stores account requests. |
| `create_transfers` | Validates and applies normal, pending, post-pending, and void-pending transfers. |
| `expire_pending_transfers` | Removes balances for timed-out pending transfers and marks them expired. |
| `lookup_accounts`, `lookup_transfers` | Looks up supplied IDs, keeping request order and omitting unknown IDs. |
| `query_accounts`, `query_transfers` | Filters by non-zero fields, sorts by timestamp, then applies `limit`. |
| `get_account_transfers` | Queries transfer history for the debit and/or credit side of one account. |
| `get_account_balances` | Queries per-transfer balance snapshots for accounts created with the history flag. |

Each create operation returns one result per input request. A successful result
contains the assigned timestamp; an unsuccessful result normally has timestamp
zero and a status explaining the validation or state conflict. Exact retry
requests are idempotent and return an `*_exists` status rather than changing
balances again.

## A minimal execution

Construct `account` and `transfer` records using zero-valued balance and
metadata fields, set a non-zero `id`, `ledger`, and `code`, then submit them in
commit order:

```ocaml
let state = State_machine.empty () in
let accounts = State_machine.create_accounts state ~timestamp:1L [ account_1; account_2 ] in
let transfers = State_machine.create_transfers state ~timestamp:3L [ transfer ] in
```

Requests without the `imported` flag must carry `timestamp = 0L`; the state
machine assigns timestamps from the supplied operation timestamp. The caller
is responsible for supplying operations in commit order. See
[the behavior notes](architecture.md) for batch, pending, and query rules.

## What is and is not covered

The Dune tests exercise account creation, normal and pending transfers,
posting, voiding, expiry, linked rollback, lookups, queries, U128 boundaries,
and several deterministic properties. They do not establish full compatibility
with TigerBeetle. In particular, the OCaml core has no C ABI or 128-byte wire
codec, does not link into the copied Zig server, and has remaining parity work
listed in `ocam/OCAML_REWRITE.md`.

The pinned tree at [`path/to/tigerbeetle`](../path/to/tigerbeetle) remains the
upstream behavior reference. Do not change it while working on this rewrite.
