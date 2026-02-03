# TigerBeetle Study Guide

_Notes from reviewing the vendored TigerBeetle repository (`tigerbeetle/`) and its documentation on February 2, 2026. Use this as a springboard for designing an OCaml-based MVP inspired by TigerBeetle's architecture._

## 1. Problem Shape & Mission
- TigerBeetle targets highly contended, write-heavy OLTP workloads where each business transaction touches multiple objects (usually two accounts) and must be strictly serializable. (`docs/ARCHITECTURE.md`)
- The productized state machine today is a double-entry ledger: every transfer debits one account and credits another, preserving the invariant that money never appears/disappears. (`docs/concepts/debit-credit.md`)
- Durability and availability are first-class. The cluster must survive disk faults, gray failures, and correlated cloud outages without creating or losing value. (`docs/concepts/safety.md`, `docs/operating/cluster.md`)

## 2. System Topology & Process Model
- A **replica** is a single statically linked binary plus one data file (formatted by `tigerbeetle format`). Start it with `tigerbeetle start --addresses=... datafile`. (`README.md`, `docs/start.md`)
- Production guidance is a **six-replica cluster** spread across three independent sites (2 replicas per site). This yields quorum flexibility: 4/6 to elect a new primary, 3/6 for steady-state throughput if the primary survives. (`docs/operating/cluster.md`)
- No graceful shutdown path—Ctrl+C is acceptable because the system replays from durable WAL + checkpoints on restart.
- The server is **single-threaded** on the hot path; concurrency is handled by batching, pipelining, and deterministic event ordering rather than multi-threaded execution. (`docs/ARCHITECTURE.md`, `docs/concepts/performance.md`)

## 3. Client Interface, Data Model & Requests
- Schema is fixed to **Accounts** and **Transfers** partitioned by integer `ledger` identifiers. All numeric fields (amounts, balances) are unsigned 128-bit integers at a caller-defined asset scale. (`docs/coding/data-modeling.md`)
- Each object exposes three `user_data` slots (128/64/32 bit) for app-specific joins into your OLGP database. (`docs/coding/data-modeling.md#user_data`)
- **Requests** are batches of homogeneous events (max 8,189 per request/reply for most APIs). The cluster commits/rolls back an entire request atomically; events execute sequentially within the batch so later events observe earlier effects. (`docs/coding/requests.md`)
- Clients should share one TigerBeetle session per process and let the client library auto-batch; there is at most one inflight request per session to simplify ordering. (`docs/coding/requests.md`)
- **Idempotency:** The client (ideally the end-user device) must generate and persist the 128-bit `id` prior to submission. Retries reuse the same `id` and receive `ok` or `exists`. (`docs/coding/reliable-transaction-submission.md`)
- **Time & ordering:** The cluster assigns strictly increasing ingestion timestamps and relative timeouts so that all ordering decisions live inside the primary. (`docs/coding/time.md`)
- **Two-phase transfers:** `flags.pending` reserves funds; follow-up transfers with `post_pending_transfer` or `void_pending_transfer` resolve the hold while preserving invariants. Timeouts auto-void stale holds. (`docs/coding/two-phase-transfers.md`)
- Additional primitives include linked events, query APIs, and CDC streaming for control-plane integration (`docs/coding/linked-events.md`, `docs/operating/cdc.md`).

## 4. Consensus & Replication Lifecycle (VSR)
- TigerBeetle implements Viewstamped Replication (chain-style) in `src/vsr/`. Normal path: client request → primary assigns `op`/`timestamp` → write prepare to WAL + forward down the replica chain → collect a quorum of `prepare_ok` → commit + reply → backups learn via next prepare or periodic `commit`. (`docs/internals/vsr.md`)
- **Batching & pipelining:** Each prepare is a batch (~8K transfers). Replication cost is amortized over the batch, keeping throughput close to an in-memory hash table. (`docs/concepts/performance.md`)
- **View changes:** `start_view_change`/`do_view_change` protocols run proactively when heartbeats stall. Headers (hash-chained metadata) allow primaries to repair or truncate WAL gaps safely. (`docs/internals/vsr.md`)
- **State sync vs WAL repair:** If a lagging replica falls more than a checkpoint behind, it state-syncs by installing a newer superblock, then fetching manifest/free-set/table blocks on demand. (`docs/internals/sync.md`)
- **Flexible quorums & clocking:** Clock health is monitored via replica-to-replica ping/pong to build “cluster time,” and Heidi Howard–style quorums let the default 6-replica deployment survive a full cloud outage. (`docs/concepts/safety.md`, `docs/internals/vsr/clock.zig`)

## 5. Storage Engine & On-Disk Layout
- Each replica’s data file contains three zones: **WAL**, **Superblock**, and the **Grid** (append-only array of 512 KiB blocks). (`docs/internals/data_file.md`)
- The grid is a deterministic copy-on-write store. Blocks are identified by `<index, checksum>` pairs stored outside the block to detect misdirected writes. (`src/vsr/grid.zig`)
- The superblock stores (multiple) root pointers: newest/oldest manifest entries plus a compressed free-set bitmap. Four on-disk copies ensure atomic updates. (`docs/internals/data_file.md`)
- WAL is a pair of ring buffers. Once a checkpoint confirms the grid reflects all prepares in that window, WAL slots can wrap. (`docs/internals/vsr.md#protocol-normal`)
- The logical state is an LSM **forest** implemented in `src/lsm/`. Key ideas:
  - Per-tree mutable + immutable in-memory tables feed levelled on-disk tables.
  - Compaction is orchestrated like music: each "bar" has `lsm_compaction_ops` beats, alternating even/odd levels to bound latency. (`docs/internals/lsm.md`)
  - Compaction selection prefers tables that overlap the fewest downstream tables; move-table optimization keeps write amplification near append-only behavior.
  - Tables are immutable; compaction emits manifest events. Manifests are themselves linked lists of `ManifestBlock`s rooted in the superblock, so replaying manifests reconstructs in-memory indexes at startup. (`docs/internals/data_file.md`)
