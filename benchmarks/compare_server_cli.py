#!/usr/bin/env python3
import argparse
import json
import os
import statistics
import subprocess
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path


ROOT = Path("/Users/blouse_man/Downloads/coding/github/6666")
DEFAULT_OCAML_BIN = ROOT / "tb_ocaml/_build/default/bin/tigerbeetle.exe"
DEFAULT_ZIG_BIN = Path("/tmp/tb_zig_release/tigerbeetle")
DEFAULT_OCAML_CHECKSUM = ROOT / "tb_ocaml/_build_tools/tb_checksum"


def decode_objects(stdout: str):
    decoder = json.JSONDecoder()
    items = []
    index = 0
    while index < len(stdout):
        while index < len(stdout) and stdout[index].isspace():
            index += 1
        if index >= len(stdout):
            break
        item, next_index = decoder.raw_decode(stdout, index)
        items.append(item)
        index = next_index
    return items


def chunked(items, size):
    for index in range(0, len(items), size):
        yield items[index : index + size]


def account_event(account_id: int, code: int = 1, ledger: int = 1, flags: str = ""):
    parts = [f"id={account_id}", f"code={code}", f"ledger={ledger}"]
    if flags:
        parts.append(f"flags={flags}")
    return " ".join(parts)


def transfer_event(
    transfer_id: int,
    debit_account_id: int,
    credit_account_id: int,
    amount: int = 1,
    code: int = 1,
    ledger: int = 1,
):
    return " ".join(
        [
            f"id={transfer_id}",
            f"debit_account_id={debit_account_id}",
            f"credit_account_id={credit_account_id}",
            f"amount={amount}",
            f"ledger={ledger}",
            f"code={code}",
        ]
    )


@dataclass
class Impl:
    name: str
    bin_path: Path
    checksum_bin: Path | None = None

    def start_env(self):
        env = os.environ.copy()
        if self.checksum_bin is not None:
            env["TB_OCAML_CHECKSUM_BIN"] = str(self.checksum_bin)
        return env


class Server:
    def __init__(self, impl: Impl):
        self.impl = impl
        self.tmpdir = tempfile.TemporaryDirectory(prefix=f"tb-bench-{impl.name}-")
        self.data = Path(self.tmpdir.name) / "0_0.tigerbeetle"
        self.proc = None
        self.port = None

    def __enter__(self):
        format_start = time.perf_counter()
        subprocess.run(
            [
                str(self.impl.bin_path),
                "format",
                "--cluster=0",
                "--replica=0",
                "--replica-count=1",
                "--development",
                str(self.data),
            ],
            check=True,
            env=self.impl.start_env(),
            capture_output=True,
            text=True,
        )
        self.format_seconds = time.perf_counter() - format_start

        start_start = time.perf_counter()
        self.proc = subprocess.Popen(
            [
                str(self.impl.bin_path),
                "start",
                "--development=true",
                "--addresses=0",
                str(self.data),
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=self.impl.start_env(),
        )
        assert self.proc.stdout is not None
        self.port = int(self.proc.stdout.readline().strip())
        self.start_seconds = time.perf_counter() - start_start
        return self

    def __exit__(self, exc_type, exc, tb):
        if self.proc is not None:
            self.proc.kill()
            self.proc.wait(timeout=5)
        self.tmpdir.cleanup()

    def repl(self, command: str):
        completed = subprocess.run(
            [
                str(self.impl.bin_path),
                "repl",
                "--cluster=0",
                f"--addresses={self.port}",
                f"--command={command}",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        return decode_objects(completed.stdout)


def benchmark_once(impl: Impl, accounts: int, batch_size: int):
    metrics = {}
    with Server(impl) as server:
        metrics["format_seconds"] = server.format_seconds
        metrics["start_seconds"] = server.start_seconds

        account_ids = list(range(10_000, 10_000 + accounts))
        account_batches = [
            "create_accounts " + ", ".join(account_event(account_id, code=100 + (account_id % 7)) for account_id in batch)
            for batch in chunked(account_ids, batch_size)
        ]

        t0 = time.perf_counter()
        created = 0
        for batch, command in zip(chunked(account_ids, batch_size), account_batches):
            results = server.repl(command)
            assert len(results) in (0, len(batch)), results[:3]
            assert all(item["status"].endswith(".created") for item in results), results[:3]
            created += len(batch)
        metrics["create_accounts_seconds"] = time.perf_counter() - t0
        metrics["create_accounts_count"] = created

        transfer_ids = list(range(20_000, 20_000 + accounts - 1))
        transfer_cmds = []
        for batch in chunked(transfer_ids, batch_size):
            events = []
            for transfer_id in batch:
                offset = transfer_id - 20_000
                debit = account_ids[offset]
                credit = account_ids[offset + 1]
                events.append(transfer_event(transfer_id, debit, credit))
            transfer_cmds.append("create_transfers " + ", ".join(events))

        t0 = time.perf_counter()
        created = 0
        for batch, command in zip(chunked(transfer_ids, batch_size), transfer_cmds):
            results = server.repl(command)
            assert len(results) in (0, len(batch)), results[:3]
            assert all(item["status"].endswith(".created") for item in results), results[:3]
            created += len(batch)
        metrics["create_transfers_seconds"] = time.perf_counter() - t0
        metrics["create_transfers_count"] = created

        lookup_commands = [
            "lookup_accounts " + ", ".join(f"id={account_id}" for account_id in batch)
            for batch in chunked(account_ids, batch_size)
        ]
        t0 = time.perf_counter()
        looked_up = 0
        for command in lookup_commands:
            results = server.repl(command)
            looked_up += len(results)
        metrics["lookup_accounts_seconds"] = time.perf_counter() - t0
        metrics["lookup_accounts_count"] = looked_up

        t0 = time.perf_counter()
        queried = server.repl("query_accounts ledger=1 limit=8189")
        metrics["query_accounts_seconds"] = time.perf_counter() - t0
        metrics["query_accounts_count"] = len(queried)

    return metrics


def summarize_runs(name: str, runs: list[dict]):
    summary = {"name": name, "runs": runs, "median": {}}
    numeric_keys = sorted(
        {
            key
            for run in runs
            for key, value in run.items()
            if isinstance(value, (int, float))
        }
    )
    for key in numeric_keys:
        values = [run[key] for run in runs]
        summary["median"][key] = statistics.median(values)
    return summary


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--accounts", type=int, default=1000)
    parser.add_argument("--batch-size", type=int, default=200)
    parser.add_argument("--iterations", type=int, default=3)
    parser.add_argument("--ocaml-bin", type=Path, default=DEFAULT_OCAML_BIN)
    parser.add_argument("--zig-bin", type=Path, default=DEFAULT_ZIG_BIN)
    parser.add_argument("--ocaml-checksum-bin", type=Path, default=DEFAULT_OCAML_CHECKSUM)
    args = parser.parse_args()

    impls = [
        Impl("ocaml", args.ocaml_bin, args.ocaml_checksum_bin),
        Impl("zig", args.zig_bin),
    ]

    all_results = []
    for impl in impls:
        runs = []
        for iteration in range(args.iterations):
            print(f"running {impl.name} iteration {iteration + 1}/{args.iterations}", flush=True)
            runs.append(benchmark_once(impl, accounts=args.accounts, batch_size=args.batch_size))
        all_results.append(summarize_runs(impl.name, runs))

    print(json.dumps({"accounts": args.accounts, "batch_size": args.batch_size, "iterations": args.iterations, "results": all_results}, indent=2))


if __name__ == "__main__":
    main()
