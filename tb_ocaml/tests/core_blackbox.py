#!/usr/bin/env python3
import json
import os
import socket
import struct
import subprocess
import tempfile
import time
from pathlib import Path


ROOT = Path("/Users/blouse_man/Downloads/coding/github/6666/tb_ocaml")
BIN = ROOT / "_build/default/bin/tigerbeetle.exe"
CHECKSUM_BIN = ROOT / "_build_tools/tb_checksum"
HEADER_SIZE = 256
REGISTER_REQUEST_SIZE = 256

OP_PULSE = 4
OP_LOOKUP_ACCOUNTS = 140
OP_LOOKUP_TRANSFERS = 141
OP_CREATE_ACCOUNTS = 146
OP_CREATE_TRANSFERS = 147
ACCOUNT_FILTER_SIZE = 128
QUERY_FILTER_SIZE = 64
ACCOUNT_SIZE = 128
TRANSFER_SIZE = 128
ACCOUNT_BALANCE_SIZE = 128


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


class TigerBeetleServer:
    def __init__(self):
        self.tmpdir = tempfile.TemporaryDirectory(prefix="tb-ocaml-")
        self.data = Path(self.tmpdir.name) / "0_0.tigerbeetle"
        self.proc = None
        self.port = None

    def __enter__(self):
        subprocess.run(
            [
                str(BIN),
                "format",
                "--cluster=0",
                "--replica=0",
                "--replica-count=1",
                "--development",
                str(self.data),
            ],
            check=True,
        )
        env = os.environ.copy()
        env["TB_OCAML_CHECKSUM_BIN"] = str(CHECKSUM_BIN)
        self.proc = subprocess.Popen(
            [
                str(BIN),
                "start",
                "--development=true",
                "--addresses=0",
                str(self.data),
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=env,
        )
        assert self.proc.stdout is not None
        self.port = int(self.proc.stdout.readline().strip())
        return self

    def __exit__(self, exc_type, exc, tb):
        if self.proc is not None:
            self.proc.kill()
            self.proc.wait(timeout=5)
        self.tmpdir.cleanup()

    def repl(self, command: str):
        completed = subprocess.run(
            [
                str(BIN),
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

    def raw_empty(self, op: int):
        with socket.create_connection(("127.0.0.1", self.port), timeout=5) as sock:
            sock.sendall(make_register_request())
            read_reply(sock)
            sock.sendall(make_request(op, b""))
            header, body = read_reply(sock)
            assert header["size"] == HEADER_SIZE
            assert body == b""

    def raw_request(self, op: int, body: bytes):
        with socket.create_connection(("127.0.0.1", self.port), timeout=5) as sock:
            sock.sendall(make_register_request())
            read_reply(sock)
            sock.sendall(make_request(op, body))
            return read_reply(sock)


def set_u128(buf: bytearray, off: int, value: int):
    buf[off : off + 16] = value.to_bytes(16, "little", signed=False)


def set_i32(buf: bytearray, off: int, value: int):
    buf[off : off + 4] = struct.pack("<I", value & 0xFFFFFFFF)


def set_i64(buf: bytearray, off: int, value: int):
    buf[off : off + 8] = struct.pack("<Q", value & 0xFFFFFFFFFFFFFFFF)


def make_register_request():
    header = bytearray(HEADER_SIZE)
    set_i32(header, 96, HEADER_SIZE + REGISTER_REQUEST_SIZE)
    set_i32(header, 108, 1)
    header[114] = 5
    set_u128(header, 160, 1)
    header[196] = 2
    return bytes(header) + (b"\x00" * REGISTER_REQUEST_SIZE)


def make_request(op: int, body: bytes):
    header = bytearray(HEADER_SIZE)
    set_i32(header, 96, HEADER_SIZE + len(body))
    set_i32(header, 108, 1)
    header[114] = 5
    set_u128(header, 160, 1)
    set_i64(header, 176, 1)
    set_i32(header, 192, 1)
    header[196] = op
    return bytes(header) + body


def multibatch_encode_single(payload: bytes, element_size: int):
    assert element_size > 0
    trailer_unpadded = 4
    trailer_size = ((trailer_unpadded + element_size - 1) // element_size) * element_size
    total = len(payload) + trailer_size
    out = bytearray(total)
    out[: len(payload)] = payload
    trailer_start = len(payload)
    total_items = (trailer_size - 2) // 2
    padding_items = total_items - 1
    for i in range(padding_items):
        struct.pack_into("<H", out, trailer_start + i * 2, 0xFFFF)
    struct.pack_into("<H", out, trailer_start + padding_items * 2, len(payload) // element_size)
    struct.pack_into("<H", out, total - 2, 1)
    return bytes(out)


def multibatch_decode_single(body: bytes, element_size: int):
    if not body:
        return b""
    batch_count = struct.unpack_from("<H", body, len(body) - 2)[0]
    assert batch_count == 1
    trailer_unpadded = 4
    trailer_size = ((trailer_unpadded + element_size - 1) // element_size) * element_size
    return body[: len(body) - trailer_size]


def encode_account_filter(account_id=0, user_data_128=0, user_data_64=0, user_data_32=0, code=0, timestamp_min=0, timestamp_max=0, limit=8189, flags=0):
    out = bytearray(ACCOUNT_FILTER_SIZE)
    set_u128(out, 0, account_id)
    set_u128(out, 16, user_data_128)
    set_i64(out, 32, user_data_64)
    set_i32(out, 40, user_data_32)
    out[44:46] = struct.pack("<H", code)
    set_i64(out, 104, timestamp_min)
    set_i64(out, 112, timestamp_max)
    set_i32(out, 120, limit)
    set_i32(out, 124, flags)
    return bytes(out)


def encode_query_filter(user_data_128=0, user_data_64=0, user_data_32=0, ledger=0, code=0, timestamp_min=0, timestamp_max=0, limit=8189, flags=0):
    out = bytearray(QUERY_FILTER_SIZE)
    set_u128(out, 0, user_data_128)
    set_i64(out, 16, user_data_64)
    set_i32(out, 24, user_data_32)
    set_i32(out, 28, ledger)
    out[32:34] = struct.pack("<H", code)
    set_i64(out, 40, timestamp_min)
    set_i64(out, 48, timestamp_max)
    set_i32(out, 56, limit)
    set_i32(out, 60, flags)
    return bytes(out)


def read_exact(sock: socket.socket, length: int):
    chunks = []
    remaining = length
    while remaining:
        chunk = sock.recv(remaining)
        if not chunk:
            raise EOFError("socket closed")
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def read_reply(sock: socket.socket):
    header = read_exact(sock, HEADER_SIZE)
    size = struct.unpack_from("<I", header, 96)[0] & 0x7FFFFFFF
    body = read_exact(sock, size - HEADER_SIZE) if size > HEADER_SIZE else b""
    return {"size": size, "operation": header[236]}, body


def assert_eq(actual, expected, label):
    if actual != expected:
        raise AssertionError(f"{label}: expected {expected!r}, got {actual!r}")


def assert_true(value, label):
    if not value:
        raise AssertionError(label)


def test_help_version():
    assert_true("tigerbeetle repl" in subprocess.check_output([str(BIN), "--help"], text=True), "help")
    assert_true(
        "tables --tree" in subprocess.check_output([str(BIN), "inspect", "--help"], text=True),
        "inspect help",
    )
    assert_true(
        "TigerBeetle version" in subprocess.check_output([str(BIN), "version"], text=True),
        "version",
    )
    assert_true(
        "process.backoff_max="
        in subprocess.check_output([str(BIN), "version", "--verbose"], text=True),
        "version verbose",
    )


def test_core_subset():
    with TigerBeetleServer() as tb:
        tb.raw_empty(OP_CREATE_ACCOUNTS)
        tb.raw_empty(OP_CREATE_TRANSFERS)
        tb.raw_empty(OP_LOOKUP_ACCOUNTS)
        tb.raw_empty(OP_LOOKUP_TRANSFERS)
        tb.raw_empty(OP_PULSE)

        results = tb.repl("create_accounts id=17 code=718 ledger=1")
        assert_eq(results[0]["status"], "tigerbeetle.CreateAccountStatus.created", "create account a")

        results = tb.repl("create_accounts id=17 code=718 ledger=1, id=19 code=719 ledger=1")
        assert_eq(results[0]["status"], "tigerbeetle.CreateAccountStatus.exists", "duplicate account")
        assert_eq(results[1]["status"], "tigerbeetle.CreateAccountStatus.created", "create account b")

        results = tb.repl("create_accounts id=3 code=718 ledger=1 timestamp=2")
        assert_eq(
            results[0]["status"],
            "tigerbeetle.CreateAccountStatus.timestamp_must_be_zero",
            "account timestamp must be zero",
        )

        results = tb.repl(
            "create_transfers id=1 debit_account_id=19 credit_account_id=17 amount=100 ledger=1 code=1"
        )
        assert_eq(results[0]["status"], "tigerbeetle.CreateTransferStatus.created", "transfer created")

        accounts = tb.repl("lookup_accounts id=17, id=19")
        assert_eq(accounts[0]["credits_posted"], "100", "credit posted")
        assert_eq(accounts[1]["debits_posted"], "100", "debit posted")

        results = tb.repl(
            "create_transfers id=2 debit_account_id=19 credit_account_id=17 amount=50 ledger=1 code=1 flags=pending timeout=2"
        )
        assert_eq(results[0]["status"], "tigerbeetle.CreateTransferStatus.created", "pending created")

        accounts = tb.repl("lookup_accounts id=17, id=19")
        assert_eq(accounts[0]["credits_pending"], "50", "credit pending")
        assert_eq(accounts[1]["debits_pending"], "50", "debit pending")

        results = tb.repl(
            "create_transfers id=3 pending_id=2 amount=340282366920938463463374607431768211455 ledger=1 code=1 flags=post_pending_transfer"
        )
        assert_eq(results[0]["status"], "tigerbeetle.CreateTransferStatus.created", "post pending")

        accounts = tb.repl("lookup_accounts id=17, id=19")
        assert_eq(accounts[0]["credits_posted"], "150", "credit posted after post")
        assert_eq(accounts[0]["credits_pending"], "0", "credit pending cleared")
        assert_eq(accounts[1]["debits_posted"], "150", "debit posted after post")
        assert_eq(accounts[1]["debits_pending"], "0", "debit pending cleared")

        results = tb.repl(
            "create_transfers id=4 debit_account_id=19 credit_account_id=17 amount=50 ledger=1 code=1 flags=pending timeout=1"
        )
        assert_eq(results[0]["status"], "tigerbeetle.CreateTransferStatus.created", "second pending created")
        time.sleep(1.25)
        accounts = tb.repl("lookup_accounts id=17, id=19")
        assert_eq(accounts[0]["credits_pending"], "0", "expired credit pending cleared")
        assert_eq(accounts[1]["debits_pending"], "0", "expired debit pending cleared")
        results = tb.repl(
            "create_transfers id=5 pending_id=4 ledger=1 code=1 flags=void_pending_transfer"
        )
        assert_eq(
            results[0]["status"],
            "tigerbeetle.CreateTransferStatus.pending_transfer_expired",
            "void expired pending",
        )

        results = tb.repl(
            "create_transfers id=6 debit_account_id=19 credit_account_id=17 amount=0 ledger=1 code=1 flags=closing_debit|closing_credit|pending"
        )
        assert_eq(results[0]["status"], "tigerbeetle.CreateTransferStatus.created", "closing pending")
        accounts = tb.repl("lookup_accounts id=17, id=19")
        assert_true("closed" in accounts[0]["flags"] and "closed" in accounts[1]["flags"], "accounts closed")

        results = tb.repl(
            "create_transfers id=7 pending_id=6 ledger=1 code=1 flags=void_pending_transfer"
        )
        assert_eq(results[0]["status"], "tigerbeetle.CreateTransferStatus.created", "void closing pending")
        accounts = tb.repl("lookup_accounts id=17, id=19")
        assert_true("closed" not in accounts[0]["flags"] and "closed" not in accounts[1]["flags"], "accounts reopened")

        results = tb.repl(
            "create_transfers id=8 debit_account_id=19 credit_account_id=17 amount=100 ledger=1 code=1 flags=linked, "
            "id=8 debit_account_id=19 credit_account_id=17 amount=100 ledger=1 code=1"
        )
        assert_eq(
            results[0]["status"],
            "tigerbeetle.CreateTransferStatus.linked_event_failed",
            "linked transfer failed",
        )
        assert_eq(
            results[1]["status"],
            "tigerbeetle.CreateTransferStatus.exists_with_different_flags",
            "linked duplicate status",
        )

        results = tb.repl("create_accounts id=21 flags=history code=718 ledger=1")
        assert_eq(results[0]["status"], "tigerbeetle.CreateAccountStatus.created", "history account")
        batch = ", ".join(
            [
                f"id={10000 + i} debit_account_id={'21' if i % 2 == 0 else '17'} credit_account_id={'19' if i % 2 == 0 else '21'} amount=100 ledger=1 code=1"
                for i in range(10)
            ]
        )
        results = tb.repl(f"create_transfers {batch}")
        assert_true(all(item["status"] == "tigerbeetle.CreateTransferStatus.created" for item in results), "history transfers")

        transfers = tb.repl("get_account_transfers account_id=21 flags=credits|debits")
        balances = tb.repl("get_account_balances account_id=21 flags=credits|debits")
        assert_eq(len(transfers), 10, "account transfers count")
        assert_eq(len(balances), 10, "account balances count")
        timestamps = [int(item["timestamp"]) for item in transfers]
        assert_true(timestamps == sorted(timestamps), "account transfers ascending")
        assert_eq(
            [item["timestamp"] for item in transfers],
            [item["timestamp"] for item in balances],
            "balance timestamps track transfers",
        )

        transfers = tb.repl("get_account_transfers account_id=21 flags=debits|reversed")
        assert_eq(len(transfers), 5, "debit transfers count")
        timestamps = [int(item["timestamp"]) for item in transfers]
        assert_true(timestamps == sorted(timestamps, reverse=True), "debit transfers descending")

        assert_eq(tb.repl("get_account_transfers account_id=21 flags="), [], "empty account transfer flags")
        assert_eq(tb.repl("get_account_balances account_id=21 flags="), [], "empty account balance flags")

        _, body = tb.raw_request(
            142,
            multibatch_encode_single(
                encode_account_filter(account_id=21, limit=8189, flags=0xFFFF),
                ACCOUNT_FILTER_SIZE,
            ),
        )
        assert_eq(multibatch_decode_single(body, TRANSFER_SIZE), b"", "invalid account transfer flags")
        _, body = tb.raw_request(
            143,
            multibatch_encode_single(
                encode_account_filter(account_id=21, limit=8189, flags=0xFFFF),
                ACCOUNT_FILTER_SIZE,
            ),
        )
        assert_eq(multibatch_decode_single(body, ACCOUNT_BALANCE_SIZE), b"", "invalid account balance flags")

        accounts = tb.repl("query_accounts code=718 ledger=1")
        assert_true(any(item["id"] == "21" for item in accounts), "query accounts finds account")
        transfers = tb.repl("query_transfers code=1 ledger=1")
        assert_true(any(item["id"] == "1" for item in transfers), "query transfers finds transfer")

        query_accounts_batch = ", ".join(
            [
                f"id={2000 + i} user_data_128={'1000' if i % 2 == 0 else '2000'} user_data_64={'100' if i % 2 == 0 else '200'} "
                f"user_data_32={'10' if i % 2 == 0 else '20'} ledger=1 code=999"
                for i in range(10)
            ]
        )
        results = tb.repl(f"create_accounts {query_accounts_batch}")
        assert_true(all(item["status"] == "tigerbeetle.CreateAccountStatus.created" for item in results), "query accounts fixture")

        accounts = tb.repl("query_accounts user_data_128=1000 user_data_64=100 user_data_32=10 ledger=1 code=999")
        assert_eq(len(accounts), 5, "query accounts subset")
        timestamps = [int(item["timestamp"]) for item in accounts]
        assert_true(timestamps == sorted(timestamps), "query accounts ascending")

        accounts = tb.repl("query_accounts user_data_128=2000 user_data_64=200 user_data_32=20 ledger=1 code=999 flags=reversed")
        assert_eq(len(accounts), 5, "query accounts reversed subset")
        timestamps = [int(item["timestamp"]) for item in accounts]
        assert_true(timestamps == sorted(timestamps, reverse=True), "query accounts descending")

        page = tb.repl("query_accounts code=999 limit=5 flags=reversed")
        assert_eq(len(page), 5, "query accounts first page")
        page_timestamps = [int(item["timestamp"]) for item in page]
        assert_true(page_timestamps == sorted(page_timestamps, reverse=True), "query accounts page descending")
        next_page = tb.repl(f"query_accounts code=999 limit=5 flags=reversed timestamp_max={page_timestamps[-1] - 1}")
        assert_eq(len(next_page), 5, "query accounts second page")
        final_page = tb.repl(f"query_accounts code=999 limit=5 flags=reversed timestamp_max={int(next_page[-1]['timestamp']) - 1}")
        assert_eq(final_page, [], "query accounts exhausted")

        query_transfer_batch = ", ".join(
            [
                f"id={3000 + i} debit_account_id={'21' if i % 2 == 0 else '17'} credit_account_id={'19' if i % 2 == 0 else '21'} "
                f"amount=100 user_data_128={'1000' if i % 2 == 0 else '2000'} user_data_64={'100' if i % 2 == 0 else '200'} "
                f"user_data_32={'10' if i % 2 == 0 else '20'} ledger=1 code=999"
                for i in range(10)
            ]
        )
        results = tb.repl(f"create_transfers {query_transfer_batch}")
        assert_true(all(item["status"] == "tigerbeetle.CreateTransferStatus.created" for item in results), "query transfers fixture")

        transfers = tb.repl("query_transfers user_data_128=1000 user_data_64=100 user_data_32=10 ledger=1 code=999")
        assert_eq(len(transfers), 5, "query transfers subset")
        timestamps = [int(item["timestamp"]) for item in transfers]
        assert_true(timestamps == sorted(timestamps), "query transfers ascending")

        transfers = tb.repl("query_transfers user_data_128=2000 user_data_64=200 user_data_32=20 ledger=1 code=999 flags=reversed")
        assert_eq(len(transfers), 5, "query transfers reversed subset")
        timestamps = [int(item["timestamp"]) for item in transfers]
        assert_true(timestamps == sorted(timestamps, reverse=True), "query transfers descending")

        page = tb.repl("query_transfers code=999 limit=5 flags=reversed")
        assert_eq(len(page), 5, "query transfers first page")
        page_timestamps = [int(item["timestamp"]) for item in page]
        assert_true(page_timestamps == sorted(page_timestamps, reverse=True), "query transfers page descending")
        next_page = tb.repl(f"query_transfers code=999 limit=5 flags=reversed timestamp_max={page_timestamps[-1] - 1}")
        assert_eq(len(next_page), 5, "query transfers second page")
        final_page = tb.repl(f"query_transfers code=999 limit=5 flags=reversed timestamp_max={int(next_page[-1]['timestamp']) - 1}")
        assert_eq(final_page, [], "query transfers exhausted")

        max_u64 = (1 << 64) - 1
        for payload in [
            encode_query_filter(timestamp_min=max_u64, limit=8189),
            encode_query_filter(timestamp_max=max_u64, limit=8189),
            encode_query_filter(timestamp_min=max_u64 - 1, timestamp_max=1, limit=8189),
            encode_query_filter(limit=0),
            encode_query_filter(limit=8189, flags=0xFFFF),
        ]:
            _, body = tb.raw_request(144, multibatch_encode_single(payload, QUERY_FILTER_SIZE))
            assert_eq(multibatch_decode_single(body, ACCOUNT_SIZE), b"", "invalid query accounts filter")
            _, body = tb.raw_request(145, multibatch_encode_single(payload, QUERY_FILTER_SIZE))
            assert_eq(multibatch_decode_single(body, TRANSFER_SIZE), b"", "invalid query transfers filter")

        for payload in [
            encode_account_filter(account_id=21, timestamp_min=max_u64, limit=8189, flags=3),
            encode_account_filter(account_id=21, timestamp_max=max_u64, limit=8189, flags=3),
            encode_account_filter(account_id=21, timestamp_min=max_u64 - 1, timestamp_max=1, limit=8189, flags=3),
            encode_account_filter(account_id=21, limit=0, flags=3),
        ]:
            _, body = tb.raw_request(142, multibatch_encode_single(payload, ACCOUNT_FILTER_SIZE))
            assert_eq(multibatch_decode_single(body, TRANSFER_SIZE), b"", "invalid account transfer filter")
            _, body = tb.raw_request(143, multibatch_encode_single(payload, ACCOUNT_FILTER_SIZE))
            assert_eq(multibatch_decode_single(body, ACCOUNT_BALANCE_SIZE), b"", "invalid account balance filter")

        tmp = tb.repl("create_accounts id=1000 code=1 ledger=1")[0]
        timestamp_max = int(tmp["timestamp"])
        results = tb.repl(
            f"create_accounts id=1001 code=1 ledger=1 flags=imported timestamp={timestamp_max + 1}, "
            f"id=1002 code=1 ledger=1 flags=imported timestamp={timestamp_max + 2}"
        )
        assert_eq(results[0]["status"], "tigerbeetle.CreateAccountStatus.created", "imported account a")
        assert_eq(results[0]["timestamp"], str(timestamp_max + 1), "imported account a timestamp")
        assert_eq(results[1]["status"], "tigerbeetle.CreateAccountStatus.created", "imported account b")
        assert_eq(results[1]["timestamp"], str(timestamp_max + 2), "imported account b timestamp")

        results = tb.repl(
            f"create_transfers id=1003 debit_account_id=1001 credit_account_id=1002 amount=100 ledger=1 code=1 flags=imported timestamp={timestamp_max + 3}"
        )
        assert_eq(results[0]["status"], "tigerbeetle.CreateTransferStatus.created", "imported transfer")
        assert_eq(results[0]["timestamp"], str(timestamp_max + 3), "imported transfer timestamp")


if __name__ == "__main__":
    test_help_version()
    test_core_subset()
    print("PASS core_blackbox")
