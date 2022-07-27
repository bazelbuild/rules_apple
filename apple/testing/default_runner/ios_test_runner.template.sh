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

set -e

basename_without_extension() {
  local full_path="$1"
  local filename
  filename=$(basename "$full_path")
  echo "${filename%.*}"
}

custom_xctestrunner_args=()
command_line_args=()
device_id=""
platform=""
while [[ $# -gt 0 ]]; do
  arg="$1"
  case $arg in
    --destination=platform=*,id=*)
      device_id="${arg##*=}"
      platform="${arg#*platform=}" # Strip "--destination=platform=" prefix
      platform="${platform%,id=*}" # Strip suffix starting with ",id="
      ;;
    --command_line_args=*)
      command_line_args+=("${arg##*=}")
      ;;
    *)
      custom_xctestrunner_args+=("$arg")
      ;;
  esac
  shift
done

# Enable verbose output in test runner.
runner_flags=("-v")

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/test_runner_work_dir.XXXXXX")"
trap 'rm -rf "${TMP_DIR}"' ERR EXIT
runner_flags+=("--work_dir=${TMP_DIR}")

TEST_BUNDLE_PATH="%(test_bundle_path)s"

if [[ "$TEST_BUNDLE_PATH" == *.xctest ]]; then
  # Need to copy the bundle outside of the Bazel execroot since the test runner
  # needs to make some modifications to its contents.
  # TODO(kaipi): Improve xctestrunner to account for Bazel permissions.
  cp -RL "$TEST_BUNDLE_PATH" "$TMP_DIR"
  chmod -R 777 "${TMP_DIR}/$(basename "$TEST_BUNDLE_PATH")"
  runner_flags+=("--test_bundle_path=${TEST_BUNDLE_PATH}")
else
  TEST_BUNDLE_NAME=$(basename_without_extension "${TEST_BUNDLE_PATH}")
  TEST_BUNDLE_TMP_DIR="${TMP_DIR}/${TEST_BUNDLE_NAME}"
  unzip -qq -d "${TEST_BUNDLE_TMP_DIR}" "${TEST_BUNDLE_PATH}"
  runner_flags+=("--test_bundle_path=${TEST_BUNDLE_TMP_DIR}/${TEST_BUNDLE_NAME}.xctest")
fi


TEST_HOST_PATH="%(test_host_path)s"

if [[ -n "$TEST_HOST_PATH" ]]; then
  if [[ "$TEST_HOST_PATH" == *.app ]]; then
    # Need to copy the bundle outside of the Bazel execroot since the test
    # runner needs to make some modifications to its contents.
    # TODO(kaipi): Improve xctestrunner to account for Bazel permissions.
    cp -RL "$TEST_HOST_PATH" "$TMP_DIR"
    chmod -R 777 "${TMP_DIR}/$(basename "$TEST_HOST_PATH")"
    runner_flags+=("--app_under_test_path=${TMP_DIR}/$(basename "$TEST_HOST_PATH")")
  else
    TEST_HOST_NAME=$(basename_without_extension "${TEST_HOST_PATH}")
    TEST_HOST_TMP_DIR="${TMP_DIR}/${TEST_HOST_NAME}"
    unzip -qq -d "${TEST_HOST_TMP_DIR}" "${TEST_HOST_PATH}"
    runner_flags+=("--app_under_test_path=${TEST_HOST_TMP_DIR}/Payload/${TEST_HOST_NAME}.app")
  fi
fi

if [[ -n "${TEST_UNDECLARED_OUTPUTS_DIR}" ]]; then
  OUTPUT_DIR="${TEST_UNDECLARED_OUTPUTS_DIR}"
  runner_flags+=("--output_dir=$OUTPUT_DIR")
  mkdir -p "$OUTPUT_DIR"
fi

TEST_TYPE="%(test_type)s"
if [[ -n "${TEST_TYPE}" ]]; then
  TEST_TYPE=$(tr '[:upper:]' '[:lower:]' <<< ${TEST_TYPE})
  runner_flags+=("--test_type=${TEST_TYPE}")
fi

# Constructs the json string to configure the test env and tests to run.
# It will be written into a temp json file which is passed to the test runner
# flags --launch_options_json_path.
LAUNCH_OPTIONS_JSON_STR=""

