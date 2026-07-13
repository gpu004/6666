# 6666

An experimental OCaml implementation of the TigerBeetle ledger database. The
upstream TigerBeetle Zig repository is pinned as a Git submodule at
`path/to/tigerbeetle` for source and behavior reference.

`ocam/` is a full copy of that pinned revision with only
`src/state_machine.zig` replaced by `src/state_machine.ml`. See
[`ocam/OCAML_REWRITE.md`](ocam/OCAML_REWRITE.md) for verification commands,
benchmarking, the integration boundary, and remaining equivalence work.

See [OCAML_REWRITE_PLAN.md](OCAML_REWRITE_PLAN.md) for the component-by-component
rewrite, compatibility, benchmarking, and analysis plan.


The experimental version is written in ocam folder, library usage guide

I plan to use the janestreet ocaml ecosystem libs, instead of normal ocaml, oxcaml, core, base, async, magic-trace etc etc

use the following
https://github.com/janestreet/async
https://github.com/janestreet/magic-trace
https://github.com/janestreet/core
https://github.com/oxcaml/oxcaml
https://github.com/oxcaml/odoc
https://github.com/oxcaml/ocaml-lsp
https://github.com/oxcaml/ocamlformat
