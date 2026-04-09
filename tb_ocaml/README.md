# tb_ocaml

Prototype-grade TigerBeetle-compatible server and CLI in OCaml.

This package is a spike, not a finished compatibility layer. It aims to make a
small OCaml core testable and repeatable through Dune while comparing selected
behavior against the upstream Zig project in `../repo`.

## Scope

- server + CLI surface
- core ledger API focus
- Dune-centered build/test/docs
- partial blackbox compatibility
- prototype persistence and protocol handling

## Portable shell setup

Commands below assume:

```sh
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT/tb_ocaml"
```

## Requirements

- OCaml `5.4+`
- Dune `3.21+`
- Python `3`
- checksum helper at `$ROOT/tb_ocaml/_build_tools/tb_checksum`
- Python venv at `$ROOT/.venv_pytests` for the upstream Python blackbox

Example Python env setup:

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

Preferred supporting tools:

- `Dune`
- `Alcotest`
- `QCheck`
- `bisect_ppx`
- `ocamlformat`
- `ppx_inline_test` when the local switch supports it
- optional `junit_alcotest`

## Formatting and warnings

```sh
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT/tb_ocaml"
ocamlformat --check $(find . -path './_build' -prune -o \( -name '*.ml' -o -name '*.mli' \) -print)
ocamlformat -i $(find . -path './_build' -prune -o \( -name '*.ml' -o -name '*.mli' \) -print)
```

Warnings are strict via `dune`:

- `-w +A-41-42-70`
- `-warn-error +A-41-42-70`

## Interfaces and docs

Every public library module has an `.mli`:

- `lib/u128.mli`
- `lib/types.mli`
- `lib/multibatch.mli`
- `lib/codec.mli`
- `lib/state.mli`
- `lib/checksum.mli`
- `lib/repl.mli`
- `lib/server.mli`

Build docs with:

```sh
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT/tb_ocaml"
dune build @doc
```

Generated HTML:

- `_build/default/_doc/_html/`

Package landing page:

- `tb_ocaml.mld`

## Run

```sh
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT/tb_ocaml"
dune exec ./bin/tigerbeetle.exe -- version
TB_OCAML_CHECKSUM_BIN="$ROOT/tb_ocaml/_build_tools/tb_checksum" \
  dune exec ./bin/tigerbeetle.exe -- format --cluster=0 --replica=0 --replica-count=1 --development /tmp/0_0.tigerbeetle
TB_OCAML_CHECKSUM_BIN="$ROOT/tb_ocaml/_build_tools/tb_checksum" \
  dune exec ./bin/tigerbeetle.exe -- start --development=true --addresses=0 /tmp/0_0.tigerbeetle
```

Then:

```sh
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT/tb_ocaml"
TB_OCAML_CHECKSUM_BIN="$ROOT/tb_ocaml/_build_tools/tb_checksum" \
  dune exec ./bin/tigerbeetle.exe -- repl --cluster=0 --addresses=<port> --command="create_accounts id=17 code=718 ledger=1"
```

## Tests

Layers:

- `tests/unit_tests.ml`: Alcotest
- `tests/property_tests.ml`: QCheck
- `tests/cli.t`: cram
- `tests/core_blackbox.py`: local blackbox smoke harness

Current direct unit coverage includes:

- codec and multibatch round-trips
- status and flag naming in `Types`
- REPL parsing in `Repl`
- basic create/lookup/query behavior in `State`

Run:

```sh
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT/tb_ocaml"
dune test
dune runtest
```

The cram suite checks:

- `--help`
- `inspect --help`
- `version`
- `version --verbose`
- `format`
- unsupported `inspect` subcommands

## Upstream Python blackbox

Run the original upstream Python test file against the OCaml server:

```sh
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT/tb_ocaml"
dune build @upstream-python-blackbox
```

Current status: this still fails at upstream `test_create_accounts`.

## Coverage

Coverage is configured via `bisect_ppx`, but the current local OCaml `5.4`
switch does not solve cleanly with the available `bisect_ppx` package in this
environment. Coverage is therefore checked in CI rather than claimed locally.

## Prototype notes

These implementation choices are acceptable for the spike, but they should not
be mistaken for long-term architecture:

- `lib/checksum.ml`: external helper process per checksum call
- `lib/server.ml`: one mutex around shared stateful request handling
- `lib/state.ml`: `Marshal` snapshot persistence

Those choices are especially important when reading benchmark numbers. They
mostly measure scaffolding costs today.

## Inline tests status

`ppx_inline_test.v0.17.1` is the right package for OCaml `5.4`, but this local
macOS arm64 switch still crashes building transitive dependencies such as
`ppx_derivers`, `ocaml-compiler-libs`, and `jane-street-headers` with
`signalled -7`. So inline tests are documented as intended, not active.
