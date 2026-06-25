#!/usr/bin/env sh
# Do not enable shell tracing because this script handles SMTP credentials.
set -e

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl msmtp

source_revision="$(git -C repo rev-parse --short=12 HEAD)"
report_id="qa-bdd-automation-run-tests-${source_revision}"
public_base_url="${REPORT_PUBLIC_BASE_URL%/}"
download_base_url="${REPORT_DOWNLOAD_BASE_URL:-$REPORT_PUBLIC_BASE_URL}"
download_base_url="${download_base_url%/}"

if [ -z "$public_base_url" ]; then
  echo "REPORT_PUBLIC_BASE_URL must be set to the browser-accessible report URL."
  exit 1
fi

if [ -z "$download_base_url" ]; then
  echo "REPORT_DOWNLOAD_BASE_URL or REPORT_PUBLIC_BASE_URL must be set to download the report."
  exit 1
fi

report_url="${public_base_url}/${report_id}/allure-report.html"
report_download_url="${download_base_url}/${report_id}"

work_directory="$(mktemp -d)"
smtp_config="${work_directory}/msmtprc"
email_message="${work_directory}/message.eml"
report_file="${work_directory}/allure-report.html"
summary_file="${work_directory}/test-summary.txt"
trap 'rm -rf "$work_directory"' EXIT HUP INT TERM

curl --fail --show-error \
  --output "$report_file" \
  "${report_download_url}/allure-report.html"
curl --fail --show-error \
  --output "$summary_file" \
  "${report_download_url}/test-summary.txt"

smtp_password="$SMTP_PASSWORD"
if [ "$SMTP_HOST" = "smtp.gmail.com" ]; then
  smtp_password="$(printf '%s' "$SMTP_PASSWORD" | tr -d '[:space:]')"
fi

umask 077
cat > "$smtp_config" <<EOF
defaults
auth on
tls on
tls_starttls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt

account concourse
host $SMTP_HOST
port $SMTP_PORT
user $SMTP_USERNAME
password $smtp_password
from $EMAIL_FROM

account default : concourse
EOF

mime_boundary="allure-report-$(date +%s)"
{
  echo "From: $EMAIL_FROM"
  echo "To: $EMAIL_TO"
  echo "Subject: [Concourse] QA BDD tests PASSED"
  echo "MIME-Version: 1.0"
  echo "Content-Type: multipart/mixed; boundary=$mime_boundary"
  echo
  echo "--$mime_boundary"
  echo "Content-Type: text/plain; charset=UTF-8"
  echo
  echo "QA BDD automation test status: PASSED"
  echo
  cat "$summary_file"
  echo
  echo "Allure HTML report: $report_url"
  echo "A portable copy is attached as allure-report.html."
  echo
  echo "--$mime_boundary"
  echo 'Content-Type: text/html; charset=UTF-8; name="allure-report.html"'
  echo 'Content-Disposition: attachment; filename="allure-report.html"'
  echo "Content-Transfer-Encoding: base64"
  echo
  base64 "$report_file"
  echo
  echo "--$mime_boundary--"
} > "$email_message"

msmtp --file="$smtp_config" "$EMAIL_TO" < "$email_message"
