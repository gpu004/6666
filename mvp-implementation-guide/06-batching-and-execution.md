# Step 06 - Batching and execution pipeline

Goal: Build the execution pipeline that batches requests, applies them in
sequence, then writes the WAL atomically.

## Deliverables
- Request queue and batcher
- Execution loop that guarantees serial order
- WAL append then apply ordering

## Files to create
- `src/engine/batcher.mli`
- `src/engine/batcher.ml`
- `src/engine/executor.mli`
- `src/engine/executor.ml`

## Tasks
1. Define batch size limits
   - Constants in `src/core/constants.ml`:
     - `max_events_per_request`
     - `batch_latency_ms`
   - With Eio, use `Eio.Time` for latency windows (monotonic clock).
   - Do not hardcode 8189 globally; use a dynamic `batch_size_limit` negotiated at session registration.

2. Queue structure
   - Use a simple in memory queue:
     - `type item = { request; reply : response -> unit }`
   - Single producer (server) and single consumer (executor).

3. Implement batcher
   - Accumulate items until:
     - total events reaches limit, or
     - latency timer expires.
   - Only merge same request types.
   - Respect TigerBeetle-style request bounds:
     - `create_*` and `lookup_*` max events are derived from `batch_size_limit / event_size`
       (default deployments are often near 8189 for 128-byte events, but treat this as configuration-derived).
     - query-style requests are one filter per request.

4. Implement executor loop
   - For each batch:
     - compute results by running apply logic on a COPY of state (or use functional updates)
     - encode WAL record (prepare/request only)
     - append + fsync WAL record
     - if WAL fsync succeeds, commit state changes and derive replies from committed execution
     - if WAL fails, discard pending changes and reply with server error
   - The key invariant: no state mutation is visible until after WAL durability.

5. Ensure deterministic ordering
   - All apply logic runs in a single thread.
   - No parallel applies.

6. Response mapping
   - Split batch results back to per request responses.
   - Preserve original request order.
   - Query replies must preserve deterministic record ordering.

## Checklists
- [ ] WAL append happens before state commit
- [ ] Batch ordering is stable and deterministic
- [ ] Results map back correctly to each request

## Notes
The MVP should keep batching simple. This is the core throughput lever inspired
by TigerBeetle.

**Rollback Strategy**: If you apply in-place before fsync, you need a
rollback/diff mechanism. The safer approach is to compute results on a copy or
use functional state updates, then swap the reference atomically after WAL
commit.
