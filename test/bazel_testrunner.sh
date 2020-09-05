#!/bin/bash

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

# Test runner that sets up the environment for Apple shell integration tests.
#
# Use the `apple_shell_test` rule in //test:test_rules.bzl to spawn this.
#
# Usage:
#   bazel_testrunner.sh <test_script>
#
# test_script: The name of the test script to execute inside the test
#     directory.

test_script="$1"; shift

# Use the image's default Xcode version when running tests to avoid flakes
# because of multiple Xcodes running at the same time.
export XCODE_VERSION_FOR_TESTS="$(xcodebuild -version | sed -nE 's/Xcode (.+)/\1/p')"

function print_message_and_exit() {
  echo "$1" >&2; exit 1;
}

# Location of the external dependencies linked to the test through @workspace
# links.
EXTERNAL_DIR="$(pwd)/external"

CURRENT_SCRIPT="${BASH_SOURCE[0]}"
# Go to the directory where the script is running
cd "$(dirname ${CURRENT_SCRIPT})" \
  || print_message_and_exit "Unable to access "$(dirname ${CURRENT_SCRIPT})""

DIR=$(pwd)
# Load the unit test framework
source "$DIR/unittest.bash" || print_message_and_exit "unittest.bash not found!"

# Load the test environment
function create_new_workspace() {
  new_workspace_dir="${1:-$(mktemp -d ${TEST_TMPDIR}/workspace.XXXXXXXX)}"
  rm -fr "${new_workspace_dir}"
  mkdir -p "${new_workspace_dir}"
  cd "${new_workspace_dir}"

  # Make a modifiable copy of external, so that we can mock out missing
  # test resources. This should only be needed for mocking the xctestrunner
  # BUILD file below; if we can workaround this, we don't need to make this
  # copy and we should reference it from the original location.
  cp -rf "$EXTERNAL_DIR" ../external

  touch WORKSPACE
  cat > WORKSPACE <<EOF
workspace(name = 'build_bazel_rules_apple_integration_tests')

# We can't use local_repository as the dependencies won't
# copy some of the build files or WORKSPACE. new_local_repository
# will create a new WORKSPACE file and we just need to pass the
# contents for a top level BUILD file, which can be empty.
new_local_repository(
    name = "bazel_skylib",
    build_file_content = '',
    path = '$PWD/../external/bazel_skylib',
)

new_local_repository(
    name = "subpar",
    build_file_content = '',
    path = '$PWD/../external/subpar',
)

local_repository(
    name = 'build_bazel_rules_apple',
    path = '$(rlocation build_bazel_rules_apple)',
)

local_repository(
    name = 'build_bazel_rules_swift',
    path = '$(rlocation build_bazel_rules_swift)',
)

local_repository(
    name = 'build_bazel_apple_support',
    path = '$(rlocation build_bazel_apple_support)',
)

local_repository(
    name = 'xctestrunner',
    path = '$(rlocation xctestrunner)',
)

# We load rules_swift dependencies into the WORKSPACE. This is safe to do
# _for now_ because Swift currently depends on:
#
# * skylib - which is already loaded, so it won't be loaded again.
# * swift_protobuf - which is not used in the integration tests, so it won't be
#   loaded.
# * protobuf - which also is not used in the integration tests.
# * swift_toolchain - which is generated locally, so nothing to download.
#
# If these assumptions change over time, we'll need to reassess this way of
# loading rules_swift dependencies.

load(
    "@build_bazel_rules_swift//swift:repositories.bzl",
    "swift_rules_dependencies",
)

swift_rules_dependencies()
EOF
}

# Set-up a clean default workspace.
function setup_clean_workspace() {
  export WORKSPACE_DIR="${TEST_TMPDIR}/workspace"
  echo "setting up client in ${WORKSPACE_DIR}" > "$TEST_log"
  rm -fr "${WORKSPACE_DIR}"
  create_new_workspace "${WORKSPACE_DIR}"
  [ "${new_workspace_dir}" = "${WORKSPACE_DIR}" ] || \
    { echo "Failed to create workspace" >&2; exit 1; }
  export BAZEL_INSTALL_BASE=$(bazel info install_base)
  export BAZEL_GENFILES=$(bazel info bazel-genfiles "${EXTRA_BUILD_OPTIONS[@]:-}")
  export BAZEL_BIN=$(bazel info bazel-bin "${EXTRA_BUILD_OPTIONS[@]:-}")
}

# Any remaining arguments are passed to every `bazel build` invocation in the
# subsequent tests (see `do_build` in apple_shell_testutils.sh).
export EXTRA_BUILD_OPTIONS=( "$@" ); shift $#

# Disable Swift workers until they work with Bazel@HEAD.
# TODO(b/133166891): Remove this.
EXTRA_BUILD_OPTIONS+=( "--strategy=SwiftCompile=local" )

echo "Applying extra options to each build: ${EXTRA_BUILD_OPTIONS[*]:-}" > "$TEST_log"

# Try to find the desired version of Xcode installed on the system. If it's not
# present, fallback to the most recent version currently installed and warn the
# user that results might be affected by this. (This makes it easier to support
# local test runs without having to change the version above from the CI
# default.)
readonly XCODE_QUERY=$(bazel query \
    "attr(aliases, $XCODE_VERSION_FOR_TESTS, " \
    "labels(versions, @local_config_xcode//:host_xcodes))" | \
    head -n 1)
if [[ -z "$XCODE_QUERY" ]]; then
  readonly OLD_XCODE_VERSION="$XCODE_VERSION_FOR_TESTS"
  XCODE_VERSION_FOR_TESTS=$(bazel query \
      "labels(versions, @local_config_xcode//:host_xcodes)" | \
      head -n 1 | \
      sed s#@local_config_xcode//:version## | \
      sed s#_#.#g)

  printf "WARN: The desired version of Xcode ($OLD_XCODE_VERSION) was not " >> "$TEST_log"
  printf "installed; using the highest version currently installed instead " >> "$TEST_log"
  printf "($XCODE_VERSION_FOR_TESTS). Note that this may produce unpredictable " >> "$TEST_log"
  printf "results in tests that depend on the behavior of a specific version " >> "$TEST_log"
  printf "of Xcode.\n" >> "$TEST_log"
fi

setup_clean_workspace

source "$(rlocation build_bazel_rules_apple/test/apple_shell_testutils.sh)"
source "$(rlocation build_bazel_rules_apple/test/${test_script})"
