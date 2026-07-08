#!/usr/bin/env bash

# Entrypoint per the Exercism Docker test-runner contract:
# https://github.com/exercism/docs/blob/main/building/tooling/test-runners/docker.md
#
# Usage: run.sh <slug> <solution-dir> <output-dir>

set -euo pipefail

slug="$1"
solution_dir="$2"
output_dir="$3"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

mkdir -p "$output_dir"

python3 "$repo_root/lib/dafny_test_runner.py" "$slug" "$solution_dir" "$output_dir"