- Snapshots are integral to compaction and future time-travel queries; snapshot ranges control table visibility without in-place mutation. (`docs/internals/lsm.md#snapshots`)

## 6. Safety, Repair & Testing Tooling
- **Hash-chains everywhere:** WAL entries, headers, grid blocks, and manifests are chained and checksummed so corruption is always attributable and repairable from healthy replicas. (`docs/internals/data_file.md`, `docs/internals/vsr.md`)
- **Repair protocols:** Separate flows repair journals, WAL entries, grid blocks, and client replies. Repairs walk backward via header hash chains first, then request missing prepares, then request raw blocks. (`docs/internals/vsr.md#protocol-repair-journal` et seq.)
- **State sync ratchet:** Sync ranges (`sync_op_min/max`) prevent replicas from rolling back partially synced data after crash/restart. (`docs/internals/sync.md`)
- **Simulation (VOPR):** Deterministic simulator (`src/vopr.zig`, `docs/internals/vopr.md`) fuzzes the real code under adversarial disk/network/clock faults, with seeds to reproduce failures. Assertions stay enabled even in production builds.
- **Operational tooling:** Change Data Capture streaming, auditing, cluster monitoring, and automatic upgrades all assume immutable history and deterministic storage so operators never rewrite past data. (`docs/operating/README.md`, `src/state_machine/auditor.zig`)

## 7. Engineering Methodology (TigerStyle)
- **Zero technical debt** posture: invest heavily up front; features ship only when design, implementation, and tests all meet bar. (`docs/TIGER_STYLE.md`)
- **Memory discipline:** Static allocation at startup, no `malloc/free` afterward. This bounds latency and eliminates fragmentation/use-after-free risk.
- **Control-flow constraints:** No recursion; loops and queues have fixed upper bounds; functions limited to ~70 LOC; "push ifs up, fors down" to keep branching centralized.
- **Assertion culture:** Aim for ≥2 assertions per function, assert both positive and negative spaces, duplicate critical assertions in independent code paths (“pair assertions”), and convert surprising comments into executable assertions.
- **Minimal abstractions:** Prefer explicit control over clever indirection; `src/` is largely hand-written Zig modules (VSr, LSM, message bus, IO, time, trace, etc.) with no third-party deps.

## 8. Patterns & Takeaways for an OCaml MVP
1. **Domain-specific API over generic SQL:** Start with typed records (`Account`, `Transfer`) and enforce double-entry invariants inside the database so application code can remain stateless/functional.
2. **Deterministic single-threaded event loop:** Model the OCaml server as one core that pulls batches from a network queue, applies them sequentially, and appends to a WAL. Concurrency lives in batching, not multi-threaded locks.
3. **Static resource planning:** Accept config (max accounts/transfers, WAL depth) at startup, pre-allocate arrays/buffers (OCaml `Bigarray` or `Cstruct`) and avoid heap churn in the hot path.
4. **Append-only WAL + copy-on-write checkpoints:** Mirror TigerBeetle’s “WAL + superblock + grid” in spirit by combining an append-only log with periodic snapshots of immutable structures (e.g., persistent B-tree/LSM built atop fixed-size segments).
5. **Immutable, leveled storage:** Borrow the mutable→immutable→level pipeline and musical compaction scheduling to keep OCaml GC predictable. Even if the MVP uses a simpler SSTable format, keep manifest logs and deterministic block numbering so replicas can compare hashes.
6. **Idempotent client protocol:** Require callers to supply 128-bit IDs (use OCaml ULID/UUIDv7) and respond with explicit `ok/exists` codes. Provide a client helper that auto-batches to mimic TigerBeetle’s session semantics.
7. **Built-in time authority:** Have the leader assign ingestion timestamps and convert client-provided relative timeouts into absolute deadlines inside the server.
8. **Repair-first mindset:** Design data structures with checksums and hash chains from day one, and script a deterministic simulator/fuzzer that can step the OCaml state machine through fault scenarios before you attempt multi-node consensus.
9. **Cultural guardrails:** Adopt TigerStyle-like coding standards for the OCaml codebase—bounded loops, aggressive assertions, preference for explicit data movement—to keep the MVP understandable even with low headcount.

## 9. Pointers for Deeper Study
- Architecture & motivation: `docs/ARCHITECTURE.md`, `docs/concepts/*.md`, `docs/start.md`.
- Consensus & storage internals: `docs/internals/vsr.md`, `docs/internals/data_file.md`, `docs/internals/lsm.md`, `docs/internals/sync.md`.
- Operational guidance: `docs/operating/*.md`.
- Coding methodology: `docs/TIGER_STYLE.md`, `src/vsr/`, `src/lsm/`, `src/state_machine/`.
- Testing & simulation: `docs/internals/vopr.md`, `src/vopr.zig`.

_Use this map to prioritize which TigerBeetle subsystems to re-read when you need deeper details for your OCaml prototype._
