# Step 08 - Server and protocol

Goal: Build a network server that receives requests, batches them, and returns
responses.

## Deliverables
- TCP server with message framing
- Protocol handler and request parsing
- Single threaded event loop

## Files to create
- `src/server/server.mli`
- `src/server/server.ml`
- `src/server/connection.ml`
- `bin/server.ml`

## Tasks
1. Implement message framing
   - Read fixed-size 256-byte header.
   - Validate header checksum first.
   - Validate cluster id, protocol version, command, and zeroed reserved fields.
   - Validate total `size` and `message_size_max`.
   - Read payload bytes (`size - 256`) and validate body checksum.

2. Implement connection handler
   - For each connection:
     - loop reading requests
     - decode request
     - enqueue into batcher with reply callback
     - write response when ready
   - With Eio, use `Eio.Net.accept` and `Eio.Flow.read_exact`/`write`.

3. Backpressure
   - Cap inflight requests per connection.
   - Enforce one in-flight request per client session.
   - If queue full, apply documented retry/busy behavior.

4. Error handling
   - Invalid payload: return error response then close.
   - WAL failure: return server error for entire batch.

5. Configuration
   - Use `cmdliner` in `bin/server.ml`.
   - Flags: `--port`, `--wal`, `--snapshot`, `--batch-size`, `--batch-latency-ms`.
   - Add `--cluster`, `--replica-count`, and `--clients-max` for explicit topology/session limits.

6. Shutdown semantics
   - No graceful shutdown path is required.
   - SIGINT/termination is acceptable; recovery is from snapshot + WAL replay.
   - With Eio, terminate the process directly and rely on startup recovery.

7. Client session semantics
   - Implement explicit session registration with random client id.
   - Enforce at most one in-flight request per session.
   - Queue subsequent session requests until reply is sent.
   - Enforce max sessions and eviction policy (least-recently-committed session first).
   - Retry semantics: server tolerates duplicates by idempotent ids and stable request mapping.
   - Document session lifecycle, retries, and eviction in `docs/api.md`.

## Checklists
- [ ] Server handles multiple connections
- [ ] Requests are framed and validated with TigerBeetle-aligned 256-byte headers
- [ ] Responses map correctly to request order
- [ ] Session semantics documented in API docs

## Notes
Keep the server single threaded. Only IO is concurrent. The executor processes
one batch at a time.
