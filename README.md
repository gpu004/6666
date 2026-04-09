# TigerBeetle in OCaml

This repository is a prototype-grade OCaml recreation inspired by TigerBeetle, with the upstream Zig TigerBeetle repository kept here as the reference implementation.

This project does not attempt to reimplement the whole TigerBeetle system. It only builds partial functionality, compares selected components against the upstream project, and uses those focused comparisons to guide the OCaml prototype.

## Prototype scope

- This repository is a prototype only.
- The OCaml code implements partial functionality rather than the full TigerBeetle feature set.
- The work here compares specific parts of the upstream project, not the entire system end to end.
- The current focus is on selected CLI, server, protocol, state, testing, and benchmark surfaces that are practical to reproduce and evaluate in OCaml.

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

## Formatting

Formatting is enforced with `ocamlformat` and a project-local config at:

- `/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/.ocamlformat`

Local commands:

```sh
cd /Users/blouse_man/Downloads/coding/github/6666/tb_ocaml
ocamlformat --check $(find . -path './_build' -prune -o \( -name '*.ml' -o -name '*.mli' \) -print)
ocamlformat -i $(find . -path './_build' -prune -o \( -name '*.ml' -o -name '*.mli' \) -print)
```

The baseline CI workflow runs the exact same core checks every time in:

- `/Users/blouse_man/Downloads/coding/github/6666/.github/workflows/tb_ocaml_ci.yml`

The sequence is:

```sh
opam install . --deps-only --with-test
dune build
dune runtest
ocamlformat --check $(find . -path './_build' -prune -o \( -name '*.ml' -o -name '*.mli' \) -print)
```

## Warnings

Compiler warnings are strict by default in:

- `/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/dune`

The project now builds with:

- `-w +A-41-42-70`
- `-warn-error +A-41-42-70`

That means warnings fail the build, with these narrow exceptions:

- warning `70` is excluded so the project does not force placeholder `.mli` files for every module
- warnings `41` and `42` are excluded because they are about record-label disambiguation and compatibility with very old OCaml syntax, not current correctness in this OCaml `5.4` codebase

This keeps warning noise near zero while still treating unused values, non-exhaustive matches, fragile pattern matches, and similar issues as CI-breaking problems.

CI enforcement is in:

- `/Users/blouse_man/Downloads/coding/github/6666/.github/workflows/tb_ocaml_ci.yml`

## Interfaces

Important library modules now have explicit `.mli` files:

- `/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/lib/u128.mli`
- `/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/lib/types.mli`
- `/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/lib/multibatch.mli`
- `/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/lib/codec.mli`
- `/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/lib/state.mli`

The biggest quality change is that `U128.t` and `State.t` are now abstract to callers. That stops accidental construction or mutation of internal state from the rest of the codebase and keeps the effectful server layer from reaching through state representation details.

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

Because `dune runtest` includes the cram test in `tb_ocaml/tests/cli.t`, the baseline CI job also exercises the user-facing CLI surface instead of only the pure OCaml test executables.

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

## Coverage

Coverage support is wired into the OCaml Dune stanzas with `bisect_ppx` instrumentation on:

- `/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/lib/dune`
- `/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/bin/dune`

The intended coverage commands are:

```sh
cd /Users/blouse_man/Downloads/coding/github/6666/tb_ocaml
BISECT_SILENT=YES dune runtest --instrument-with bisect_ppx --force
bisect-ppx-report summary
bisect-ppx-report html
```

That produces the HTML report in `/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/_coverage/index.html`.

Current local blocker:

- the current developer switch is OCaml `5.4.0`
- `opam show bisect_ppx` currently resolves to `2.8.3`
- that package depends on `ppxlib < 0.36.0`
- on this machine that conflicts with OCaml `5.4.0`, so `opam install bisect_ppx` does not solve in the current switch

Because of that, the repository now checks coverage in CI instead of pretending local coverage works on this switch. The workflow is:

- `/Users/blouse_man/Downloads/coding/github/6666/.github/workflows/tb_ocaml_coverage.yml`

That job runs coverage on OCaml `5.3.0`, generates both the terminal summary and the HTML report, and uploads the report as an artifact.

Use coverage to find untested branches in core logic such as:

- request/reply codec paths in `/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/lib/codec.ml`
- multibatch edge cases in `/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/lib/multibatch.ml`
- validation and ledger state transitions in `/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml/lib/state.ml`

The target is not fake `100%`. The useful bar is high coverage on core library logic, with lower expectations on CLI glue, wrappers, and mechanical entrypoints.

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
