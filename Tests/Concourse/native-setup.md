# Native Concourse Setup

This setup removes the repository's Docker Compose runtime. It runs Concourse,
Postgres, and the report artifact server as native processes or services.

It does not remove Concourse task images. Concourse runs `platform: linux` tasks
inside worker-managed containers, and this pipeline still needs Linux images for
.NET, Alpine, curl, git, Chromium, Java, and msmtp. Removing those images would
mean replacing Concourse tasks with a different non-container execution model.

## Required Hosts

Use a Linux host for the Concourse worker. The current pipeline tasks call
`apt-get`, `apk`, Linux Chromium packages, and Linux shell tooling.

On macOS, you can run `fly` and access the UI from the Mac, but the worker should
run on Linux. The previous Docker Compose setup supplied that Linux worker by
running `concourse/concourse` in Docker.

## Services

Install and run these without Docker:

- Postgres 15 or newer
- Concourse 8.x web node
- Concourse 8.x worker node
- Python 3 artifact server from `Concourse/artifact-server/server.py`

Use the same Concourse version for `concourse` and `fly`.

## Database

Create the database and user:

```sh
createuser concourse
createdb --owner=concourse concourse
psql -c "alter user concourse with password 'concourse';"
```

Use stronger credentials outside a local development machine.

## Keys

Generate keys on the Linux Concourse host:

```sh
mkdir -p ./concourse-keys
ssh-keygen -t rsa -b 4096 -m PEM -f ./concourse-keys/session_signing_key -N ''
ssh-keygen -t rsa -b 4096 -m PEM -f ./concourse-keys/tsa_host_key -N ''
ssh-keygen -t rsa -b 4096 -m PEM -f ./concourse-keys/worker_key -N ''
cp ./concourse-keys/worker_key.pub ./concourse-keys/authorized_worker_keys
```

## Start Concourse Web

```sh
concourse web \
  --external-url http://localhost:8080 \
  --postgres-host 127.0.0.1 \
  --postgres-database concourse \
  --postgres-user concourse \
  --postgres-password concourse \
  --add-local-user test:test \
  --main-team-local-user test \
  --session-signing-key ./concourse-keys/session_signing_key \
  --tsa-host-key ./concourse-keys/tsa_host_key \
  --tsa-authorized-keys ./concourse-keys/authorized_worker_keys
```

## Start Concourse Worker

Run the worker on Linux with sufficient privileges for its runtime:

```sh
sudo concourse worker \
  --work-dir /var/lib/concourse-worker \
  --tsa-host 127.0.0.1:2222 \
  --tsa-public-key ./concourse-keys/tsa_host_key.pub \
  --tsa-worker-private-key ./concourse-keys/worker_key \
  --runtime containerd \
  --containerd-dns-server 1.1.1.1 \
  --containerd-allow-host-access
```

## Start The Artifact Server

```sh
mkdir -p ./concourse-artifacts
ARTIFACT_DATA_DIRECTORY="$PWD/concourse-artifacts" \
  python3 Concourse/artifact-server/server.py
```

The server listens on port `8081`.

## Pipeline Variables

For the native setup, set these values in `Concourse/vars.yml`:

```yaml
artifact_internal_base_url: http://127.0.0.1:8081
artifact_public_base_url: http://localhost:8081
```

If the worker and artifact server are on different hosts, use an internal URL
that the worker can reach, and a public URL that your browser/email recipient can
open.

## Apply The Pipeline

```sh
./fly-concourse -t local login -c http://localhost:8080 -u test -p test
./fly-concourse -t local set-pipeline \
  -p qa-bdd-automation \
  -c Concourse/pipeline.yml \
  -l Concourse/vars.yml \
  -n
./fly-concourse -t local unpause-pipeline -p qa-bdd-automation
```

## What Still Uses Images

These task files still use Concourse `registry-image` resources:

- `tasks/install-deps.yml`, `tasks/build.yml`, `tasks/test.yml`, and
  `tasks/send-email.yml`: `mcr.microsoft.com/dotnet/sdk:8.0`
- `tasks/source-metadata.yml`: `alpine/git`
- `tasks/package-xray.yml`, `tasks/evaluate-status.yml`, and
  `tasks/github-status.yml`: `alpine:3.20`
- `tasks/publish-report.yml`: `curlimages/curl:8.12.1`

That is normal for Concourse. Docker Desktop and Docker Compose are no longer
part of this setup, but Concourse still uses OCI images for reproducible task
roots.
