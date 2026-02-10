#!/usr/bin/env bash
set -euo pipefail

echo "=== Building ==="
dune build

echo "=== Running tests ==="
dune runtest

echo "=== All checks passed ==="
