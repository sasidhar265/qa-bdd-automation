#!/usr/bin/env bash
set -exc

cp -a built-repo/. built-repo-working/
cd built-repo-working

artifacts_dir="$PWD/.."
results_dir="$artifacts_dir/test-results"
report_dir="$artifacts_dir/allure-report"
mkdir -p "$results_dir" "$report_dir"

export NUGET_PACKAGES="$PWD/.nuget/packages"
export PATH="$PWD/.tools/allure/bin:$PATH"
apt-get update
apt-get install -y --no-install-recommends \
  chromium \
  chromium-driver \
  default-jre-headless \
  python3

export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
export CHROME_BIN="$(command -v chromium || command -v chromium-browser)"
export CHROMEDRIVER_BIN="$(command -v chromedriver)"
export CHROME_HEADLESS=true

dotnet restore Tests/Tests.csproj

set +e
dotnet test Tests/Tests.csproj \
  --no-build \
  --logger "trx;LogFileName=test-results.trx" \
  --results-directory "$results_dir" \
  | tee "$results_dir/test-output.log"
test_exit_code=${PIPESTATUS[0]}
set -e

trx_file="$(find "$results_dir" -name '*.trx' | head -n 1)"
if [ -z "$trx_file" ]; then
  echo "No TRX result file was generated." | tee "$results_dir/test-summary.txt"
  exit 1
fi

python3 - "$trx_file" > "$results_dir/test-summary.txt" <<'PY'
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
ns = {"trx": "http://microsoft.com/schemas/VisualStudio/TeamTest/2010"}
counters = root.find(".//trx:Counters", ns)

def count(name):
    return counters.get(name, "0") if counters is not None else "0"

print(f"Total tests: {count('total')}")
print(f"Passed: {count('passed')}")
print(f"Failed: {count('failed')}")
print(f"Skipped: {count('notExecuted')}")

failed_results = root.findall(".//trx:UnitTestResult[@outcome='Failed']", ns)
if failed_results:
    print("\nFailed tests:")

for result in failed_results:
    print(f"- {result.get('testName', 'Unknown test')}")
    message = result.findtext(".//trx:Message", default="", namespaces=ns).strip()
    if message:
        print(f"  Reason: {message}")
PY

cat "$results_dir/test-summary.txt"
echo "$test_exit_code" > "$results_dir/test-exit-code.txt"

if [ -d Tests/allure-report ]; then
  cp -a Tests/allure-report/. "$report_dir/"
elif [ -d allure-report ]; then
  cp -a allure-report/. "$report_dir/"
else
  echo "Allure HTML report was not generated." > "$report_dir/report-status.txt"
fi

exit 0
