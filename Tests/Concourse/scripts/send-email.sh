#!/usr/bin/env sh
# Do not enable shell tracing because this script handles SMTP credentials.
set -e

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl msmtp

source_revision="$(git -C repo rev-parse --short=12 HEAD)"
report_id="qa-bdd-automation-run-tests-${source_revision}"
internal_report_url="http://10.80.0.1:8081/reports/${report_id}"
report_url="http://localhost:8081/reports/${report_id}/allure-report.html"

work_directory="$(mktemp -d)"
smtp_config="${work_directory}/msmtprc"
email_message="${work_directory}/message.eml"
report_file="${work_directory}/allure-report.html"
summary_file="${work_directory}/test-summary.txt"
trap 'rm -rf "$work_directory"' EXIT HUP INT TERM

curl --fail --show-error \
  --output "$report_file" \
  "${internal_report_url}/allure-report.html"
curl --fail --show-error \
  --output "$summary_file" \
  "${internal_report_url}/test-summary.txt"

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
