# TigerOCaml API Contract (Step 02)

## Operation Surface

Batchable operations:
- `create_accounts`
- `create_transfers`
- `lookup_accounts`
- `lookup_transfers`

Single-filter operations (one filter per request):
- `get_account_transfers`
- `get_account_balances`
- `query_accounts`
- `query_transfers`
- `get_change_events`

## Batch Size Limits

Batch limits are dynamic and derived from:
- `batch_size_limit / event_size`

`batch_size_limit` is negotiated at session registration.
With default `message_size_max = 1 MiB`, the limit is based on payload size plus the 256-byte header budget.

## Core Invariants

ID rules (`account_id`, `transfer_id`, and all ID-like fields):
- Must not be `0`.
- Must not be `2^128 - 1`.

Ledger/code rules:
- `ledger` must not be `0`.
- `code` must not be `0`.

Flag and padding rules:
- Bitfield padding bits must be zero.
- `account_flags.debits_must_not_exceed_credits` and `account_flags.credits_must_not_exceed_debits` are mutually exclusive.
- `transfer_flags.pending`, `transfer_flags.post_pending_transfer`, and `transfer_flags.void_pending_transfer` are mutually exclusive.
- `transfer_flags.balancing_debit` and `transfer_flags.balancing_credit` are mutually exclusive.

Wire layout rules:
- Field order is layout-critical for all wire records.
- `account` and `transfer` are each 128 bytes.
- `account_balance` is 128 bytes.
- `account_filter` is 128 bytes.
- `query_filter` is 64 bytes.
- `change_event` is 384 bytes.
- `change_events_filter` is 64 bytes.

## Create Results: Sparse Encoding

Create operations return sparse result items:
- `create_accounts_result = { index: u32; result: create_account_result }`
- `create_transfers_result = { index: u32; result: create_transfer_result }`

Behavior:
- Only failed events appear in the result list.
- A fully successful batch returns an empty list.
- `index` points to the failed event position within the submitted batch.

## Idempotency and Exists Semantics

Clients own idempotency keys (`id`):
- Client generates and persists IDs before submission.
- Retries reuse the same ID.

Outcomes:
- Same ID + same payload semantics -> `Exists` (idempotent success).
- Same ID + different payload fields -> `Exists_with_different_*` result.

## Timestamp Ownership and Imported Semantics

Normal events:
- Cluster owns timestamp assignment.
- For non-imported events, timestamp must be zero on input.

Imported events (`flags.imported = true`):
- Caller supplies timestamp.
- Imported timestamps must satisfy ordering/range constraints represented by imported-event result codes.

## Linked Event Chains

`flags.linked` marks atomic chain membership.
If one linked event fails, the chain fails consistently and returns linked-event result codes (`Linked_event_failed` / chain-open semantics).

## Error Code Mapping

Create account and create transfer result enums map to stable `u32` codes matching TigerBeetle semantics exactly.

Notable points:
- `create_account_result`: codes `0..26`.
- `create_transfer_result`: codes `0..68` (including `Deprecated_18`).

## Filter Semantics

For `account_filter` and `query_filter`:
- Zero-valued filter fields mean "no filter" for that field.
- `limit` controls maximum returned results.
- `reversed` flags request reverse chronological ordering.
