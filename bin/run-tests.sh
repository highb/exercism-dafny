#!/usr/bin/env bash

# Local test harness. Runs every reference (.meta/solution.dfy) and
# deliberately-broken (.meta/broken/*.dfy) solution, plus the exercise
# stub itself, through bin/run.sh and asserts on the resulting
# results.json. Mirrors the pattern used by exercism/lean-test-runner's
# bin/run-tests.sh.
#
# Requires: python3, dafny, jq.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

pass_count=0
fail_count=0
last_results_file=""

# run_case <description> <dfy-file> <slug> <expected-top-level-status>
run_case() {
  local description="$1" dfy_file="$2" slug="$3" expect_status="$4"
  local case_dir sol_dir out_dir results_file
  case_dir="$(mktemp -d -p "$tmp_root")"
  sol_dir="$case_dir/solution"
  out_dir="$case_dir/output"
  mkdir -p "$sol_dir" "$out_dir"
  cp "$dfy_file" "$sol_dir/$slug.dfy"

  "$repo_root/bin/run.sh" "$slug" "$sol_dir" "$out_dir" >"$case_dir/run.log" 2>&1 || true

  results_file="$out_dir/results.json"
  last_results_file="$results_file"

  if [[ ! -f "$results_file" ]]; then
    echo "FAIL  $description: no results.json produced"
    cat "$case_dir/run.log"
    fail_count=$((fail_count + 1))
    return
  fi

  local actual_status
  actual_status="$(jq -r '.status' "$results_file")"

  if [[ "$actual_status" == "$expect_status" ]]; then
    echo "PASS  $description (status=$actual_status)"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL  $description: expected status=$expect_status, got status=$actual_status"
    cat "$results_file"
    fail_count=$((fail_count + 1))
  fi
}

# assert_test_status <description> <name-prefix> <expected-test-status>
# Checks the most recent run_case's results.json for a test whose name
# starts with <name-prefix> and asserts its status. Used to confirm the
# *right* obligation is reported as failing, not just "something failed".
assert_test_status() {
  local description="$1" name_prefix="$2" expect_test_status="$3"
  local actual
  actual="$(jq -r --arg p "$name_prefix" \
    '[.tests[]? | select(.name | startswith($p))] | if length > 0 then (map(.status) | if any(. == "fail") then "fail" elif any(. == "error") then "error" else "pass" end) else "MISSING" end' \
    "$last_results_file")"
  if [[ "$actual" == "$expect_test_status" ]]; then
    echo "PASS  $description"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL  $description: expected '$name_prefix*' status=$expect_test_status, got '$actual'"
    fail_count=$((fail_count + 1))
  fi
}

for exercise_dir in "$repo_root"/exercises/practice/*/; do
  slug="$(basename "$exercise_dir")"
  stub="$exercise_dir/$slug.dfy"
  solution="$exercise_dir/.meta/solution.dfy"

  echo "=== $slug ==="

  if [[ -f "$stub" ]]; then
    run_case "$slug: stub fails cleanly" "$stub" "$slug" "fail"
  fi

  if [[ -f "$solution" ]]; then
    run_case "$slug: reference solution verifies" "$solution" "$slug" "pass"
  else
    echo "FAIL  $slug: missing .meta/solution.dfy"
    fail_count=$((fail_count + 1))
  fi

  if [[ -d "$exercise_dir/.meta/broken" ]]; then
    for broken in "$exercise_dir"/.meta/broken/*.dfy; do
      [[ -e "$broken" ]] || continue
      name="$(basename "$broken" .dfy)"
      run_case "$slug: broken/$name reported as fail (not error)" "$broken" "$slug" "fail"
    done
  else
    echo "FAIL  $slug: missing .meta/broken/ directory"
    fail_count=$((fail_count + 1))
  fi
done

# Exercise-specific obligation-attribution checks (spot checks that the
# parser attributes failures to the right symbol, not just "some" symbol).
run_case "array-max: weak-invariant broken" \
  "$repo_root/exercises/practice/array-max/.meta/broken/weak-invariant.dfy" "array-max" "fail"
assert_test_status "array-max: Max obligation is the one that fails" "Max" "fail"

run_case "is-sorted-check: no-loop broken" \
  "$repo_root/exercises/practice/is-sorted-check/.meta/broken/no-loop.dfy" "is-sorted-check" "fail"
assert_test_status "is-sorted-check: IsSorted obligation is the one that fails" "IsSorted" "fail"
assert_test_status "is-sorted-check: SortedSpec obligation still passes" "SortedSpec" "pass"

run_case "binary-search: weak-invariant broken" \
  "$repo_root/exercises/practice/binary-search/.meta/broken/weak-invariant.dfy" "binary-search" "fail"
assert_test_status "binary-search: BinarySearch obligation is the one that fails" "BinarySearch" "fail"

run_case "list-reverse-involution: empty-body broken" \
  "$repo_root/exercises/practice/list-reverse-involution/.meta/broken/empty-body.dfy" "list-reverse-involution" "fail"
assert_test_status "list-reverse-involution: ReverseInvolution obligation is the one that fails" "ReverseInvolution" "fail"
assert_test_status "list-reverse-involution: ReverseDistributes obligation still passes" "ReverseDistributes" "pass"

run_case "sum-formula: empty-body broken" \
  "$repo_root/exercises/practice/sum-formula/.meta/broken/empty-body.dfy" "sum-formula" "fail"
assert_test_status "sum-formula: SumFormula obligation is the one that fails" "SumFormula" "fail"

echo
echo "======================================"
echo "$pass_count passed, $fail_count failed"
echo "======================================"

if [[ "$fail_count" -gt 0 ]]; then
  exit 1
fi
