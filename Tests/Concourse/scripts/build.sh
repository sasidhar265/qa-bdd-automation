#!/usr/bin/env bash
set -exc

cp -a restored-repo/. built-repo/
cd built-repo

export NUGET_PACKAGES="$PWD/.nuget/packages"

# NuGet writes absolute package paths into project.assets.json. Concourse runs
# each task in a different working directory, so refresh the assets file before
# building with --no-restore.
dotnet restore QaAutomation.sln
dotnet build QaAutomation.sln --no-restore | tee ../build-status/build.log
build_exit_code=${PIPESTATUS[0]}

if [ "$build_exit_code" -eq 0 ]; then
  echo "Build status: PASSED" | tee ../build-status/build-status.txt
else
  echo "Build status: FAILED" | tee ../build-status/build-status.txt
  exit "$build_exit_code"
fi
