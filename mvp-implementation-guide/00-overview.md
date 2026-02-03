# OCaml MVP Implementation Guide (TigerBeetle Inspired)

This guide breaks the MVP into numbered steps. Each step is its own file with
concrete tasks, deliverables, and checklists. The MVP is single replica, single
threaded, WAL backed, and strictly serializable. We take design inspiration from
TigerBeetle but implement in an OCaml-first way.

## Target MVP scope
- Single replica, single process
- Single threaded state machine
- Append only WAL and crash recovery
- Accounts and Transfers with double entry invariants
- Idempotent requests with client generated ids
- Batching at client and server
- Minimal query surface

## Recommended step order
1. 01-repo-and-conventions.md
2. 02-domain-types-and-api.md
3. 03-binary-codec-and-wire-format.md
4. 04-wal-storage.md
5. 05-state-machine.md
6. 06-batching-and-execution.md
7. 07-snapshot-and-recovery.md
8. 08-server-and-protocol.md
9. 09-client-and-cli.md
10. 10-testing-and-hardening.md

## Directory layout assumption
We assume a dune project in the repo root with this structure:

- src/
  - core/
  - codec/
  - storage/
  - engine/
  - server/
  - client/
- test/
- bin/

Adjust paths if you choose another layout.
