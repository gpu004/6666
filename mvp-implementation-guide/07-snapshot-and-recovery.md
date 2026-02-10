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
   - **Determinism**: When iterating `Hashtbl`, the order is non-deterministic.
     Sort entries by `id` before writing to ensure reproducible snapshots.

2. Snapshot writing
   - Serialize to `snapshot.tmp`.
   - Fsync the temp file.
   - Rename to `snapshot.dat` atomically.
   - **Durability**: Call `fsync` on the containing directory after rename.
     On many filesystems (ext4, XFS), the directory entry update is not durable
     until `fsync(dir_fd)`.

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
- [ ] Snapshot serialization uses deterministic ordering (sorted by id)
- [ ] Directory fsync called after snapshot rename
- [ ] Recovery is deterministic
- [ ] WAL rotation does not lose data

## Notes
This is a simpler analogue of TigerBeetle's superblock and grid. It provides
the same checkpoint plus replay idea with fewer moving parts.
