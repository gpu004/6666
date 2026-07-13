# 6666

An experimental OCaml rewrite of TigerBeetle's ledger state machine. It keeps
the pinned upstream TigerBeetle source at `path/to/tigerbeetle` as the behavior
reference; do not treat this repository as a replacement TigerBeetle server.

## Layout

- `path/to/tigerbeetle/` — pinned upstream Zig source and behavior oracle.
- `ocam/` — a copy of that pinned revision (`97c7a8ef385270ebe0e1b75959d3d21d134629df`),
  with `src/state_machine.zig` replaced by the OCaml state machine and its
  interface.
- `ocam/src/` — deterministic ledger core, built with Dune and Base.
- `ocam/test/` and `ocam/bench/` — equivalence scenarios and a state-machine
  benchmark. [`BENCHMARK_COMPARISON.md`](BENCHMARK_COMPARISON.md) records the
  workload, the latest local OCaml result, and the current native-baseline
  blocker.

The build and CI use the pinned OxCaml compiler, Jane Street Base, and the
matching OxCaml-compatible formatter. The current core is synchronous and
keeps its state and wire/storage representations explicit; Async belongs at an
integration boundary rather than in the ledger logic.

## Build, test, and benchmark

From `ocam/`:

```sh
opam switch create tigerbeetle-oxcaml oxcaml-compiler.5.2.0minus31 \
  --repos ox=git+https://github.com/oxcaml/opam-repository.git,default
eval "$(opam env --switch tigerbeetle-oxcaml)"
opam install . --deps-only --with-test
opam exec -- dune build
opam exec -- dune runtest
opam exec -- dune build @bench
```

The project requires the OxCaml opam overlay; `oxcaml` in
`ocam/dune-project` makes a standard OCaml switch fail dependency resolution
instead of silently compiling the project with a different toolchain. CI uses
the same pinned OxCaml compiler. The formatting check uses the matching
OxCaml-compatible formatter:

```sh
opam install ocamlformat.0.26.2+ox1
find . -name _build -prune -o \( -name '*.ml' -o -name '*.mli' \) -print0 \
  | xargs -0 opam exec -- ocamlformat --check
```

The OCaml benchmark reports operations per second, per-batch latency, and
allocation figures. Run it from `ocam/`:

```sh
opam exec -- dune exec bench/state_machine_bench.exe
```

The direct Zig baseline is not yet a valid benchmark: its standalone fixture
violates a TigerBeetle internal commit-sequencing invariant after the first
commit. It is therefore not included in the build instructions or presented as
a comparison result.

## Code analysis

DeepSource is configured in [`.deepsource.toml`](.deepsource.toml) for secret
scanning. The pinned upstream source and its local Zig copy are excluded because
they are behavior references rather than maintained rewrite code. After merging
the configuration to the repository's default branch, activate Code Review in
the DeepSource repository settings.

## Documentation

Start with the [ledger-core guide](doc/README.md). It describes the state
machine's public operations, timestamp and linked-batch semantics, and the
boundary between this in-memory core and the unchanged upstream components.

The API reference is generated from the OCaml interface with `odoc`:

```sh
cd ocam
opam exec -- dune build @doc
open _build/default/_doc/_html/index.html
```

The generated HTML is a build artifact and is intentionally not checked in.

## Current boundary

The copied Zig LSM and VSR sources are unchanged. The OCaml state machine does
not yet link into the copied Zig server: that needs a C-ABI adapter and
wire-compatible 128-byte codecs. Current tests cover core account and transfer
operations, linked rollback, lookups, and queries; full TigerBeetle equivalence
still requires the complete Zig corpus and several protocol and edge-case
areas. See [`ocam/OCAML_REWRITE.md`](ocam/OCAML_REWRITE.md) for the detailed
coverage and remaining work.
