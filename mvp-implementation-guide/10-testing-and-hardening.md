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
     - invalid id (`0`, max u128)
     - invalid ledger/code (`0`)
     - invalid imported timestamp rules
     - account flags mutual exclusion and linked-chain semantics
   - Create transfers:
     - ok
     - missing accounts
     - ledger mismatch
     - insufficient funds
     - invalid transfer flags/mutual exclusion
     - invalid pending_id flows
     - closing and balancing semantics
   - Pending and post/void/timeout rules
   - Query/filter validation tests for all query endpoints

2. Property tests
   - Generate random batches of accounts/transfers.
   - Apply batch to state.
   - Encode to WAL, replay WAL.
   - Verify resulting state equals original.
   - Re-derive replies from replayed prepares and compare with original replies.
   - Verify deterministic ordering of query replies.

3. Crash recovery tests
   - Run server.
   - Send a batch.
   - Kill process mid write.
   - Restart and validate state.
   - Include crash around snapshot rename and validate directory-fsync durability rules.

4. Metrics
   - Counters: requests, events, errors, session_evictions, retries.
   - Gauges: WAL size, snapshot size, batch size.
   - Expose metrics via a simple HTTP endpoint or log.

5. Logging
   - Structured log per batch: timestamp, batch size, duration.
   - Log WAL checksum failures and recovery actions.

6. Documentation
   - `docs/testing.md` lists how to run tests and expected outputs.
   - Include deterministic seed replay instructions for failing property tests.

## Checklists
- [ ] Replay determinism tests pass
- [ ] Crash tests pass on repeated runs
- [ ] Logging is consistent and parseable
- [ ] All TigerBeetle-aligned constraints and flags have unit-test coverage
- [ ] Session lifecycle and retry behavior has integration-test coverage

## Notes
TigerBeetle uses deterministic simulation. Here we use a smaller but focused
test set to validate core invariants.
