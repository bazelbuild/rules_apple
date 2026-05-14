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

readonly coverage_env_file=%{coverage_env_file}s
readonly coverage_manifest=%{coverage_manifest}s
readonly expected_coverage_file=%{expected_coverage_file}s
readonly expected_json_file=%{expected_json_file}s
readonly expected_source_files=%{expected_source_files}s
readonly produce_json=%{produce_json}s
readonly test_executable=%{test_executable}s

mkdir -p "$TEST_TMPDIR" "$TEST_UNDECLARED_OUTPUTS_DIR"

export COVERAGE=1
export COVERAGE_DIR="$TEST_TMPDIR/coverage"
export COVERAGE_MANIFEST="$coverage_manifest"
export COVERAGE_OUTPUT_FILE="$TEST_UNDECLARED_OUTPUTS_DIR/coverage.dat"
mkdir -p "$COVERAGE_DIR"

if [[ "$produce_json" == "1" ]]; then
  export COVERAGE_PRODUCE_JSON=1
fi

while IFS= read -r env_entry || [[ -n "$env_entry" ]]; do
  if [[ -n "$env_entry" ]]; then
    export "${env_entry?}"
  fi
done < "$coverage_env_file"

"$test_executable"

if [[ ! -s "$COVERAGE_OUTPUT_FILE" ]]; then
  echo "Coverage output was not generated: $COVERAGE_OUTPUT_FILE" >&2
  exit 1
fi

while IFS= read -r expected || [[ -n "$expected" ]]; do
  if ! grep -F -- "$expected" "$COVERAGE_OUTPUT_FILE" >/dev/null; then
    echo "Coverage output did not contain expected text: $expected" >&2
    cat "$COVERAGE_OUTPUT_FILE" >&2
    exit 1
  fi
done < "$expected_coverage_file"

if [[ -s "$expected_source_files" ]]; then
  sed -n 's/^SF://p' "$COVERAGE_OUTPUT_FILE" | sort -u > "$TEST_TMPDIR/actual_source_files"
  sort -u "$expected_source_files" > "$TEST_TMPDIR/sorted_expected_source_files"
  if ! diff -u "$TEST_TMPDIR/sorted_expected_source_files" "$TEST_TMPDIR/actual_source_files"; then
    echo "Coverage output contained unexpected source files" >&2
    cat "$COVERAGE_OUTPUT_FILE" >&2
    exit 1
  fi
fi

if [[ -s "$expected_json_file" ]]; then
  readonly json_coverage="$TEST_UNDECLARED_OUTPUTS_DIR/coverage.json"
  if [[ ! -s "$json_coverage" ]]; then
    echo "JSON coverage output was not generated: $json_coverage" >&2
    exit 1
  fi

  while IFS= read -r expected || [[ -n "$expected" ]]; do
    if ! grep -F -- "$expected" "$json_coverage" >/dev/null; then
      echo "JSON coverage output did not contain expected text: $expected" >&2
      cat "$json_coverage" >&2
      exit 1
    fi
  done < "$expected_json_file"
fi
