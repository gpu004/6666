# tb_ocaml

Small OCaml TigerBeetle-compatible server and CLI.

Use Dune as the primary workflow:

```sh
dune build
dune test
dune runtest
```

## What it contains

- a Dune-based executable in `bin/tigerbeetle.ml`
- core protocol/state logic in `lib/`
- a repo-local compatibility smoke test wired to the `@runtest` alias
- an upstream Python blackbox runner wired to the `@upstream-python-blackbox` alias
- a checksum helper source in `ocaml_tb_checksum.zig` that imports upstream code from `../repo`

## Requirements

- OCaml `5.4+`
- Dune `3.21+`
- Python `3`
- A checksum helper present at `/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/_build_tools/tb_checksum`
- For the upstream Python blackbox alias: a Python virtualenv at `/Users/blouse_man/Downloads/coding/github/6666/.venv_pytests` with `pytest` and `tigerbeetle` installed

Set up the Python test environment once:

```sh
cd /Users/blouse_man/Downloads/coding/github/6666
python3 -m venv .venv_pytests
. .venv_pytests/bin/activate
pip install -U pip pytest tigerbeetle
```

## Build

```sh
cd /Users/blouse_man/Downloads/coding/github/6666/tb_ocaml
dune build
```

## Run

Use Dune to execute the built binary:

```sh
cd /Users/blouse_man/Downloads/coding/github/6666/tb_ocaml
dune exec ./bin/tigerbeetle.exe -- version
TB_OCAML_CHECKSUM_BIN=/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/_build_tools/tb_checksum \
  dune exec ./bin/tigerbeetle.exe -- format --cluster=0 --replica=0 --replica-count=1 --development /tmp/0_0.tigerbeetle
TB_OCAML_CHECKSUM_BIN=/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/_build_tools/tb_checksum \
  dune exec ./bin/tigerbeetle.exe -- start --development=true --addresses=0 /tmp/0_0.tigerbeetle
```

`start` prints the chosen port. Use that port with `repl`:

```sh
cd /Users/blouse_man/Downloads/coding/github/6666/tb_ocaml
TB_OCAML_CHECKSUM_BIN=/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/_build_tools/tb_checksum \
  dune exec ./bin/tigerbeetle.exe -- repl --cluster=0 --addresses=<port> --command="create_accounts id=17 code=718 ledger=1"
TB_OCAML_CHECKSUM_BIN=/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/_build_tools/tb_checksum \
  dune exec ./bin/tigerbeetle.exe -- repl --cluster=0 --addresses=<port> --command="lookup_accounts id=17"
```

## Test the OCaml version

Categories:

- Unit tests: `tests/unit_tests.ml` using Alcotest
- Property tests: `tests/property_tests.ml` using QCheck
- Cram / CLI tests: `tests/cli.t`
- Blackbox smoke test: `tests/core_blackbox.py`

```sh
cd /Users/blouse_man/Downloads/coding/github/6666/tb_ocaml
dune test
```

Equivalent:

```sh
cd /Users/blouse_man/Downloads/coding/github/6666/tb_ocaml
dune runtest
```

`dune test` runs the Alcotest and QCheck executables.

`dune runtest` runs:

- the Alcotest unit suite
- the QCheck property suite
- the cram CLI test
- the repo-local blackbox smoke harness from `tests/core_blackbox.py`

As of April 9, 2026, both commands pass in this workspace.

Run the original upstream Python blackbox file against the OCaml server:

```sh
cd /Users/blouse_man/Downloads/coding/github/6666/tb_ocaml
dune build @upstream-python-blackbox
```

That alias runs:

- the upstream file `/Users/blouse_man/Downloads/coding/github/6666/repo/src/clients/python/tests/test_basic.py`
- against the OCaml server from `/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/_build/default/bin/tigerbeetle.exe`
- using `pytest` from `/Users/blouse_man/Downloads/coding/github/6666/.venv_pytests`

As of April 9, 2026, this alias reaches the real upstream Python blackbox suite and currently fails at `test_create_accounts`, where the upstream client expects one `CreateAccountResult` and the OCaml server still returns `[]`.

## Inline tests status

Inline tests are not enabled yet in this switch. The blocker is not the repo layout; it is the local opam environment. Installing `ppx_inline_test` failed even with `-j1`:

```sh
opam install -y ppx_inline_test
opam install -y -j1 ppx_inline_test
```

Both commands failed with `signal 7` while building `ppx_derivers`, `ocaml-compiler-libs`, and `jane-street-headers`. Once that switch issue is fixed, the next step is to add `ppx_inline_test` under Dune and move small invariants next to modules such as `lib/u128.ml` and `lib/multibatch.ml`.

## Important note about `repo/`

`checksum_build.zig` compiles `../repo/src/ocaml_tb_checksum.zig`, so the outer repository must have the `repo/` submodule initialized:

```sh
cd /Users/blouse_man/Downloads/coding/github/6666
git submodule update --init --recursive
```

## Current status of upstream blackbox suites

The OCaml server is directly runnable through Dune and the local Dune smoke test passes. The upstream-facing Dune alias today is `@upstream-python-blackbox`. The other original upstream client suites are still blocked in this workspace by the upstream native-client build environment.
