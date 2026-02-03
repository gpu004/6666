# Step 09 - Client library and CLI

Goal: Provide an OCaml client that supports batching and a simple CLI for
manual testing.

## Deliverables
- Client library with auto batching
- Id generator (ULID or UUIDv7)
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
   - With Eio, use `Eio.Net.connect` and a single fiber for send/recv.

2. Auto batching
   - Group requests by type.
   - Flush batch when size limit or latency expires.
   - Use `Eio.Time` for the latency window.

3. Id generation
   - Provide `id ()` that returns time sortable 128 bit ids.
   - Use a stable library or implement a simple ULID in OCaml.

4. CLI REPL
   - Parse commands:
     - `create_accounts` with fields
     - `create_transfers` with fields
     - `lookup_accounts` with ids
     - `lookup_transfers` with ids
   - Print results as JSON.

5. Docs
   - `docs/client.md` with code examples and CLI usage.

## Checklists
- [ ] Client batches requests automatically
- [ ] CLI can create and lookup objects
- [ ] Ids are stable and collision resistant

## Notes
This keeps the client experience similar to TigerBeetle but minimal.
