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
   - Read fixed size header.
   - Validate magic and version.
   - Read payload length bytes.
   - Validate checksum.

2. Implement connection handler
   - For each connection:
     - loop reading requests
     - decode request
     - enqueue into batcher with reply callback
     - write response when ready
   - With Eio, use `Eio.Net.accept` and `Eio.Flow.read_exact`/`write`.

3. Backpressure
   - Cap inflight requests per connection.
   - If queue full, respond with a retry error code.

4. Error handling
   - Invalid payload: return error response then close.
   - WAL failure: return server error for entire batch.

5. Configuration
   - Use `cmdliner` in `bin/server.ml`.
   - Flags: `--port`, `--wal`, `--snapshot`, `--batch-size`, `--batch-latency-ms`.

6. Graceful shutdown
   - On SIGINT:
     - stop accepting new connections
     - flush current batch
     - close WAL
   - With Eio, wrap the server loop in `Eio.Switch.run` and cancel on signal.

## Checklists
- [ ] Server handles multiple connections
- [ ] Requests are framed and validated
- [ ] Responses map correctly to request order

## Notes
Keep the server single threaded. Only IO is concurrent. The executor processes
one batch at a time.
