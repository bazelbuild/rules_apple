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
# Asked to do a buildifier run.
if [[ -n "${BUILDIFIER:-}" ]]; then
  FOUND_ISSUES="no"

  # buildifier supports BUILD/WORKSPACE/*.bzl files, this provides the args
  # to reuse in all the finds.
  FIND_ARGS=(
      \(
          -name BUILD
          -o
          -name WORKSPACE
          -o
          -name "*.bzl"
      \)
  )

  # Check for format issues?
  if [[ "${FORMAT:-yes}" == "yes" ]] ; then
    echo "buildifier: validating formatting..."
    if ! find . "${FIND_ARGS[@]}" -print | xargs buildifier -d ; then
      echo ""
      echo "Please download the latest buildifier"
      echo "   https://github.com/bazelbuild/buildtools/releases"
      echo "and run it over the changed BUILD/.bzl files."
      echo ""
      FOUND_ISSUES="yes"
    fi
  fi

  # Check for lint issues?
  if [[ "${LINT:-yes}" == "yes" ]] ; then
    echo "buildifier: running lint checks..."
    # NOTE: buildifier defaults to --mode=fix, so these lint runs also
    # reformat the files. But since this is on travis, that is fine.
    # https://github.com/bazelbuild/buildtools/issues/453
    if ! find . "${FIND_ARGS[@]}" -print | xargs buildifier --lint=warn ; then
      echo ""
      echo "Please download the latest buildifier"
      echo "   https://github.com/bazelbuild/buildtools/releases"
      echo "and run it with --lint=(warn|fix) over the changed BUILD/.bzl files"
      echo "and make the edits as needed."
      echo ""
      FOUND_ISSUES="yes"
    fi
  fi

  # Anything?
  if [[ "${FOUND_ISSUES}" != "no" ]] ; then
    exit 1
  fi
fi
