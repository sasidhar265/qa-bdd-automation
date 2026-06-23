#!/usr/bin/env sh
set -exc

cat test-results/test-summary.txt
test_exit_code="$(cat test-results/test-exit-code.txt)"

if [ "$test_exit_code" -ne 0 ]; then
  echo "One or more tests failed."
  exit "$test_exit_code"
fi

echo "All tests passed."
