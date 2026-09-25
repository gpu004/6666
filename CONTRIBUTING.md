# Contributing

Read [`README.md`](README.md) and [`AGENTS.md`](AGENTS.md) first. The pinned
TigerBeetle tree at `path/to/tigerbeetle` is the behavior oracle; do not edit
or advance it as part of a change to the OCaml core.

## Toolchain

The OCaml code is built with the OxCaml compiler pinned in
`.github/workflows/tb_ocaml_ci.yml`. From `ocam/`:

```sh
opam switch create tigerbeetle-oxcaml oxcaml-compiler.5.2.0minus39 \
  --repos ox=git+https://github.com/oxcaml/opam-repository.git,default
eval "$(opam env --switch tigerbeetle-oxcaml)"
opam install . --deps-only --with-test --with-doc
opam install ocamlformat.0.26.2+ox2
```

## Checks

Run the same commands CI runs before opening a pull request, from `ocam/`:

```sh
opam exec -- dune build
opam exec -- dune build @doc
opam exec -- dune runtest
opam exec -- dune build @bench
opam exec -- dune build @fmt     # or `dune fmt` to rewrite in place
```

The coverage workflow instruments the tests with Bisect PPX and fails when
line coverage drops below the `MINIMUM_COVERAGE` set in
`.github/workflows/tb_ocaml_coverage.yml`. Bisect PPX does not build against
OxCaml's patched `ppxlib`, so that workflow runs on upstream OCaml 5.2 (the core
is Stdlib-only). Reproduce it locally on a standard switch with:

```sh
opam install bisect_ppx
BISECT_FILE="$PWD/_coverage/bisect" \
  opam exec -- dune runtest --instrument-with bisect_ppx --force
opam exec -- bisect-ppx-report summary --coverage-path _coverage
```

## Layout of the OCaml core

| Module | Role |
| --- | --- |
| `U128` | Unsigned 128-bit integers with explicit overflow/underflow results. |
| `Types` | Account, transfer, filter, and status records shared by every module. |
| `Result_code` | Numeric `CreateAccountsResult`/`CreateTransfersResult` codes. |
| `Timeline` | Append-only, timestamp-ordered index with binary-searched range reads. |
| `Ledger` | Storage, timestamp and per-account indexes, and the rollback journal. |
| `State_machine` | Validation, batch execution, and the public API. |

Keep the core deterministic and synchronous: no Async, storage, clock, or
network dependency. New behavior should be compared against the pinned Zig
`src/state_machine.zig` and its tests, and covered by a scenario in
`ocam/test/state_machine_test.ml` or a property in
`ocam/test/state_machine_property_test.ml`.

## Version control

Contributors use [Jujutsu (`jj`)](https://github.com/jj-vcs/jj) on top of the
Git repository. Set it up once in an existing clone:

```sh
jj git init --colocate
jj git fetch
```

With a colocated repository, Git and `jj` share the working copy, so CI and
GitHub continue to see ordinary Git branches. Inspect `jj status` and
`jj diff` before and after changes, and see the "Commit and push workflow" in
[`AGENTS.md`](AGENTS.md) for how bookmarks are moved and pushed. Plain Git
commands also work if you do not use `jj`; the requirement is that the history
you push consists of coherent commits that do not touch the pinned submodule.

## License

Contributions are accepted under the Apache License 2.0 in [`LICENSE`](LICENSE),
the same license as the upstream TigerBeetle sources this repository derives
from.
