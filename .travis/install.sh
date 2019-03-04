#!/bin/bash

# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eux

if [[ "${TRAVIS_OS_NAME}" == "osx" ]]; then
  OS=darwin
else
  OS=linux
fi

# -------------------------------------------------------------------------------------------------
# Helper to use the github redirect to find the latest release.
function github_latest_release_tag() {
  local PROJECT=$1
  curl \
      -s \
      -o /dev/null \
      --write-out '%{redirect_url}' \
      "https://github.com/${PROJECT}/releases/latest" \
  | sed -e 's,https://.*/releases/tag/\(.*\),\1,'
}

# -------------------------------------------------------------------------------------------------
# Helper to install buildifier.
function install_buildifier() {
  local VERSION="${1}"

  if [[ "${VERSION}" == "RELEASE" ]]; then
    VERSION="$(github_latest_release_tag bazelbuild/buildtools)"
  fi

  if [[ "${VERSION}" == "HEAD" ]]; then
    echo "buildifier head is not supported"
    exit 1
  fi

  if [[ "${OS}" == "darwin" ]]; then
    URL="https://github.com/bazelbuild/buildtools/releases/download/${VERSION}/buildifier.osx"
  else
    URL="https://github.com/bazelbuild/buildtools/releases/download/${VERSION}/buildifier"
  fi

  mkdir -p "$HOME/bin"
  wget -O "${HOME}/bin/buildifier" "${URL}"
  chmod +x "${HOME}/bin/buildifier"
  buildifier --version
}

# -------------------------------------------------------------------------------------------------
# Install what is requested.
[[ -z "${BUILDIFIER:-}" ]] || install_buildifier "${BUILDIFIER}"