TEST_ENV="%(test_env)s"
if [[ -n "$TEST_ENV" ]]; then
  TEST_ENV="$TEST_ENV,TEST_SRCDIR=$TEST_SRCDIR"
else
  TEST_ENV="TEST_SRCDIR=$TEST_SRCDIR"
fi

readonly profraw="$TMP_DIR/coverage.profraw"
if [[ "${COVERAGE:-}" -eq 1 ]]; then
  readonly profile_env="LLVM_PROFILE_FILE=$profraw"
  TEST_ENV="$TEST_ENV,$profile_env"
fi

# Converts the test env string to json format and addes it into launch
# options string.
TEST_ENV=$(echo "$TEST_ENV" | awk -F ',' '{for (i=1; i <=NF; i++) { d = index($i, "="); print substr($i, 1, d-1) "\":\"" substr($i, d+1); }}')
TEST_ENV=${TEST_ENV//$'\n'/\",\"}
TEST_ENV="{\"${TEST_ENV}\"}"
LAUNCH_OPTIONS_JSON_STR="\"env_vars\":${TEST_ENV}"

if [[ -n "${command_line_args}" ]]; then
  if [[ -n "${LAUNCH_OPTIONS_JSON_STR}" ]]; then
    LAUNCH_OPTIONS_JSON_STR+=","
  fi
  command_line_args="$(IFS=","; echo "${command_line_args[*]}")"
  command_line_args="${command_line_args//,/\",\"}"
  LAUNCH_OPTIONS_JSON_STR+="\"args\":[\"$command_line_args\"]"
fi

# Use the TESTBRIDGE_TEST_ONLY environment variable set by Bazel's --test_filter
# flag to set tests_to_run value in ios_test_runner's launch_options.
# Any test prefixed with '-' will be passed to "skip_tests". Otherwise the tests
# is passed to "tests_to_run"
if [[ -n "$TESTBRIDGE_TEST_ONLY" ]]; then
  if [[ -n "${LAUNCH_OPTIONS_JSON_STR}" ]]; then
    LAUNCH_OPTIONS_JSON_STR+=","
  fi

  IFS=","
  ALL_TESTS=("$TESTBRIDGE_TEST_ONLY")
  for TEST in $ALL_TESTS; do
    if [[ $TEST == -* ]]; then
      if [[ -n "$SKIP_TESTS" ]]; then
        SKIP_TESTS+=",${TEST:1}"
      else
        SKIP_TESTS="${TEST:1}"
      fi
    else
      if [[ -n "$ONLY_TESTS" ]]; then
          ONLY_TESTS+=",$TEST"
      else
          ONLY_TESTS="$TEST"
      fi
    fi
  done

  if [[ -n "$SKIP_TESTS" ]]; then
    SKIP_TESTS="${SKIP_TESTS//,/\",\"}"
    LAUNCH_OPTIONS_JSON_STR+="\"skip_tests\":[\"$SKIP_TESTS\"]"

    if [[ -n "$ONLY_TESTS" ]]; then
      LAUNCH_OPTIONS_JSON_STR+=","
    fi
  fi

  if [[ -n "$ONLY_TESTS" ]]; then
    ONLY_TESTS="${ONLY_TESTS//,/\",\"}"
    LAUNCH_OPTIONS_JSON_STR+="\"tests_to_run\":[\"$ONLY_TESTS\"]"
  fi
fi

if [[ -n "${LAUNCH_OPTIONS_JSON_STR}" ]]; then
  LAUNCH_OPTIONS_JSON_STR="{${LAUNCH_OPTIONS_JSON_STR}}"
  LAUNCH_OPTIONS_JSON_PATH="${TMP_DIR}/launch_options.json"
  echo "${LAUNCH_OPTIONS_JSON_STR}" > "${LAUNCH_OPTIONS_JSON_PATH}"
  runner_flags+=("--launch_options_json_path=${LAUNCH_OPTIONS_JSON_PATH}")
fi

target_flags=()
if [[ -n "${REUSE_GLOBAL_SIMULATOR:-}" ]]; then
  if [[ -n "$device_id" ]]; then
    echo "error: both '\$REUSE_GLOBAL_SIMULATOR' and a custom simulator id cannot be set" >&2
    exit 1
  fi

  if [[ -z "%(os_version)s" ]]; then
    echo "error: to create a re-useable simulator the OS version must always be set on the test runner or with '--ios_simulator_version'" >&2
    exit 1
  fi

  if [[ -z "%(device_type)s" ]]; then
    echo "error: to create a re-useable simulator the device type must always be set on the test runner or with '--ios_simulator_device'" >&2
    exit 1
  fi

  id="$("./%(simulator_creator)s" "%(os_version)s" "%(device_type)s")"
  target_flags=(
    "test"
    "--platform=ios_simulator"
    "--id=$id"
  )
elif [[ -n "$device_id" ]]; then
  target_flags=(
    "test"
    "--platform=$platform"
    "--id=$device_id"
  )
else
  target_flags=(
    "simulator_test"
    "--device_type=%(device_type)s"
    "--os_version=%(os_version)s"
  )
fi

cmd=("%(testrunner_binary)s"
  "${runner_flags[@]}"
  "${target_flags[@]}"
  "${custom_xctestrunner_args[@]}")
"${cmd[@]}" 2>&1

if [[ "${COVERAGE:-}" -ne 1 ]]; then
  # Normal tests run without coverage
  exit 0
fi

readonly profdata="$TMP_DIR/coverage.profdata"
xcrun llvm-profdata merge "$profraw" --output "$profdata"

lcov_args=(
  -instr-profile "$profdata"
  -ignore-filename-regex='.*external/.+'
  -path-equivalence="$ROOT",.
)
has_binary=false
IFS=";"
arch=$(uname -m)
for binary in $TEST_BINARIES_FOR_LLVM_COV; do
  if [[ "$has_binary" == false ]]; then
    lcov_args+=("${binary}")
    has_binary=true
    if ! file "$binary" | grep -q "$arch"; then
      arch=x86_64
    fi
  else
    lcov_args+=(-object "${binary}")
  fi

  lcov_args+=("-arch=$arch")
done

readonly error_file="$TMP_DIR/llvm-cov-error.txt"
llvm_cov_status=0
xcrun llvm-cov \
  export \
  -format lcov \
  "${lcov_args[@]}" \
  @"$COVERAGE_MANIFEST" \
  > "$COVERAGE_OUTPUT_FILE" \
  2> "$error_file" \
  || llvm_cov_status=$?

# Error ourselves if lcov outputs warnings, such as if we misconfigure
# something and the file path of one of the covered files doesn't exist
if [[ -s "$error_file" || "$llvm_cov_status" -ne 0 ]]; then
  echo "error: while exporting coverage report" >&2
  cat "$error_file" >&2
  exit 1
fi

if [[ -n "${COVERAGE_PRODUCE_JSON:-}" ]]; then
  llvm_cov_json_export_status=0
  xcrun llvm-cov \
    export \
    -format text \
    "${lcov_args[@]}" \
    @"$COVERAGE_MANIFEST" \
    > "$TEST_UNDECLARED_OUTPUTS_DIR/coverage.json"
    2> "$error_file" \
    || llvm_cov_json_export_status=$?
  if [[ -s "$error_file" || "$llvm_cov_json_export_status" -ne 0 ]]; then
    echo "error: while exporting json coverage report" >&2
    cat "$error_file" >&2
    exit 1
  fi
fi

if [[ -n "${COVERAGE_PRODUCE_HTML:-}" ]]; then
  llvm_cov_html_export_status=0

  # TODO: remove it, for debugging purpose only
  echo "${lcov_args[*]}"

  echo ">>> root:"$ROOT
  echo ">>> pwd"
  pwd
  echo ">>> list"
  ls -al $ROOT
  echo ">>>"

  # TODO: Improve to use `@"$COVERAGE_MANIFEST"` to filter out unneccessary file on staticlib
  # reference: https://github.com/bazelbuild/rules_apple/pull/1490#discussion_r900379232
  xcrun llvm-cov \
    show \
    -format html \
    -use-color \
    -output-dir="$TEST_UNDECLARED_OUTPUTS_DIR/html" \
    "${lcov_args[@]}" \
    2> "$error_file" \
    || llvm_cov_html_export_status=$?
  if [[ -s "$error_file" || "$llvm_cov_html_export_status" -ne 0 ]]; then
    echo "error: while exporting html coverage report" >&2
    cat "$error_file" >&2
    exit 1
  fi
fi
