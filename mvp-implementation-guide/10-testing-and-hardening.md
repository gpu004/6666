# Step 10 - Testing and hardening

Goal: Validate correctness, determinism, and recovery behavior.

## Deliverables
- Unit tests for all invariants
- Property tests for replay
- Crash recovery tests
- Minimal metrics and logging

## Files to create
- `test/state_test.ml`
- `test/wal_test.ml`
- `test/recovery_test.ml`
- `test/codec_test.ml`
- `test/batch_test.ml`
- `docs/testing.md`

## Tasks
1. Unit tests
   - Create accounts:
     - ok
     - exists
   - Create transfers:
     - ok
     - missing accounts
     - ledger mismatch
     - insufficient funds
   - Pending and post/void rules

2. Property tests
   - Generate random batches of accounts/transfers.
   - Apply batch to state.
   - Encode to WAL, replay WAL.
   - Verify resulting state equals original.

3. Crash recovery tests
   - Run server.
   - Send a batch.
   - Kill process mid write.
   - Restart and validate state.

4. Metrics
   - Counters: requests, events, errors.
   - Gauges: WAL size, snapshot size, batch size.
   - Expose metrics via a simple HTTP endpoint or log.

5. Logging
   - Structured log per batch: timestamp, batch size, duration.
   - Log WAL checksum failures and recovery actions.

6. Documentation
   - `docs/testing.md` lists how to run tests and expected outputs.

## Checklists
- [ ] Replay determinism tests pass
- [ ] Crash tests pass on repeated runs
- [ ] Logging is consistent and parseable

## Notes
TigerBeetle uses deterministic simulation. Here we use a smaller but focused
test set to validate core invariants.
