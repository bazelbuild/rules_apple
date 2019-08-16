#!/bin/bash

# Copyright 2019 The Bazel Authors. All rights reserved.
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

newline=$'\n'

# This script allows many of the functions in apple_shell_testutils.sh to be
# called through apple_verification_test_runner.sh.template by using environment
# variables.
#
# Supported operations:
#  CONTAINS: takes a list of files to test for existance
#  NOT_CONTAINS: takes a list of files to test for non-existance

# Test that the archive contains the specified files in the CONTAIN env var.
if [[ -n "${CONTAINS-}" ]]; then
  for path in "${CONTAINS[@]}"
  do
    if [[ ! -e "$ARCHIVE_ROOT/$path" ]]; then
      fail "Archive did not contain \"$path\"" \
        "contents were:$newline$(find $ARCHIVE_ROOT)"
    fi
  done
fi

# Test that the archive doesn't contains the specified files in NOT_CONTAINS.
if [[ -n "${NOT_CONTAINS-}" ]]; then
  for path in "${NOT_CONTAINS[@]}"
  do
    if [[ -e "$ARCHIVE_ROOT/$path" ]]; then
      fail "Archive did contain \"$path\""
    fi
  done
fi

