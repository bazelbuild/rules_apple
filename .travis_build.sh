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

set -eu

# -------------------------------------------------------------------------------------------------
# Asked to do a bazel build.
if [[ -n "${BAZEL:-}" ]]; then
  # - Crank down the progress messages to not flood the travis log, but still
  #   provide some output so there is an indicator things aren't hung.
  # - "--test_output=errors" causes failures to report more completely since
  #   just getting the log file info isn't that useful on CI.
  set -x
  if [[ -n "${BUILD_TARGET:-}" ]]; then
    bazel \
      --bazelrc=/dev/null \
      build \
      --show_progress_rate_limit=30.0 \
      "${BUILD_TARGET}"
  fi
  bazel \
    --bazelrc=/dev/null \
    test \
    --show_progress_rate_limit=30.0 \
    --test_output=errors \
    "${TARGET}"
  set +x
fi

# -------------------------------------------------------------------------------------------------
# Asked to do a buildifier run.
if [[ -n "${BUILDIFER:-}" ]]; then
  # bazelbuild/buildtools/issues/220 - diff doesn't include the file that needs updating
  # bazelbuild/buildtools/issues/221 - the exist status is always zero.
  if [[ -n "$(find . -name BUILD -print | xargs buildifier -v -d)" ]]; then
    echo "ERROR: BUILD file formatting issue(s)"
    find . -name BUILD -print -exec buildifier -v -d {} \;
    exit 1
  fi
fi
