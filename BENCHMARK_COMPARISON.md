# State-machine benchmark status

The OCaml workload creates two accounts before timing, then applies 30,000
successful posted transfers in prebuilt batches of 30. Request construction is
outside the timed interval. A future valid native runner should use the same
transfer workload.

Only the OCaml runner is currently executable:

```sh
cd ocam
opam exec -- dune exec bench/state_machine_bench.exe
```

The direct Zig baseline has not produced a valid measurement. Its standalone
fixture reaches a TigerBeetle internal commit-sequencing invariant after the
first commit, so it must not be used for comparison or cited as a TigerBeetle
performance figure. The pinned submodule remains the behavior reference; it is
not modified by this work.

| Implementation | Timed path | Metrics |
| --- | --- | --- |
| TigerBeetle Zig | Planned: the pinned `StateMachine` `create_transfers` commit path through TigerBeetle's in-memory test storage. | Blocked pending a fixture that follows the required commit sequencing. |
| OCaml | `create_transfers` in the deterministic in-memory rewrite, including result allocation. | Operations/second, mean batch latency, and OCaml heap words allocated. |

The OCaml figure tracks the deterministic in-memory core, not server
throughput. A future native figure will include an LSM/VSR test fixture, so a
paired result will still need to be labelled as a state-machine-path comparison
rather than a server-throughput comparison. Run multiple times on an otherwise
idle machine and compare medians.

## Latest local run

This is a machine-specific observation, not a cross-implementation result. Do
not compare results from different hosts, compiler versions, or optimization
modes.

| Implementation | Operations/s | Mean batch latency (ms) | Allocation |
| --- | ---: | ---: | --- |
| TigerBeetle Zig | blocked | blocked | The standalone fixture needs TigerBeetle's internal commit sequencing completed before it can produce a valid run. |
| OCaml | 1,294,725 | 0.023 | 5,767,131 words total; 192.24 words/op |
