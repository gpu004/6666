# Tiger Metal in OCaml

This repository contains an OCaml TigerBeetle-compatible server/CLI and the upstream Zig TigerBeetle repository used as the reference implementation.

The OCaml workflow is Dune-first:

```sh
dune build
dune test
dune runtest
```

## Repository layout

- `tb_ocaml/`: the OCaml implementation.
- `repo/`: the upstream TigerBeetle repository as a submodule.
- `zig/`: the local Zig `0.14.1` toolchain used by the upstream repo.
- `benchmarks/`: local comparison benchmarks.
- `scripts/`: older helper scripts. Prefer the Dune aliases in `tb_ocaml/`.

## Clone correctly

Because `repo/` is a submodule, a fresh clone needs one of these:

```sh
git clone --recurse-submodules https://github.com/tusharhqq/6666.git
```

or, after cloning:

```sh
git submodule update --init --recursive
```

## Requirements

- OCaml `5.4+`
- Dune `3.21+`
- Python `3`
- For the upstream Python blackbox alias: a Python virtualenv at `.venv_pytests` with `pytest` and `tigerbeetle` installed
- For server-starting commands: a checksum helper at `tb_ocaml/_build_tools/tb_checksum`

Set up the upstream Python test environment once:

```sh
cd /Users/blouse_man/Downloads/coding/github/6666
python3 -m venv .venv_pytests
. .venv_pytests/bin/activate
pip install -U pip pytest tigerbeetle
```

## Build the OCaml version

```sh
cd /Users/blouse_man/Downloads/coding/github/6666/tb_ocaml
dune build
```

## Run the OCaml version

Use Dune to run the built executable:

```sh
cd /Users/blouse_man/Downloads/coding/github/6666/tb_ocaml
dune exec ./bin/tigerbeetle.exe -- version
TB_OCAML_CHECKSUM_BIN=/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/_build_tools/tb_checksum \
  dune exec ./bin/tigerbeetle.exe -- format --cluster=0 --replica=0 --replica-count=1 --development /tmp/0_0.tigerbeetle
TB_OCAML_CHECKSUM_BIN=/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/_build_tools/tb_checksum \
  dune exec ./bin/tigerbeetle.exe -- start --development=true --addresses=0 /tmp/0_0.tigerbeetle
```

The `start` command prints the chosen TCP port on stdout. In another shell, use `repl` against that port:

```sh
cd /Users/blouse_man/Downloads/coding/github/6666/tb_ocaml
TB_OCAML_CHECKSUM_BIN=/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/_build_tools/tb_checksum \
  dune exec ./bin/tigerbeetle.exe -- repl --cluster=0 --addresses=<port> --command="create_accounts id=17 code=718 ledger=1"
TB_OCAML_CHECKSUM_BIN=/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/_build_tools/tb_checksum \
  dune exec ./bin/tigerbeetle.exe -- repl --cluster=0 --addresses=<port> --command="lookup_accounts id=17"
```

## Run tests against the OCaml version

### Test categories

- Unit tests: Alcotest executable at `/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/tests/unit_tests.ml`
- Property tests: QCheck executable at `/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/tests/property_tests.ml`
- Cram / CLI tests: Dune cram file at `/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/tests/cli.t`
- Blackbox smoke test: repo-local Python harness at `/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/tests/core_blackbox.py`

### Dune test aliases

```sh
cd /Users/blouse_man/Downloads/coding/github/6666/tb_ocaml
dune test
```

`dune test` runs the OCaml-native deterministic suites:

- Alcotest unit tests
- QCheck property tests

Run the full Dune `@runtest` alias:

```sh
cd /Users/blouse_man/Downloads/coding/github/6666/tb_ocaml
dune runtest
```

`dune runtest` runs everything above plus:

- the cram CLI test in `tb_ocaml/tests/cli.t`
- the repo-local compatibility harness in `tb_ocaml/tests/core_blackbox.py`

As of April 9, 2026, both `dune test` and `dune runtest` pass in this workspace.

### Run the upstream Python blackbox file against the OCaml server

The upstream blackbox file is:

- `/Users/blouse_man/Downloads/coding/github/6666/repo/src/clients/python/tests/test_basic.py`

Use the Dune alias:

```sh
cd /Users/blouse_man/Downloads/coding/github/6666/tb_ocaml
dune build @upstream-python-blackbox
```

This alias starts the OCaml server, exports `TB_ADDRESS`, copies the upstream Python test to a temp directory, and runs it with `pytest` from `/Users/blouse_man/Downloads/coding/github/6666/.venv_pytests`.

As of April 9, 2026, this command runs the original upstream Python blackbox file successfully against the OCaml server, but the test suite fails at `test_create_accounts` because the OCaml server still returns `[]` where that upstream client path expects one `CreateAccountResult`.

### Inline tests status

Inline tests are not wired yet in this switch. The concrete blocker is `ppx_inline_test`: both

```sh
opam install -y ppx_inline_test
opam install -y -j1 ppx_inline_test
```

failed on this machine with `signal 7` while building transitive dependencies `ppx_derivers`, `ocaml-compiler-libs`, and `jane-street-headers`. So the repository is now split into unit, property, cram, and blackbox layers under Dune, but the inline-test layer is documented as blocked by the current opam environment rather than partially enabled.

### Benchmark OCaml vs Zig on the shared CLI/server surface

```sh
cd /Users/blouse_man/Downloads/coding/github/6666
python3 benchmarks/compare_server_cli.py --accounts 1000 --batch-size 200 --iterations 3
```

## Original upstream blackbox tests

The upstream blackbox-style tests in `repo/` are:

- `/Users/blouse_man/Downloads/coding/github/6666/repo/src/integration_tests.zig`
- `/Users/blouse_man/Downloads/coding/github/6666/repo/src/clients/python/tests/test_basic.py`
- `/Users/blouse_man/Downloads/coding/github/6666/repo/src/clients/go/tb_client_test.go`
- `/Users/blouse_man/Downloads/coding/github/6666/repo/src/clients/rust/tests/tests.rs`
- `/Users/blouse_man/Downloads/coding/github/6666/repo/src/clients/node/src/test.ts`
- `/Users/blouse_man/Downloads/coding/github/6666/repo/src/clients/dotnet/TigerBeetle.Tests/IntegrationTests.cs`
- `/Users/blouse_man/Downloads/coding/github/6666/repo/src/clients/java/src/test/java/com/tigerbeetle/IntegrationTest.java`

## Current limitation on running all upstream tests directly

Running the original upstream suites directly against the OCaml server is the correct long-term target, but it is not fully wired up in this workspace yet:

- The upstream repo pins Zig `0.14.1` and currently does not build cleanly on this macOS setup, so the exact native client artifacts expected by the Go, Rust, Node, .NET, and Java suites are not all available yet.
- The checksum helper used by the OCaml server is still an external Zig-built artifact rather than a native Dune target. In this workspace, the helper already exists at `tb_ocaml/_build_tools/tb_checksum`, which is enough for the Dune workflow above.
- The documented Dune alias for the upstream Python suite is a faithful run of the original upstream Python blackbox file. It is currently a compatibility check that fails honestly on behavior, not a rewritten test.

The commands above document the current reproducible Dune-centered path for building the OCaml version, running it, and exercising it with both the local smoke test and the original upstream Python blackbox file.
