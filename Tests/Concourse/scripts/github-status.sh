#!/usr/bin/env sh
set -ec

apk add --no-cache curl git

if [ -z "$GITHUB_TOKEN" ]; then
  echo "GITHUB_TOKEN is required to update GitHub commit status."
  exit 1
fi

case "$GITHUB_STATUS_STATE" in
  pending|success|failure|error) ;;
  *)
    echo "GITHUB_STATUS_STATE must be pending, success, failure, or error."
    exit 1
    ;;
esac

cd repo
commit_sha="$(git rev-parse HEAD)"
remote_url="$(git config --get remote.origin.url)"

repository_path="$(printf '%s' "$remote_url" \
  | sed -E 's#^https://github.com/##; s#^git@github.com:##; s#\.git$##')"

if ! printf '%s' "$repository_path" | grep -Eq '^[^/]+/[^/]+$'; then
  echo "Unable to derive GitHub owner/repository from remote URL: $remote_url"
  exit 1
fi

if [ -z "$GITHUB_STATUS_TARGET_URL" ] && [ -n "${ATC_EXTERNAL_URL:-}" ]; then
  GITHUB_STATUS_TARGET_URL="${ATC_EXTERNAL_URL}/teams/${BUILD_TEAM_NAME}/pipelines/${BUILD_PIPELINE_NAME}/jobs/${BUILD_JOB_NAME}/builds/${BUILD_NAME}"
fi

payload="$(cat <<EOF
{
  "state": "$GITHUB_STATUS_STATE",
  "target_url": "$GITHUB_STATUS_TARGET_URL",
  "description": "$GITHUB_STATUS_DESCRIPTION",
  "context": "$GITHUB_STATUS_CONTEXT"
}
EOF
)"

curl --fail --show-error \
  --request POST \
  --header "Accept: application/vnd.github+json" \
  --header "Authorization: Bearer ${GITHUB_TOKEN}" \
  --header "X-GitHub-Api-Version: 2022-11-28" \
  --data "$payload" \
  "https://api.github.com/repos/${repository_path}/statuses/${commit_sha}"
