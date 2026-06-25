#!/usr/bin/env sh
set -eu

artifact_directory="xray-report-artifact"
archive_path="${artifact_directory}/allure-report-for-xray.tar.gz"

echo "Artifact directory: ${artifact_directory}"
echo

echo "Stored artifact files:"
find "${artifact_directory}" -type f -exec ls -lh {} \; | sort
echo

echo "Stored artifact directories:"
find "${artifact_directory}" -type d | sort
echo

if [ -f "${archive_path}" ]; then
  echo "Archive contents: ${archive_path}"
  tar -tzf "${archive_path}" | sort
  echo
else
  echo "Archive not found: ${archive_path}"
  exit 1
fi

for file in \
  source-version.txt \
  commit-summary.txt \
  test-summary.txt \
  xray-upload-instructions.txt
do
  path="${artifact_directory}/${file}"
  if [ -f "${path}" ]; then
    echo "----- ${file} -----"
    cat "${path}"
    echo
  else
    echo "Missing artifact detail file: ${path}"
  fi
done
