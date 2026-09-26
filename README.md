# 6666

An experimental OCaml rewrite of TigerBeetle's ledger state machine. It keeps
the pinned upstream TigerBeetle source at `path/to/tigerbeetle` as the behavior
reference; do not treat this repository as a replacement TigerBeetle server.

## Layout

- `path/to/tigerbeetle/` — pinned upstream Zig source and behavior oracle.
- `ocam/` — a copy of that pinned revision (`97c7a8ef385270ebe0e1b75959d3d21d134629df`),
  with `src/state_machine.zig` replaced by the OCaml state machine and its
  interface.
  The copied Zig LSM/VSR sources, docs, and clients are kept verbatim so the
  eventual C-ABI adapter can be developed in place; the copied upstream CI
  workflows are not kept because they do not apply to this project.
- `ocam/src/` — deterministic ledger core, built with Dune on the OCaml
  standard library: `U128`, `Types`, `Result_code`, `Ledger`, and the public
  `State_machine` module.
- `ocam/test/` and `ocam/bench/` — equivalence scenarios, QCheck properties,
  and a multi-workload state-machine benchmark.
  [`BENCHMARK_COMPARISON.md`](BENCHMARK_COMPARISON.md) records the workloads
  and the current native-baseline blocker.
- `doc/` — reader's guide and architecture notes for the OCaml core.

The build and CI use the pinned OxCaml compiler and the matching
OxCaml-compatible formatter. The current core is synchronous and keeps its
state and wire/storage representations explicit; Async belongs at an
integration boundary rather than in the ledger logic.

The submodule path `path/to/tigerbeetle` is historical; renaming it would
rewrite the submodule entry, so it is left in place and referenced by name.

## Build, test, and benchmark

From `ocam/`:

```sh
opam switch create tigerbeetle-oxcaml oxcaml-compiler.5.2.0minus39 \
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
opam install ocamlformat.0.26.2+ox2
opam exec -- dune build @fmt   # `dune fmt` rewrites files in place
```

The OCaml benchmark reports operations per second and allocation per
operation for posted transfers, two-phase transfers, successful and failing
linked chains, indexed queries, and pending expiry. Run it from `ocam/`:

```sh
opam exec -- dune exec bench/state_machine_bench.exe
```

The direct Zig baseline is not yet a valid benchmark: its standalone fixture
violates a TigerBeetle internal commit-sequencing invariant after the first
commit. It is therefore not included in the build instructions or presented as
a comparison result.

## Code analysis

CI runs `opam lint`, `dune build @fmt`, the test suite, and a Bisect PPX
coverage job with a minimum line-coverage threshold
(`.github/workflows/tb_ocaml_coverage.yml`). The coverage job also builds the
`odoc` API reference; it runs on upstream OCaml 5.2 because `bisect_ppx` and
`odoc` do not currently build on the OxCaml opam overlay.
CodeRabbit reviews pull requests
(`.coderabbit.yaml`). See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the local
equivalents and the `jj` workflow.

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

## License

The OCaml code and documentation in this repository are licensed under the
Apache License 2.0 ([`LICENSE`](LICENSE)), matching the upstream TigerBeetle
sources copied under `ocam/` (`ocam/LICENSE`) and pinned at
`path/to/tigerbeetle`.
