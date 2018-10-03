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
      build \
      --show_progress_rate_limit=30.0 \
      "${BUILD_TARGET}"
  fi
  TEST_ARGS=(
    test
    --show_progress_rate_limit=30.0
    --test_output=errors
    --spawn_strategy=local
  )
  if [[ -n "${TAGS:-}" ]]; then
    TEST_ARGS+=( "--test_tag_filters=${TAGS}")
  fi
  bazel "${TEST_ARGS[@]}" "${TARGET}"
  set +x
fi

# -------------------------------------------------------------------------------------------------
# Asked to do a buildifier run.
if [[ -n "${BUILDIFER:-}" ]]; then
  # bazelbuild/buildtools/issues/220 - diff doesn't include the file that needs updating
  if ! find . \( -name BUILD -o -name "*.bzl" \) -print | xargs buildifier -d > /dev/null 2>&1 ; then
    echo "ERROR: BUILD/.bzl file formatting issue(s):"
    echo ""
    find . \( -name BUILD -o -name "*.bzl" \) -print -exec buildifier -v -d {} \;
    echo ""
    echo "Please download the latest buildifier"
    echo "   https://github.com/bazelbuild/buildtools/releases"
    echo "and run it over the changed BUILD/.bzl files."
    exit 1
  fi
fi
