#!/usr/bin/env sh
set -exc

cd repo
{
  echo "Repository: $(git config --get remote.origin.url)"
  echo "Branch: $(git rev-parse --abbrev-ref HEAD)"
  echo "Commit: $(git rev-parse HEAD)"
  echo "Short commit: $(git rev-parse --short HEAD)"
  echo "Author: $(git show -s --format='%an <%ae>' HEAD)"
  echo "Commit date: $(git show -s --format='%ci' HEAD)"
  echo "Commit subject: $(git show -s --format='%s' HEAD)"
} | tee ../source-metadata/source-version.txt

git show --stat --oneline --decorate --no-renames HEAD > ../source-metadata/commit-summary.txt
