#!/bin/bash -eu

# Copyright 2017 The Bazel Authors. All rights reserved.
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

# This template uses the `%(key)s` format for values that are
# substituted by the ios_unit_test and ios_ui_test rules before this script
# is executed. Check
# https://github.com/bazelbuild/rules_apple/blob/master/apple/testing/apple_test_rules.bzl
# for more info.

if [[ "%(test_type)s" = "XCUITEST" ]]; then
  echo "This runner only works with macos_unit_test (b/63707899)."
  exit 1
fi

# Retrieve the basename of a file or folder with an extension.
basename_without_extension() {
  local full_path="$1"
  local filename=$(basename "$full_path")
  echo "${filename%.*}"
}

# Location of the template xctestrun file to be used for the test. This file is
# used by xcodebuild to configure the test to be run. It is generated by Xcode
# when using Build For Testing, and the template file submitted is a trimmed
# and parameterized version of the one created by Xcode. For more information
# about this file, check `man xcodebuild.xctestrun`.
BAZEL_XCTESTRUN_TEMPLATE=%(xctestrun_template)s

# Create a temporary folder that will contain the test bundle and potentially
# the test host bundle as well.
TEST_TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/test_tmp_dir.XXXXXX")"
trap 'rm -rf "${TEST_TMP_DIR}"' ERR EXIT

TEST_BUNDLE_PATH="%(test_bundle_path)s"
TEST_BUNDLE_NAME=$(basename_without_extension "$TEST_BUNDLE_PATH")

if [[ "$TEST_BUNDLE_PATH" == *.xctest ]]; then
  cp -R "$TEST_BUNDLE_PATH" "$TEST_TMP_DIR"
  # Need to modify permissions as Bazel will set all files to non-writable, and
  # Xcode's test runner requires the files to be writable.
  chmod -R 777 "$TEST_TMP_DIR/$TEST_BUNDLE_NAME.xctest"
else
  unzip -qq -d "${TEST_TMP_DIR}" "${TEST_BUNDLE_PATH}"
fi
readonly test_binary="$TEST_TMP_DIR/${TEST_BUNDLE_NAME}.xctest/Contents/MacOS/$TEST_BUNDLE_NAME"

# In case there is no test host, TEST_HOST_PATH will be empty. TEST_BUNDLE_PATH
# will always be populated.
TEST_HOST_PATH="%(test_host_path)s"

if [[ -n "$TEST_HOST_PATH" ]]; then
  TEST_HOST_NAME=$(basename_without_extension "$TEST_HOST_PATH")

  if [[ "$TEST_HOST_PATH" == *.app ]]; then
    cp -R "$TEST_HOST_PATH" "$TEST_TMP_DIR"
    # Need to modify permissions as Bazel will set all files to non-writable,
    # and Xcode's test runner requires the files to be writable.
    chmod -R 777 "$TEST_TMP_DIR/$TEST_HOST_NAME.app"
  else
    unzip -qq -d "${TEST_TMP_DIR}" "${TEST_HOST_PATH}"
  fi
fi

# List of substitutions for the xctestrun template. This list is different
# depending on whether the test is running with or without a test host.
XCTESTRUN_TEST_BUNDLE_PATH="__TESTROOT__/$TEST_BUNDLE_NAME.xctest"
if [[ -n "$TEST_HOST_PATH" ]]; then
  XCTESTRUN_TEST_HOST_PATH="__TESTROOT__/$TEST_HOST_NAME.app"
  XCTESTRUN_TEST_HOST_BASED=true
  XCTESTRUN_TEST_HOST_BINARY="__TESTHOST__/Contents/MacOS/$TEST_HOST_NAME"
else
  XCTESTRUN_TEST_HOST_PATH="__PLATFORMS__/MacOSX.platform/Developer/Library/Xcode/Agents/xctest"
  XCTESTRUN_TEST_HOST_BASED=false
  XCTESTRUN_TEST_HOST_BINARY=""
fi

# Create a copy of the template in the temporary folder to be instantiated.
# This location is chosen so that the xctestrun __TESTROOT__ variable is set to
# the same folder where the test bundle and test host were unpacked.
XCTESTRUN="$TEST_TMP_DIR/tests.xctestrun"
cp -f "$BAZEL_XCTESTRUN_TEMPLATE" "$XCTESTRUN"

