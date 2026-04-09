# Tiger Metal in OCaml

This repository is a small OCaml rewrite of ideas and compatibility behavior from TigerBeetle, using the upstream Zig codebase as a reference.

## Repository layout

- `tb_ocaml/`: the OCaml implementation you are actively building.
- `repo/`: the upstream TigerBeetle repository, kept as a Git submodule for reference and for upstream Zig modules used by the OCaml checksum helper build.
- `zig/`: a local Zig toolchain checkout used during development.

## Clone correctly

Because `repo/` is a submodule, a fresh clone needs one of these:

```sh
git clone --recurse-submodules https://github.com/tusharhqq/6666.git
```

or, after cloning:

```sh
git submodule update --init --recursive
```

## OCaml project

The runnable project lives in `tb_ocaml/`.

```sh
cd tb_ocaml
dune build
python3 tests/core_blackbox.py
```

The black-box test currently passes in this workspace.
