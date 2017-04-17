#!/bin/bash
#
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
#
# This script contains functionality common to many of the shell scripts that
# wrap Xcode tools.


# Usage: create_temp_dir <pattern>
#
# Creates a temporary directory with the given name pattern. The directory is
# not deleted if the script exits abnormally; this allows you to examine its
# contents if necessary.
function create_temp_dir() {
  local -r pattern="$1"
  local -r tempdir="$(mktemp -d "${TMPDIR:-/tmp}/$pattern")"
  echo "$tempdir"
}

# Usage: finalize_output_as_zip <dir_to_zip> <out_zip>
#
# Recursively resets the timestamps of the files in `dir_to_zip` (for
# comparison purposes) and then zips its contents to `out_zip`, without using
# compression (for speed). Finally, it deletes the directory.
function finalize_output_as_zip() {
  local -r dir_to_zip="$1"
  local -r out_zip="$2"

  # Need to push/pop tempdir so it isn't the current working directory
  # when we remove it via the EXIT trap.
  pushd "$dir_to_zip" > /dev/null

  # Reset all dates to Zip Epoch so that two identical zips created at
  # different times appear the exact same for comparison purposes.
  find . -exec touch -h -t 198001010000 {} \+

  # Added include "*" to fix case where we may want an empty zip file because
  # there is no data.
  zip --compression-method store --symlinks --recurse-paths --quiet \
    "$out_zip" . --include "*"

  popd > /dev/null
  rm -rf "$dir_to_zip"
}

# Usage: kill_process_mercilessly <regex>
#
# Tries to kill a process whose name ends with a string matching the given
# regex and does so repeatedly if it shows any signs of restarting itself.
function kill_process_mercilessly() {
  local -r regex="$1"
  local -r max_wait_secs=10

  while : ; do
    processname=$(ps -xc -o command | grep -E "${regex}$" | head -1)
    if [[ -z "$processname" ]]; then
      break
    fi
    killed=0
    killtime="$(date +%s)"
    waittime="$killtime"
    set +e
    until [[ "$killed" -ne 0 || \
        "$(("$waittime" - "$killtime"))" -ge "$max_wait_secs" ]]; do
      /usr/bin/killall -9 "$processname" >/dev/null 2>&1
      killed="$?"
      waittime="$(date +%s)"
    done
    set -e
  done
}

# Usage: realpath <arguments...>
#
# Executes "realpath", passing it the given arguments.
function realpath() {
  if [[ -z "${REALPATH:-}" ]]; then
    echo "REALPATH not set; did you forget to call setup_common_tools?"
    exit 1
  fi
  "$REALPATH" "$@"
}

# Usage: reset_simulator_service
#
# If you have a CI service that switches between multiple Xcode versions,
# sometimes simulators used by the actool/ibtool daemon associated with the
# previous version will not properly shut down after a switch. If the variable
# SHOULD_RESET_SIMULATORS is set in your environment, then this function is
# called at the beginning of actoolwrapper and ibtoolwrapper to force the
# simulator process to be killed.
function reset_simulator_service() {
  kill_process_mercilessly "com\.apple\.CoreSimulatorService"
}

# Usage: setup_common_tools
#
# Configures environment variables used to determine the paths to common tools.
function setup_common_tools() {
  # The variables in this function are explicitly exported.
  REALPATH="$0.runfiles/build_bazel_rules_apple/tools/realpath/realpath"
  XCRUNWRAPPER="$0.runfiles/bazel_tools/tools/objc/xcrunwrapper.sh"
}

# Usage: xcrunwrapper <arguments...>
#
# Executes "xcrunwrapper", passing it the given arguments.
function xcrunwrapper() {
  if [[ -z "${XCRUNWRAPPER:-}" ]]; then
    echo "XCRUNWRAPPER not set; did you forget to call setup_common_tools?"
    exit 1
  fi
  "$XCRUNWRAPPER" "$@"
}
