#!/usr/bin/env bash
# Zero-dependency test runner: executes each tests/test_*.sh, reports pass/fail.
set -uo pipefail

cd "$(dirname "$0")/.."
pass=0
fail=0
for t in tests/test_*.sh; do
  if bash "$t" >/tmp/hf-codex-test.out 2>&1; then
    echo "PASS $t"
    pass=$((pass + 1))
  else
    echo "FAIL $t"
    sed 's/^/    /' /tmp/hf-codex-test.out
    fail=$((fail + 1))
  fi
done
echo "---"
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
