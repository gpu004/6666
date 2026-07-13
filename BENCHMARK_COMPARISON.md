# State-machine benchmark comparison

This repository benchmarks the pinned TigerBeetle Zig state machine and the
OCaml rewrite with the same workload: two pre-created accounts followed by
30,000 successful posted transfers in prebuilt batches of 30. Request creation
is outside the timed interval in both runners.

Run both benchmarks from the repository root:

```sh
sh ocam/bench/run_state_machine_comparison.sh
```

The script uses the Zig binary bundled with the pinned TigerBeetle submodule
(`path/to/tigerbeetle/zig/zig`, version 0.14.1) and the active Opam switch for
the OCaml executable. Set `ZIG=/path/to/zig` to use a compatible local Zig
binary. The native harness imports the pinned source directly; it does not
modify the submodule. On this macOS host, the command pins the native target to
macOS 15 because the bundled Zig 0.14.1 cannot link its test runner against the
host's newer macOS SDK target.

| Implementation | Timed path | Metrics |
| --- | --- | --- |
| TigerBeetle Zig | The pinned `StateMachine` commit path through TigerBeetle's in-memory test storage, including multi-batch encoding, prefetch, and LSM indexes. | Operations/second and mean batch latency. |
| OCaml | `create_transfers` in the deterministic in-memory rewrite, including creation-result allocation. | Operations/second, mean batch latency, and OCaml heap words allocated. |

The figures are useful for tracking each implementation on the same machine,
but are not a server-throughput comparison. The Zig path includes its LSM/VSR
test fixture; the OCaml path intentionally has no storage or replication
adapter yet. Run several times on an otherwise idle machine and compare medians.

## Latest local run

Populate this table with the output of the command above when recording a
machine-specific result. Do not compare results from different hosts, compiler
versions, or optimization modes.

| Implementation | Operations/s | Mean batch latency (ms) | Allocation |
| --- | ---: | ---: | --- |
| TigerBeetle Zig | pending first run | pending first run | not reported by this harness |
| OCaml | pending first run | pending first run | pending first run |
