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
  OUTPUT_DIR="${PWD}/${TEST_UNDECLARED_OUTPUTS_DIR}"
  runner_flags+=("--output_dir=$OUTPUT_DIR")
  mkdir -p "$OUTPUT_DIR"
fi

# Constructs the json string to configure the test env and tests to run.
# It will be written into a temp json file which is passed to the test runner
# flags --launch_options_json_path.
LAUNCH_OPTIONS_JSON_STR=""

TEST_ENV="%(test_env)s"
if [[ -n "${TEST_ENV}" ]]; then
  # Converts the test env string to json format and addes it into launch
  # options string.
  TEST_ENV=${TEST_ENV//=/\":\"}
  TEST_ENV=${TEST_ENV//,/\",\"}
  TEST_ENV="{\"${TEST_ENV}\"}"
  LAUNCH_OPTIONS_JSON_STR="\"env_vars\":${TEST_ENV}"
fi

# Use the TESTBRIDGE_TEST_ONLY environment variable set by Bazel's --test_filter
# flag to set tests_to_run value in ios_test_runner's launch_options.
if [[ -n "$TESTBRIDGE_TEST_ONLY" ]]; then
  if [[ -n "${LAUNCH_OPTIONS_JSON_STR}" ]]; then
    LAUNCH_OPTIONS_JSON_STR+=","
  fi
  LAUNCH_OPTIONS_JSON_STR+="\"tests_to_run\":[\"$TESTBRIDGE_TEST_ONLY\"]"
fi

if [[ -n "${LAUNCH_OPTIONS_JSON_STR}" ]]; then
  LAUNCH_OPTIONS_JSON_STR="{${LAUNCH_OPTIONS_JSON_STR}}"
  LAUNCH_OPTIONS_JSON_PATH="${TMP_DIR}/launch_options.json"
  echo "${LAUNCH_OPTIONS_JSON_STR}" > "${LAUNCH_OPTIONS_JSON_PATH}"
  runner_flags+=("--launch_options_json_path=${LAUNCH_OPTIONS_JSON_PATH}")
fi

cmd=("%(testrunner_binary)s"
  "${runner_flags[@]}"
  simulator_test
  "--device_type=%(device_type)s"
  "--os_version=%(os_version)s"
  "$@")
"${cmd[@]}" 2>&1
status=$?
exit ${status}
