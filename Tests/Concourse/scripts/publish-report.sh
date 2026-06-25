#!/usr/bin/env sh
set -e

apk add --no-cache git

source_revision="$(git -C repo rev-parse --short=12 HEAD)"
report_id="qa-bdd-automation-run-tests-${source_revision}"
upload_base_url="${REPORT_UPLOAD_BASE_URL%/}"
public_base_url="${REPORT_PUBLIC_BASE_URL%/}"
upload_method="${REPORT_UPLOAD_METHOD:-PUT}"
upload_full_allure_dir="${REPORT_UPLOAD_FULL_ALLURE_DIR:-false}"

if [ -z "$upload_base_url" ]; then
  echo "REPORT_UPLOAD_BASE_URL must be set to the report storage upload URL."
  exit 1
fi

if [ -z "$public_base_url" ]; then
  echo "REPORT_PUBLIC_BASE_URL must be set to the browser-accessible report URL."
  exit 1
fi

report_upload_url="${upload_base_url}/${report_id}"
report_url="${public_base_url}/${report_id}/allure-report.html"

upload_file() {
  source_path="$1"
  target_name="$2"
  target_url="${report_upload_url}/${target_name}"
  content_type="application/octet-stream"

  case "$target_name" in
    *.html) content_type="text/html; charset=utf-8" ;;
    *.txt) content_type="text/plain; charset=utf-8" ;;
    *.json) content_type="application/json" ;;
    *.js) content_type="application/javascript" ;;
    *.css) content_type="text/css" ;;
    *.svg) content_type="image/svg+xml" ;;
    *.png) content_type="image/png" ;;
    *.jpg|*.jpeg) content_type="image/jpeg" ;;
    *.gif) content_type="image/gif" ;;
    *.woff) content_type="font/woff" ;;
    *.woff2) content_type="font/woff2" ;;
    *.tar.gz|*.tgz) content_type="application/gzip" ;;
  esac

  if [ -n "${REPORT_UPLOAD_AUTH_HEADER:-}" ]; then
    curl --fail --show-error \
      --request "$upload_method" \
      --header "$REPORT_UPLOAD_AUTH_HEADER" \
      --header "Content-Type: $content_type" \
      --upload-file "$source_path" \
      "$target_url"
  else
    curl --fail --show-error \
      --request "$upload_method" \
      --header "Content-Type: $content_type" \
      --upload-file "$source_path" \
      "$target_url"
  fi
}

mkdir -p report-metadata published-report
cp xray-report-artifact/allure-report.html published-report/allure-report.html

upload_file xray-report-artifact/allure-report.html allure-report.html
upload_file xray-report-artifact/test-summary.txt test-summary.txt
upload_file xray-report-artifact/allure-report-for-xray.tar.gz allure-report-for-xray.tar.gz

if [ "$upload_full_allure_dir" = "true" ]; then
  find xray-report-artifact/allure-report -type f | while IFS= read -r report_file; do
    relative_path="${report_file#xray-report-artifact/}"
    upload_file "$report_file" "$relative_path"
  done
fi

echo "$report_id" | tee report-metadata/report-id.txt
echo "$report_url" | tee report-metadata/report-url.txt
echo "Published portable Allure HTML report: $report_url"
