#!/usr/bin/env sh
set -ex

apk add --no-cache git

source_revision="$(git -C repo rev-parse --short=12 HEAD)"
report_id="qa-bdd-automation-run-tests-${source_revision}"
artifact_internal_base_url="${ARTIFACT_INTERNAL_BASE_URL:-http://10.80.0.1:8081}"
artifact_public_base_url="${ARTIFACT_PUBLIC_BASE_URL:-http://localhost:8081}"
internal_report_url="${artifact_internal_base_url}/reports/${report_id}"
report_url="${artifact_public_base_url}/reports/${report_id}/allure-report.html"

mkdir -p report-metadata published-report
cp xray-report-artifact/allure-report.html published-report/allure-report.html

curl --fail --show-error \
  --request POST \
  --header "Content-Type: application/gzip" \
  --data-binary @xray-report-artifact/allure-report-for-xray.tar.gz \
  "$internal_report_url"

curl --fail --show-error \
  --output /dev/null \
  "${internal_report_url}/allure-report.html"

echo "$report_id" | tee report-metadata/report-id.txt
echo "$report_url" | tee report-metadata/report-url.txt
echo "Published portable Allure HTML report: $report_url"
