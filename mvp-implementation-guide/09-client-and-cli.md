# Step 09 - Client library and CLI

Goal: Provide an OCaml client that supports batching and a simple CLI for
manual testing.

## Deliverables
- Client library with auto batching
- TigerBeetle-compatible time-based id generator
- CLI REPL for interactive testing

## Files to create
- `src/client/session.mli`
- `src/client/session.ml`
- `src/client/client.mli`
- `src/client/client.ml`
- `bin/cli.ml`
- `docs/client.md`

## Tasks
1. Client session
   - Maintain one TCP connection.
   - Allow only one inflight batch.
   - Queue new requests until inflight is complete.
   - Retry indefinitely on network errors (no timeouts exposed at client level).
   - If evicted by server, reconnect and re-register before continuing.
   - With Eio, use `Eio.Net.connect` and a single fiber for send/recv.

2. Auto batching
   - Group requests by type.
   - Flush batch when size limit or latency expires.
   - Enforce request-size constraints:
     - `create_*` and `lookup_*` limits are dynamic (`batch_size_limit / event_size`),
       negotiated at session registration.
     - query requests one filter per request.
   - Use `Eio.Time` for the latency window.

3. Id generation
   - Provide `id ()` that returns TigerBeetle-style sortable 128-bit ids:
     - high 48 bits: millisecond timestamp
     - low 80 bits: randomness with monotonic increment in same millisecond
   - Ensure ids are never `0` or `2^128 - 1`.

4. CLI REPL
   - Parse commands:
     - `create_accounts` with fields
     - `create_transfers` with fields
     - `lookup_accounts` with ids
     - `lookup_transfers` with ids
     - `get_account_transfers` with filter
     - `get_account_balances` with filter
     - `query_accounts` with filter
     - `query_transfers` with filter
   - Print results as JSON.

5. Docs
   - `docs/client.md` with code examples and CLI usage.

## Checklists
- [ ] Client batches requests automatically
- [ ] CLI can create, lookup, and query objects
- [ ] Ids are stable and collision resistant
- [ ] Session retry and eviction behavior is documented

## Notes
This keeps the client experience similar to TigerBeetle but minimal.
