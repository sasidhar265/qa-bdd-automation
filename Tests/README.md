# QA BDD Automation

## Run the Concourse pipeline locally with Docker

This project includes a local Concourse setup under `Concourse/`.

The local Concourse stack contains:

- `concourse/concourse:7`
- `postgres:15`
- a local Concourse user: `test` / `test`
- the pipeline file: `Concourse/pipeline.yml`

## Prerequisites

Install and start Docker Desktop.

Use the Concourse `fly` CLI, not the Fly.io `fly` CLI. If `fly --help` says `flyctl` or `Fly.io`, that is the wrong CLI for Concourse.

The examples below download the Concourse CLI as `./fly-concourse` so it does not conflict with any existing `fly` command.

## 1. Start Concourse

```sh
docker compose -f Concourse/docker-compose.yml up -d
```

Check that both containers are running:

```sh
docker compose -f Concourse/docker-compose.yml ps
```

Expected services:

- `concourse`
- `concourse-db`

Open the Concourse UI:

```text
http://localhost:8080
```

Login with:

- username: `test`
- password: `test`

## 2. Install the Concourse fly CLI

For Apple Silicon Macs:

```sh
curl -L 'http://localhost:8080/api/v1/cli?arch=arm64&platform=darwin' -o fly-concourse
chmod +x fly-concourse
./fly-concourse --version
```

For Intel Macs:

```sh
curl -L 'http://localhost:8080/api/v1/cli?arch=amd64&platform=darwin' -o fly-concourse
chmod +x fly-concourse
./fly-concourse --version
```

The version should be a Concourse version, for example:

```text
7.14.3
```

## 3. Login to local Concourse

```sh
./fly-concourse -t local login -c http://localhost:8080 -u test -p test
```

This creates a local target named `local`.

## 4. Create or update the pipeline

Configure the scheduler and SMTP settings in the ignored
`Concourse/vars.yml` file. The recipient is configured as
`sasidhar265@gmail.com` in `Concourse/pipeline.yml`.

```yaml
daily_schedule_start_after: "2026-06-23 07:00:00"
daily_schedule_timezone: Europe/London

smtp_host: smtp.gmail.com
smtp_port: "587"
smtp_username: your-email@gmail.com
smtp_password: your-gmail-app-password
email_from: your-email@gmail.com
```

```sh
./fly-concourse -t local set-pipeline \
  -p qa-bdd-automation \
  -c Concourse/pipeline.yml \
  -l Concourse/vars.yml \
  -n
```

The pipeline uses three separate jobs:

- `scheduler` emits one trigger during the configured daily time window.
- `run-tests` starts for each new `main` revision and from the daily trigger, then publishes the report.
- `send-email` runs after a successful test job and emails the published report.

Configure `daily_schedule_start_after` and `daily_schedule_timezone` in
`Concourse/vars.yml`. The first run occurs on or after that timestamp, followed
by one run every 24 hours. The `-n` flag applies the pipeline without an
interactive confirmation prompt.

## 5. Unpause the pipeline

Concourse creates new pipelines in a paused state. Unpause it before running jobs:

```sh
./fly-concourse -t local unpause-pipeline -p qa-bdd-automation
```

Verify the pipeline is available:

```sh
./fly-concourse -t local pipelines
```

## 6. Check the git resource

The pipeline uses this git resource:

```yaml
resources:
  - name: repo
    type: git
    source:
      uri: https://github.com/sasidhar265/qa-bdd-automation.git
      branch: main
```

Force Concourse to check the repository:

```sh
./fly-concourse -t local check-resource -r qa-bdd-automation/repo
```

If this fails with `Could not resolve host: github.com`, the Concourse worker container cannot reach GitHub DNS. Check Docker Desktop networking and retry after restarting Concourse:

```sh
docker compose -f Concourse/docker-compose.yml restart concourse
./fly-concourse -t local check-resource -r qa-bdd-automation/repo
```

The Docker Compose file already enables Concourse DNS proxy settings for local Docker Desktop runs.

## 7. Trigger the pipeline job

```sh
./fly-concourse -t local trigger-job \
  -j qa-bdd-automation/run-tests \
  -w
```

The `-w` flag streams the build logs in the terminal.

## Useful commands

List pipelines:

```sh
./fly-concourse -t local pipelines
```

List jobs:

```sh
./fly-concourse -t local jobs -p qa-bdd-automation
```

List builds for the test job:

```sh
./fly-concourse -t local builds -j qa-bdd-automation/run-tests
```

Watch Concourse logs:

```sh
docker compose -f Concourse/docker-compose.yml logs -f concourse
```

Stop Concourse:

```sh
docker compose -f Concourse/docker-compose.yml down
```

Stop Concourse and remove the Postgres data volume:

```sh
docker compose -f Concourse/docker-compose.yml down -v
```

## Important notes

The pipeline runs code from GitHub `main`, not directly from uncommitted local files. Commit and push changes before expecting Concourse to run them.

The existing local binary `fly-concourse` is intentionally named this way to avoid confusion with the Fly.io CLI, which also uses the command name `fly`.
