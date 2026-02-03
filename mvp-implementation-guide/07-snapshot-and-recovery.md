# Step 07 - Snapshot and recovery

Goal: Add periodic snapshots so recovery is fast and WAL can be truncated.

## Deliverables
- Snapshot file format
- Snapshot writer with atomic replace
- Recovery path: snapshot + WAL replay

## Files to create
- `src/storage/snapshot.mli`
- `src/storage/snapshot.ml`
- `test/recovery_test.ml`

## Tasks
1. Snapshot format
   - Header: magic, version, checksum, counts.
   - Body:
     - accounts array
     - transfers array
     - account_transfers index
     - last_timestamp

2. Snapshot writing
   - Serialize to `snapshot.tmp`.
   - Fsync the temp file.
   - Rename to `snapshot.dat` atomically.

3. Snapshot loading
   - Read and validate header checksum.
   - If invalid, ignore and fall back to WAL only.

4. WAL rotation
   - After snapshot success:
     - close current WAL
     - rename to `wal.old`
     - create fresh WAL
     - optionally delete `wal.old`

5. Recovery algorithm
   - On startup:
     - load snapshot
     - replay WAL
     - verify last_timestamp is monotonic

6. Tests
   - snapshot then replay -> same state
   - corrupted snapshot -> WAL replay still works

## Checklists
- [ ] Snapshot write is atomic
- [ ] Recovery is deterministic
- [ ] WAL rotation does not lose data

## Notes
This is a simpler analogue of TigerBeetle's superblock and grid. It provides
the same checkpoint plus replay idea with fewer moving parts.
