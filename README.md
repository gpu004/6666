# TigerBeetle in OCaml

This repository contains a prototype-grade OCaml compatibility build inspired by
TigerBeetle, with the upstream Zig codebase kept in `repo/` as the reference.

This is not a full reimplementation. Treat it as a behavior and tooling spike:

- core ledger API only
- server + CLI compatibility surface
- partial blackbox compatibility
- useful for focused experiments, not production claims

## Repository layout

- `tb_ocaml/`: OCaml implementation
- `repo/`: upstream TigerBeetle submodule
- `benchmarks/`: local comparison harnesses
- `scripts/`: helper scripts outside Dune
- `zig/`: local Zig toolchain used for some upstream/build helper tasks

## Clone

The upstream reference is a submodule:

```sh
git clone --recurse-submodules https://github.com/tusharhqq/6666.git
```

or after cloning:

```sh
git submodule update --init --recursive
```

## Portable shell setup

Commands below assume:

```sh
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"
```

## Requirements

- OCaml `5.4+`
- Dune `3.21+`
- Python `3`
- a Python virtualenv at `$ROOT/.venv_pytests` for the upstream Python blackbox
- a checksum helper at `$ROOT/tb_ocaml/_build_tools/tb_checksum`

Set up the Python env once:

```sh
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"
python3 -m venv .venv_pytests
. .venv_pytests/bin/activate
pip install -U pip pytest tigerbeetle
```

## Dune workflow

```sh
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT/tb_ocaml"
dune build
dune test
dune runtest
dune build @doc
```

Supporting tools used here:

- `Dune` for build, test, docs, and cram orchestration
- `Alcotest` for deterministic unit tests
- `QCheck` for property tests
- `bisect_ppx` for coverage
- `ocamlformat` for formatting
- `ppx_inline_test` when the local switch can support it
- optional `junit_alcotest` if CI needs JUnit XML

## Formatting and warnings

Formatting is pinned by `tb_ocaml/.ocamlformat`.

```sh
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT/tb_ocaml"
ocamlformat --check $(find . -path './_build' -prune -o \( -name '*.ml' -o -name '*.mli' \) -print)
ocamlformat -i $(find . -path './_build' -prune -o \( -name '*.ml' -o -name '*.mli' \) -print)
```

Warnings are strict in `tb_ocaml/dune`:

- `-w +A-41-42-70`
- `-warn-error +A-41-42-70`

## CI baseline

The main OCaml CI workflow is `.github/workflows/tb_ocaml_ci.yml`. It runs:

```sh
opam install . --deps-only --with-test --with-doc
dune build
dune build @doc
dune runtest
ocamlformat --check $(find . -path './_build' -prune -o \( -name '*.ml' -o -name '*.mli' \) -print)
```

## Interfaces and docs

Every public library module now has an `.mli`:

- `tb_ocaml/lib/u128.mli`
- `tb_ocaml/lib/types.mli`
- `tb_ocaml/lib/multibatch.mli`
- `tb_ocaml/lib/codec.mli`
- `tb_ocaml/lib/state.mli`
- `tb_ocaml/lib/checksum.mli`
- `tb_ocaml/lib/repl.mli`
- `tb_ocaml/lib/server.mli`

Docs are generated from the same Dune package:

```sh
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT/tb_ocaml"
dune build @doc
```

Generated HTML:

- `tb_ocaml/_build/default/_doc/_html/`

The package landing page is `tb_ocaml/tb_ocaml.mld`.

## Run the OCaml version

```sh
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT/tb_ocaml"
dune exec ./bin/tigerbeetle.exe -- version
TB_OCAML_CHECKSUM_BIN="$ROOT/tb_ocaml/_build_tools/tb_checksum" \
  dune exec ./bin/tigerbeetle.exe -- format --cluster=0 --replica=0 --replica-count=1 --development /tmp/0_0.tigerbeetle
TB_OCAML_CHECKSUM_BIN="$ROOT/tb_ocaml/_build_tools/tb_checksum" \
  dune exec ./bin/tigerbeetle.exe -- start --development=true --addresses=0 /tmp/0_0.tigerbeetle
```

Then in another shell:

```sh
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT/tb_ocaml"
TB_OCAML_CHECKSUM_BIN="$ROOT/tb_ocaml/_build_tools/tb_checksum" \
  dune exec ./bin/tigerbeetle.exe -- repl --cluster=0 --addresses=<port> --command="create_accounts id=17 code=718 ledger=1"
TB_OCAML_CHECKSUM_BIN="$ROOT/tb_ocaml/_build_tools/tb_checksum" \
  dune exec ./bin/tigerbeetle.exe -- repl --cluster=0 --addresses=<port> --command="lookup_accounts id=17"
```

## Tests

Main test layers:

- `tb_ocaml/tests/unit_tests.ml`: Alcotest unit tests
- `tb_ocaml/tests/property_tests.ml`: QCheck property tests
- `tb_ocaml/tests/cli.t`: cram CLI tests
- `tb_ocaml/tests/core_blackbox.py`: repo-local compatibility smoke test

The unit suite currently covers:

- codec and multibatch round-trips
- status/flag rendering in `Types`
- REPL parsing in `Repl`
- basic create/lookup/query behavior in `State`

Run them with Dune:

```sh
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT/tb_ocaml"
dune test
dune runtest
```

The cram layer checks real CLI behavior:

- `--help`
- `inspect --help`
- `version`
- `version --verbose`
- `format`
- unsupported `inspect` subcommands

## Upstream Python blackbox against OCaml

This runs the original upstream Python test file from `repo/` against the OCaml
server:

```sh
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT/tb_ocaml"
dune build @upstream-python-blackbox
```

Current status: it still fails at upstream `test_create_accounts`. That means
the project is not yet a trusted compatibility layer.

## Coverage

Coverage is wired through `bisect_ppx`, but in this local switch the available
`bisect_ppx` conflicts with OCaml `5.4.0`. The authoritative path is CI in
`.github/workflows/tb_ocaml_coverage.yml`.

When coverage is available, treat it as a blind-spot finder, not a percentage
goal. Prioritize:

- `tb_ocaml/lib/state.ml`
- `tb_ocaml/lib/codec.ml`
- `tb_ocaml/lib/multibatch.ml`

## Benchmarking caveat

`benchmarks/compare_server_cli.py` is useful for comparing the current
prototype workflow, not normalized engine throughput.

The current OCaml implementation still contains prototype scaffolding that
materially affects benchmark results:

- `tb_ocaml/lib/checksum.ml` shells out to an external checksum helper per call
- `tb_ocaml/lib/server.ml` serializes stateful work behind one mutex
- `tb_ocaml/lib/state.ml` persists snapshots with `Marshal`

Treat benchmark output as "how this spike behaves today", not "how an OCaml
TigerBeetle would perform after architectural cleanup."

## Current limits

- Persistence is temporary test scaffolding, not a durable format.
- Compatibility coverage is still shallow relative to upstream behavior.
- Some upstream blackbox suites remain blocked by environment/tooling.
- Inline tests are still blocked in this local macOS arm64 OCaml `5.4` switch.
