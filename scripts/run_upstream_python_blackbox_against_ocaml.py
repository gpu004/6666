#!/usr/bin/env python3
import argparse
import os
import shutil
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OCAML_BIN = Path(
    os.environ.get("TB_OCAML_BIN", ROOT / "tb_ocaml/_build/default/bin/tigerbeetle.exe")
)
OCAML_CHECKSUM_BIN = Path(
    os.environ.get("TB_OCAML_CHECKSUM_BIN", ROOT / "tb_ocaml/_build_tools/tb_checksum")
)
UPSTREAM_PY_TEST = ROOT / "repo/src/clients/python/tests/test_basic.py"
DEFAULT_VENV_ACTIVATE = ROOT / ".venv_pytests/bin/activate"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--venv-activate",
        type=Path,
        default=DEFAULT_VENV_ACTIVATE,
        help="Path to a shell activate script for the Python venv that has pytest and tigerbeetle installed.",
    )
    parser.add_argument(
        "--pytest-args",
        default="-x -vv",
        help="Extra pytest arguments passed through to the upstream test run.",
    )
    args = parser.parse_args()

    if not OCAML_BIN.exists():
        raise SystemExit(f"missing OCaml binary: {OCAML_BIN}")
    if not UPSTREAM_PY_TEST.exists():
        raise SystemExit(f"missing upstream test file: {UPSTREAM_PY_TEST}")
    if not args.venv_activate.exists():
        raise SystemExit(f"missing venv activate script: {args.venv_activate}")

    with tempfile.TemporaryDirectory(prefix="tb-upstream-py-") as td:
        td = Path(td)
        test_file = td / "test_basic.py"
        data_file = td / "0_0.tigerbeetle"
        shutil.copy2(UPSTREAM_PY_TEST, test_file)

        subprocess.run(
            [
                str(OCAML_BIN),
                "format",
                "--cluster=0",
                "--replica=0",
                "--replica-count=1",
                "--development",
                str(data_file),
            ],
            check=True,
        )

        env = os.environ.copy()
        env["TB_OCAML_CHECKSUM_BIN"] = str(OCAML_CHECKSUM_BIN)

        server = subprocess.Popen(
            [
                str(OCAML_BIN),
                "start",
                "--development=true",
                "--addresses=0",
                str(data_file),
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=env,
        )

        try:
            assert server.stdout is not None
            port = server.stdout.readline().strip()
            if not port:
                raise RuntimeError("failed to read OCaml server port from stdout")

            command = (
                f". {args.venv_activate} && "
                f"TB_ADDRESS={port} pytest {args.pytest_args} {test_file}"
            )
            result = subprocess.run(
                ["/bin/zsh", "-lc", command],
                text=True,
                capture_output=True,
            )
            print(f"TB_ADDRESS={port}")
            print(result.stdout, end="")
            if result.stderr:
                print("\nSTDERR>>>")
                print(result.stderr, end="")
            raise SystemExit(result.returncode)
        finally:
            server.kill()
            server.wait(timeout=5)


if __name__ == "__main__":
    main()
