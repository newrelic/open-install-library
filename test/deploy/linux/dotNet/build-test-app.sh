#!/bin/bash
# Builds and publishes a minimal ASP.NET Core web app on the test host.
# Usage: build-test-app.sh <output-dir> <app-name> <dotnet-channel> <self-contained: true|false>
#
# The SDK is installed under /opt/nr-test-sdk, outside the system .NET install,
# and is left there so later builds on the same host reuse it.
set -euo pipefail

OUTPUT_DIR=$1
APP_NAME=$2
DOTNET_CHANNEL=$3
SELF_CONTAINED=$4

SDK_ROOT=/opt/nr-test-sdk
SDK_DIR=${SDK_ROOT}/${DOTNET_CHANNEL}

export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
export DOTNET_CLI_HOME=${SDK_ROOT}/home
export NUGET_PACKAGES=${SDK_ROOT}/nuget
# Don't leave MSBuild/compiler server processes running: they are .NET processes
# that the .NET agent recipe would see.
export MSBUILDDISABLENODEREUSE=1
export DOTNET_CLI_USE_MSBUILD_SERVER=0

mkdir -p "${SDK_ROOT}"

# The services that use this script deploy in parallel, and small instances
# can't run two SDK installs or builds at once.
exec 9>"${SDK_ROOT}/build.lock"
flock 9

# Some distros (e.g. Amazon Linux 2023) mount /tmp as a small tmpfs, which can't
# hold the SDK archive while dotnet-install.sh extracts it, so use disk instead.
export TMPDIR=${SDK_ROOT}/tmp
mkdir -p "${TMPDIR}"

# The marker is written only after a complete install, so a partial install
# (e.g. from a full disk) is replaced, not reused.
if [[ ! -f "${SDK_DIR}/.install-complete" ]]; then
  rm -rf "${SDK_DIR}"
  curl -fsSL --retry 3 https://dot.net/v1/dotnet-install.sh -o "${SDK_ROOT}/dotnet-install.sh"
  bash "${SDK_ROOT}/dotnet-install.sh" --channel "${DOTNET_CHANNEL}" --install-dir "${SDK_DIR}"
  touch "${SDK_DIR}/.install-complete"
fi

WORK_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}"' EXIT

"${SDK_DIR}/dotnet" new web --name "${APP_NAME}" --output "${WORK_DIR}/src"

publish_args=(-c Release -o "${OUTPUT_DIR}" -p:UseSharedCompilation=false)
if [[ "${SELF_CONTAINED}" == "true" ]]; then
  case "$(uname -m)" in
    aarch64) runtime_id=linux-arm64 ;;
    *) runtime_id=linux-x64 ;;
  esac
  publish_args+=(-r "${runtime_id}" --self-contained true)
else
  publish_args+=(--self-contained false)
fi

"${SDK_DIR}/dotnet" publish "${WORK_DIR}/src" "${publish_args[@]}"
"${SDK_DIR}/dotnet" build-server shutdown > /dev/null 2>&1 || true