# Basic XML character escaping for environment variable substitution.
function escape() {
  escaped=${1//&/&amp;}
  escaped=${escaped//</&lt;}
  escaped=${escaped//>/&gt;}
  escaped=${escaped//'"'/&quot;}
  echo $escaped
}

# Add the test environment variables into the xctestrun file to propagate them
# to the test runner
TEST_ENV="%(test_env)s"
readonly profraw="$TEST_TMP_DIR/coverage.profraw"
if [[ "${COVERAGE:-}" -eq 1 ]]; then
  readonly profile_env="LLVM_PROFILE_FILE=$profraw"
  if [[ -n "$TEST_ENV" ]]; then
    TEST_ENV="$TEST_ENV,$profile_env"
  else
    TEST_ENV="$profile_env"
  fi
fi

XCTESTRUN_ENV=""
for SINGLE_TEST_ENV in ${TEST_ENV//,/ }; do
  IFS== read key value <<< "$SINGLE_TEST_ENV"
  XCTESTRUN_ENV+="<key>$(escape "$key")</key><string>$(escape "$value")</string>"
done

# Replace the substitution values into the xctestrun file.
/usr/bin/sed -i '' 's@BAZEL_TEST_BUNDLE_PATH@'"$XCTESTRUN_TEST_BUNDLE_PATH"'@g' "$XCTESTRUN"
/usr/bin/sed -i '' 's@BAZEL_TEST_HOST_BASED@'"$XCTESTRUN_TEST_HOST_BASED"'@g' "$XCTESTRUN"
/usr/bin/sed -i '' 's@BAZEL_TEST_HOST_BINARY@'"$XCTESTRUN_TEST_HOST_BINARY"'@g' "$XCTESTRUN"
/usr/bin/sed -i '' 's@BAZEL_TEST_HOST_PATH@'"$XCTESTRUN_TEST_HOST_PATH"'@g' "$XCTESTRUN"
/usr/bin/sed -i '' 's@BAZEL_TEST_ENVIRONMENT@'"$XCTESTRUN_ENV"'@g' "$XCTESTRUN"

# If XML_OUTPUT_FILE is not an absolute path, make it absolute with regards of
# where this script is being run.
if [[ "$XML_OUTPUT_FILE" != /* ]]; then
  export XML_OUTPUT_FILE="$PWD/$XML_OUTPUT_FILE"
fi

# Run xcodebuild with the xctestrun file just created. If the test failed, this
# command will return non-zero, which is enough to tell bazel that the test
# failed.
rm -rf "$TEST_UNDECLARED_OUTPUTS_DIR/test.xcresult"
xcodebuild test-without-building \
    -destination "platform=macOS" \
    -resultBundlePath "$TEST_UNDECLARED_OUTPUTS_DIR/test.xcresult" \
    -xctestrun "$XCTESTRUN"

if [[ "${COVERAGE:-}" -ne 1 ]]; then
  # Normal tests run without coverage
  exit 0
fi

readonly profdata="$TEST_TMP_DIR/coverage.profdata"
xcrun llvm-profdata merge "$profraw" --output "$profdata"

readonly export_error_file="$TEST_TMP_DIR/llvm-cov-export-error.txt"
llvm_cov_export_status=0
lcov_args=(
  -instr-profile "$profdata"
  -ignore-filename-regex='.*external/.+'
  -path-equivalence="$ROOT",.
)
xcrun llvm-cov \
  export \
  -format lcov \
  "${lcov_args[@]}" \
  "$test_binary" \
  @"$COVERAGE_MANIFEST" \
  > "$COVERAGE_OUTPUT_FILE" \
  2> "$export_error_file" \
  || llvm_cov_export_status=$?

# Error ourselves if lcov outputs warnings, such as if we misconfigure
# something and the file path of one of the covered files doesn't exist
if [[ -s "$export_error_file" || "$llvm_cov_export_status" -ne 0 ]]; then
  echo "error: while exporting coverage report" >&2
  cat "$export_error_file" >&2
  exit 1
fi

if [[ -n "${COVERAGE_PRODUCE_JSON:-}" ]]; then
  llvm_cov_json_export_status=0
  xcrun llvm-cov \
    export \
    -format text \
    "${lcov_args[@]}" \
    "$test_binary" \
    @"$COVERAGE_MANIFEST" \
    > "$TEST_UNDECLARED_OUTPUTS_DIR/coverage.json"
    2> "$export_error_file" \
    || llvm_cov_json_export_status=$?
  if [[ -s "$export_error_file" || "$llvm_cov_json_export_status" -ne 0 ]]; then
    echo "error: while exporting json coverage report" >&2
    cat "$export_error_file" >&2
    exit 1
  fi
fi

if [[ -n "${COVERAGE_PRODUCE_HTML:-}" ]]; then
  llvm_cov_html_export_status=0

  # TODO: Improve to use `@"$COVERAGE_MANIFEST"` to filter out unneccessary file on staticlib
  # reference: https://github.com/bazelbuild/rules_apple/pull/1490#discussion_r900379232
  xcrun llvm-cov \
    export \
    -format html \
    -use-color \
    -output-dir="$TEST_UNDECLARED_OUTPUTS_DIR/html" \
    "${lcov_args[@]}" \
    "$test_binary" \
    2> "$export_error_file" \
    || llvm_cov_html_export_status=$?
  if [[ -s "$export_error_file" || "$llvm_cov_html_export_status" -ne 0 ]]; then
    echo "error: while exporting html coverage report" >&2
    cat "$export_error_file" >&2
    exit 1
  fi
fi