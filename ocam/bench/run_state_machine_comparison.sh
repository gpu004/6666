#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
zig=${ZIG:-"$repository_root/path/to/tigerbeetle/zig/zig"}

(
  cd "$repository_root/ocam"
  opam exec -- dune exec bench/state_machine_bench.exe
)

(
  cd "$repository_root"
  "$zig" test -O ReleaseSafe -target aarch64-macos.15.0 \
    --dep stdx --dep test_options --dep vsr_options \
    -Mroot=tigerbeetle_state_machine_bench.zig \
    -Mstdx=path/to/tigerbeetle/src/stdx/stdx.zig \
    -Mtest_options=bench/test_options.zig \
    -Mvsr_options=bench/vsr_options.zig
)
