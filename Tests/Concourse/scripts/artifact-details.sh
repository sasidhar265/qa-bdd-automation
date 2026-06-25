#!/usr/bin/env sh
set -eu

artifact_directory="xray-report-artifact"
allure_report_directory="${artifact_directory}/allure-report"
allure_index_path="${allure_report_directory}/index.html"
portable_allure_path="${artifact_directory}/allure-report.html"

echo "Allure report artifact directory: ${allure_report_directory}"
echo

if [ ! -d "${allure_report_directory}" ]; then
  echo "Allure report folder not found: ${allure_report_directory}"
  exit 1
fi

echo "Allure report folder contents:"
find "${allure_report_directory}" -maxdepth 2 -type f -exec ls -lh {} \; | sort
echo

if [ -f "${allure_index_path}" ]; then
  echo "Generated Allure index.html:"
  ls -lh "${allure_index_path}"
  echo
else
  echo "Generated Allure index.html not found: ${allure_index_path}"
  exit 1
fi

if [ -f "${portable_allure_path}" ]; then
  echo "Portable Allure HTML report:"
  ls -lh "${portable_allure_path}"
fi
