# tb_ocaml

Small OCaml compatibility build inspired by TigerBeetle.

## What it contains

- a Dune-based OCaml executable in `bin/tigerbeetle.ml`
- core state and codec logic in `lib/`
- a black-box compatibility smoke test in `tests/core_blackbox.py`
- a local Zig checksum helper source in `ocaml_tb_checksum.zig` that imports upstream checksum code from `../repo`

## Requirements

- OCaml 5.4+
- Dune 3.21+
- Python 3
- Zig available locally if the checksum helper needs to be rebuilt

## Build and test

```sh
dune build
python3 tests/core_blackbox.py
```

## Important note about `repo/`

`checksum_build.zig` compiles `../repo/src/ocaml_tb_checksum.zig`, so the outer repository must have the `repo/` submodule initialized:

```sh
git submodule update --init --recursive
```
