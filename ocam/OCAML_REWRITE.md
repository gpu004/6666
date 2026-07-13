# OCaml ledger state machine

This directory is a copy of pinned TigerBeetle revision
`97c7a8ef385270ebe0e1b75959d3d21d134629df`. The copied
`src/state_machine.zig` is replaced by `src/state_machine.ml` and its interface.
Every other copied TigerBeetle file remains at the pinned revision. The original
submodule at `../path/to/tigerbeetle` is the Zig behavior oracle.

## Commands

```sh
opam install . --deps-only --with-test
opam exec -- dune build
opam exec -- dune runtest
opam exec -- dune build @bench
```

The benchmark reports operations/second, per-batch latency, total allocated
words, and allocated words per operation.

## Boundary and current coverage

The OCaml module is deterministic and synchronous. Replication supplies commit
timestamps; Async belongs in the adapter, not the core. The copied Zig LSM and
VSR source is unchanged, but a C-ABI adapter and wire-compatible 128-byte codecs
are still required before the copied Zig server can link to this OCaml module.

Current scenarios cover validation precedence, account creation, single-phase
and pending transfers, posting, voiding, balance changes, lookups, queries, and
linked rollback. Full differential equivalence still requires the entire Zig
test corpus, exact numeric result-code encoding, CDC/history objects, imported
edge cases, query validation, expiry batching, and deprecated operations.
