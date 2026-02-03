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

2. Queue structure
   - Use a simple in memory queue:
     - `type item = { request; reply : response -> unit }`
   - Single producer (server) and single consumer (executor).

3. Implement batcher
   - Accumulate items until:
     - total events reaches limit, or
     - latency timer expires.
   - Only merge same request types.

4. Implement executor loop
   - For each batch:
     - apply batch to state to get results
     - encode request + response as WAL record
     - append + fsync WAL
     - if WAL ok, commit state changes
     - if WAL error, drop changes and reply with server error

5. Ensure deterministic ordering
   - All apply logic runs in a single thread.
   - No parallel applies.

6. Response mapping
   - Split batch results back to per request responses.
   - Preserve original request order.

## Checklists
- [ ] WAL append happens before state commit
- [ ] Batch ordering is stable and deterministic
- [ ] Results map back correctly to each request

## Notes
The MVP should keep batching simple. This is the core throughput lever inspired
by TigerBeetle.
