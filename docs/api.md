# TigerOCaml API Reference

## Data Model

### Account (128 bytes on wire)

| Field | Type | Constraint |
|-------|------|-----------|
| `id` | uint128 | Must not be `0` or `2^128 - 1` |
| `debits_pending` | uint128 | Must be `0` on create |
| `debits_posted` | uint128 | Must be `0` on create |
| `credits_pending` | uint128 | Must be `0` on create |
| `credits_posted` | uint128 | Must be `0` on create |
| `user_data_128` | uint128 | Application-defined |
| `user_data_64` | uint64 | Application-defined |
| `user_data_32` | uint32 | Application-defined |
| `reserved` | int | Must be `0` |
| `ledger` | uint32 | Must not be `0` |
| `code` | uint16 | Must not be `0` |
| `flags` | uint16 | See account flags below |
| `timestamp` | uint64 | Assigned by cluster; must be `0` unless `flags.imported` |

Field order is binary-layout critical and must match TigerBeetle exactly.

### Transfer (128 bytes on wire)

| Field | Type | Constraint |
|-------|------|-----------|
| `id` | uint128 | Must not be `0` or `2^128 - 1` |
| `debit_account_id` | uint128 | Must exist |
| `credit_account_id` | uint128 | Must exist, must differ from debit |
| `amount` | uint128 | Must not be `0` (unless posting/voiding pending) |
| `pending_id` | uint128 | `0` unless posting/voiding a pending transfer |
| `user_data_128` | uint128 | Application-defined |
| `user_data_64` | uint64 | Application-defined |
| `user_data_32` | uint32 | Application-defined |
| `timeout` | uint32 | Reserved for pending transfers only |
| `ledger` | uint32 | Must match both accounts |
| `code` | uint16 | Must not be `0` |
| `flags` | uint16 | See transfer flags below |
| `timestamp` | uint64 | Assigned by cluster |

Field order is binary-layout critical and must match TigerBeetle exactly.

## Account Flags

| Bit | Name | Description |
|-----|------|-------------|
| 0 | `linked` | Atomic chain — this event succeeds/fails with the next |
| 1 | `debits_must_not_exceed_credits` | Balance constraint |
| 2 | `credits_must_not_exceed_debits` | Balance constraint |
| 3 | `history` | Enable balance history queries |
| 4 | `imported` | Caller provides timestamp |
| 5 | `closed` | Account is closed; requires a balance constraint flag |

`debits_must_not_exceed_credits` and `credits_must_not_exceed_debits` are mutually exclusive.

## Transfer Flags

| Bit | Name | Description |
|-----|------|-------------|
| 0 | `linked` | Atomic chain |
| 1 | `pending` | Two-phase: reserve funds |
| 2 | `post_pending_transfer` | Resolve pending: commit |
| 3 | `void_pending_transfer` | Resolve pending: rollback |
| 4 | `balancing_debit` | Clamp amount to available debit balance |
| 5 | `balancing_credit` | Clamp amount to available credit balance |
| 6 | `closing_debit` | Close debit account after transfer |
| 7 | `closing_credit` | Close credit account after transfer |
| 8 | `imported` | Caller provides timestamp |

`pending`, `post_pending_transfer`, and `void_pending_transfer` are mutually exclusive.

## Request Types

| Command | Batch limit | Description |
|---------|------------|-------------|
| `create_accounts` | dynamic (`batch_size_limit / 128`) | Create accounts atomically per batch |
| `create_transfers` | dynamic (`batch_size_limit / 128`) | Create transfers atomically per batch |
| `lookup_accounts` | dynamic (`batch_size_limit / 16`) | Lookup accounts by id |
| `lookup_transfers` | dynamic (`batch_size_limit / 16`) | Lookup transfers by id |
| `get_account_transfers` | 1 filter/request; dynamic reply capacity | Query transfers for an account |
| `get_account_balances` | 1 filter/request; dynamic reply capacity | Query balance snapshots for an account |
| `query_accounts` | 1 filter/request; dynamic reply capacity | Query accounts by filter |
| `query_transfers` | 1 filter/request; dynamic reply capacity | Query transfers by filter |
| `get_change_events` | 1 filter/request; dynamic reply capacity | Query change-event stream |

`batch_size_limit` is negotiated at client session registration. With default
`message_size_max = 1 MiB`, common limits are close to (but not universally) 8189 events.

## Create Result Encoding

- `create_accounts` and `create_transfers` replies are sparse.
- Each item is `{ index: uint32, result: uint32 }`.
- Only failed events produce a result item.
- A fully successful create batch returns an empty result list.

## Idempotency

- The **client** must generate and persist the 128-bit `id` before submission.
- Retries reuse the same `id`.
- If the id already exists with identical fields → `Exists` (success).
- If the id exists with different fields → `Exists_with_different_*` (error).

## Linked Events

Events with `flags.linked` are chained. If any event in the chain fails, all events in the chain fail with `Linked_event_failed`. The last event in the chain does **not** set the `linked` flag.

## Timestamp Ownership

- The cluster assigns strictly increasing timestamps.
- Events with `flags.imported` must provide their own timestamp (must be > 0, strictly increasing).
