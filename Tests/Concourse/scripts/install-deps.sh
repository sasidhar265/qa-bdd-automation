#!/usr/bin/env bash
set -exc

cp -a repo/. restored-repo/
cd restored-repo

export NUGET_PACKAGES="$PWD/.nuget/packages"
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  default-jre-headless \
  gzip \
  tar

export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
dotnet restore QaAutomation.sln

mkdir -p .tools
curl -fsSL \
  https://repo.maven.apache.org/maven2/io/qameta/allure/allure-commandline/2.29.0/allure-commandline-2.29.0.tgz \
  -o .tools/allure-commandline.tgz
tar -xzf .tools/allure-commandline.tgz -C .tools
mv .tools/allure-2.29.0 .tools/allure
.tools/allure/bin/allure --version
