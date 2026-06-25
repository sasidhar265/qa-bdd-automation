# Concourse Pipeline Guide

This directory contains the Concourse pipeline and the scripts used by each
pipeline task.

## File Layout

- `pipeline.yml` defines resources, jobs, task order, scheduled execution, main
  branch execution, feature branch execution, email notification, and GitHub PR
  status updates.
- `tasks/*.yml` are Concourse task wrappers. They declare the Docker image,
  inputs, outputs, parameters, and the script to run.
- `scripts/*.sh` contain the executable task logic. Edit these files when the
  behavior of a task needs to change.
- `vars.example.yml` documents required pipeline variables. Copy the values into
  ignored `vars.yml` for local pipeline setup.
- `docker-compose.yml` starts local Concourse and Postgres.
- Generated Allure reports are uploaded to the configured external report
  storage.

## Jobs

### `scheduler`

Reads the `daily-schedule` time resource. This job exists only to create a
scheduled gate for daily main-branch test runs.

### `run-tests`

Runs the full QA chain for `main_branch`.

This job starts when either:

- the schedule emits a new version, or
- the `repo` git resource has a new version.

Task order:

1. `source-metadata`
2. `install-deps`
3. `build`
4. `test`
5. `package-xray`
6. `artifact-details`
7. `publish-report`
8. `evaluate-status`

### `run-feature-tests`

Runs the same QA chain for `feature_branch`. The feature branch resource is
checked out as `repo` so all task wrappers and scripts use the same input name.

This job also posts GitHub commit statuses for the feature branch commit:

- `pending` before the QA chain starts
- `success` after all checks pass
- `failure` if any check fails

The status context is `qa-bdd-automation/pr-deployment` by default.

### `send-email`

Runs after a successful `run-tests` build and sends the published Allure report
by email. It downloads the report from the configured report storage instead of
using a worker-local HTTP server.

## Report Storage

The pipeline does not store reports on `localhost`. The `publish-report` task
uploads the generated report files to an external artifact endpoint, and the
`send-email` task downloads the same published files when preparing the email.

Required variables:

- `report_upload_base_url`: upload destination used by `publish-report`
- `report_public_base_url`: browser URL written to logs and email
- `report_download_base_url`: download URL used by `send-email`
- `report_upload_method`: HTTP method for uploads, normally `PUT`
- `report_upload_auth_header`: optional auth header for upload requests

The uploaded path is based on the short commit SHA:

```text
<report_public_base_url>/qa-bdd-automation-run-tests-<commit>/allure-report.html
```

The publish task uploads the portable `allure-report.html`, the readable
`test-summary.txt`, the compressed `allure-report-for-xray.tar.gz`, and the full
`allure-report/` directory.

## Task And Script Reference

### `source-metadata`

- Wrapper: `tasks/source-metadata.yml`
- Script: `scripts/source-metadata.sh`
- Input: `repo`
- Output: `source-metadata`

Writes commit metadata and a short commit summary. These files are packaged with
the report artifact.

### `install-deps`

- Wrapper: `tasks/install-deps.yml`
- Script: `scripts/install-deps.sh`
- Input: `repo`
- Output: `restored-repo`

Copies the repository into `restored-repo`, installs OS dependencies needed for
restore and Allure, restores NuGet packages, and downloads the Allure CLI.

### `build`

- Wrapper: `tasks/build.yml`
- Script: `scripts/build.sh`
- Inputs: `repo`, `restored-repo`
- Outputs: `built-repo`, `build-status`

Copies the restored repository into `built-repo`, refreshes NuGet assets for the
new Concourse task directory, builds the solution, and writes build status files.

### `test`

- Wrapper: `tasks/test.yml`
- Script: `scripts/test.sh`
- Inputs: `repo`, `built-repo`
- Outputs: `test-results`, `allure-report`

Installs browser test dependencies, runs the NUnit/Reqnroll tests, captures TRX
results, writes a readable test summary, and copies the generated Allure report.
This task exits `0` even when tests fail so downstream report packaging can still
run. `evaluate-status` fails the build later using `test-exit-code.txt`.

### `package-xray`

- Wrapper: `tasks/package-xray.yml`
- Script: `scripts/package-xray.sh`
- Inputs: `repo`, `source-metadata`, `test-results`, `allure-report`
- Output: `xray-report-artifact`

Builds a gzip archive containing the Allure report and supporting metadata for
manual Jira Xray attachment.

### `artifact-details`

- Wrapper: `tasks/artifact-details.yml`
- Script: `scripts/artifact-details.sh`
- Inputs: `repo`, `xray-report-artifact`

Prints the packaged Allure report folder contents and generated `index.html`
details into the Concourse build log.

### `publish-report`

- Wrapper: `tasks/publish-report.yml`
- Script: `scripts/publish-report.sh`
- Inputs: `repo`, `xray-report-artifact`
- Outputs: `report-metadata`, `published-report`
- Parameters:
  - `REPORT_UPLOAD_BASE_URL`
  - `REPORT_PUBLIC_BASE_URL`
  - `REPORT_UPLOAD_METHOD`
  - `REPORT_UPLOAD_AUTH_HEADER`

Uploads the packaged report files to `REPORT_UPLOAD_BASE_URL` and records the
report identifier and browser URL built from `REPORT_PUBLIC_BASE_URL`.

### `evaluate-status`

- Wrapper: `tasks/evaluate-status.yml`
- Script: `scripts/evaluate-status.sh`
- Inputs: `repo`, `test-results`

Reads the stored test exit code and fails the Concourse build if any test failed.

### `github-status`

- Wrapper: `tasks/github-status.yml`
- Script: `scripts/github-status.sh`
- Input: `repo`
- Parameters:
  - `GITHUB_TOKEN`
  - `GITHUB_STATUS_STATE`
  - `GITHUB_STATUS_CONTEXT`
  - `GITHUB_STATUS_DESCRIPTION`
  - `GITHUB_STATUS_TARGET_URL`

Posts a commit status to GitHub for the checked-out commit. This is used by
`run-feature-tests` to report PR deployment/check status.

### `send-email`

- Wrapper: `tasks/send-email.yml`
- Script: `scripts/send-email.sh`
- Input: `repo`
- Parameters:
  - `SMTP_HOST`
  - `SMTP_PORT`
  - `SMTP_USERNAME`
  - `SMTP_PASSWORD`
  - `EMAIL_FROM`
  - `EMAIL_TO`
  - `REPORT_PUBLIC_BASE_URL`
  - `REPORT_DOWNLOAD_BASE_URL`

Downloads the published report and summary from the configured report storage
and sends an email with the portable Allure HTML report attached.

## Changing The Pipeline

- Change job order, triggers, resources, or GitHub status wiring in
  `pipeline.yml`.
- Change task behavior in `scripts/*.sh`.
- Change task inputs, outputs, Docker images, or params in `tasks/*.yml`.
- Add new secret or runtime variables to `vars.example.yml`, then set real
  values in ignored `vars.yml`.

## Validation

Validate pipeline syntax before applying it:

```sh
./fly-concourse validate-pipeline -c Concourse/pipeline.yml
```

Validate script syntax locally:

```sh
bash -n Concourse/scripts/install-deps.sh
bash -n Concourse/scripts/build.sh
bash -n Concourse/scripts/test.sh
sh -n Concourse/scripts/source-metadata.sh
sh -n Concourse/scripts/package-xray.sh
sh -n Concourse/scripts/publish-report.sh
sh -n Concourse/scripts/evaluate-status.sh
sh -n Concourse/scripts/github-status.sh
sh -n Concourse/scripts/send-email.sh
```
