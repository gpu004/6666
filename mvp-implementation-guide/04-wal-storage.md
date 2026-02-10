# Step 04 - WAL storage

Goal: Implement an append only WAL with fsync and replay.

## Deliverables
- WAL module with append, flush, and replay
- WAL record format with checksums
- WAL reader for recovery

## Files to create
- `src/storage/wal.mli`
- `src/storage/wal.ml`
- `src/storage/wal_reader.ml`
- `test/wal_test.ml`

## Tasks
1. Define WAL record format
   - Reuse the header from Step 03.
   - Payload is encoded request (prepare) only.
   - Reply data is not WAL-persisted; it is derived deterministically by state machine execution.
   - Record type in header indicates `prepare`.

2. WAL API design
   - `val open_file : string -> t`
   - `val append : t -> Cstruct.t -> (unit, error) result`
   - `val fsync : t -> (unit, error) result`
   - `val close : t -> unit`
   - `val replay : t -> (record -> unit) -> (unit, error) result`

3. Implement append
   - Open file with `O_CREAT`, `O_APPEND`, `O_RDWR`.
   - Write header then payload using `Unix.write` in a loop.
   - Fsync per batch for MVP durability.

4. Implement replay
   - Seek to start.
   - Read header, then payload length.
   - Validate checksum.
   - Decode payload and pass to callback.
   - Stop cleanly on EOF.
   - Ignore trailing partial record (crash-tail tolerance).

5. Add corruption handling
   - If checksum fails, stop replay and return error.
   - If header fields are invalid (size/cluster/protocol/command), stop and return error.

6. Tests
   - Append N batches and replay.
   - Corrupt a byte and ensure checksum failure is detected.
   - Re-execute replayed prepares and ensure derived responses match original execution.

## Checklists
- [ ] WAL append writes a complete record or fails
- [ ] Replay ignores trailing partial record
- [ ] Checksum failure is detectable
- [ ] WAL stores prepares only (no persisted replies)

## Notes
TigerBeetle uses a more complex WAL for replication. The MVP uses a simpler
append only log but keeps the same strict validation idea.
