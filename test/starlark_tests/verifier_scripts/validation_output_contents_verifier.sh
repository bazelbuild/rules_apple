#!/bin/bash

# Copyright 2026 The Bazel Authors. All rights reserved.
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

set -euo pipefail

# Loads the unittest framework for common assert methods.
source test/unittest.bash

# Pre-declare expected arrays so set -u does not fail if empty
declare -a EXPECTED_CONTENTS=() NOT_EXPECTED_CONTENTS=()

# Parse any environmental variables passed into bash arrays.
if [[ -n "${APPLE_TEST_ENV_KEYS-}" ]]; then
  for key in $APPLE_TEST_ENV_KEYS; do
    eval "declare -a ${key}"
    eval "${key}=()"
    i="0"
    while eval "[[ -n \${APPLE_TEST_ENV_${key}_${i}-} ]]"; do
      eval "${key}+=(\"\${APPLE_TEST_ENV_${key}_${i}}\")"
      i=$((i + 1))
    done
  done
fi

validation_file="${VALIDATION_FILE}"
if [[ "$validation_file" != /* ]]; then
  validation_file="${PWD}/${validation_file}"
fi

echo "=== Inspecting Validation Output File ==="
echo "Validation file path: ${validation_file}"
if [[ ! -f "${validation_file}" ]]; then
  fail "Validation file ${validation_file} does not exist. Validation action was not executed!"
fi
file_contents=$(cat "${validation_file}")
echo "=== Validation File Contents ==="
printf "%s\n" "${file_contents}"
echo "================================="

if [[ "${ALLOW_EMPTY:-false}" != "true" ]]; then
  if [[ -z "${file_contents}" ]]; then
    fail "Validation file ${validation_file} is empty. Expected non-empty validation output!"
  fi
fi

if [[ ${#EXPECTED_CONTENTS[@]} -gt 0 ]]; then
  for expected in "${EXPECTED_CONTENTS[@]}"; do
    if ! grep -Fq -- "${expected}" "${validation_file}"; then
      fail "Expected validation file to contain '${expected}', but got: ${file_contents}"
    fi
  done
fi

if [[ ${#NOT_EXPECTED_CONTENTS[@]} -gt 0 ]]; then
  for not_expected in "${NOT_EXPECTED_CONTENTS[@]}"; do
    if grep -Fq -- "${not_expected}" "${validation_file}"; then
      fail "Validation file contains unexpected '${not_expected}'"
    fi
  done
fi

echo "PASS: Validation action execution verified successfully."
