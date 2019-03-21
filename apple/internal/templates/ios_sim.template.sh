#!/bin/bash

# Copyright 2015 The Bazel Authors. All rights reserved.
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

# This script is to:
# 1. create a new simulator by running "xcrun simctl create ..."
# 2. launch the created simulator by passing the ID to the simulator app,
# like: "/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app/Contents/MacOS/Simulator" -CurrentDeviceUDID "B647C213-110F-4A6B-827D-BD25313C2D1F"
# 3. install the target app on the created simulator by running
# "xcrun simctl install ..."
# 4. launch the target app on the created simulator by running
# "xcrun simctl launch <device> <app identifier> <args>", and get its PID. We
# pass in the env vars to the app by exporting the env vars adding the prefix
# "SIMCTL_CHILD_" in the calling environment.
# 5. check the app's PID periodically, exit the script when the app is not
# running.
# 6. when exit, will shutdown and delete the new created simulator.
#
# Note: the command "xcrun simctl launch ..." cannot return the app's output,
# so we pass in the StdRedirect.dylib as an $DYLD_INSERT_LIBRARIES, which
# could redirect the output to $GSTDERR and $GSTDOUT. Then we "tail -f" the
# file with the redirected content to show it on the console.

set -eu

if [[ "$(uname)" != Darwin ]]; then
  echo "Cannot run iOS targets on a non-mac machine."
  exit 1
fi

function MissingRuntimeError() {
  # print a simple error message about runtimes.
  printf "Currently installed runtimes:\n%s\n\nYou can install other runtimes via Xcode > Preferences > Components\n" \
      "$(xcrun simctl list runtimes)"
}

# Note: the sim_device might contain spaces, but they are already provided in
# quoted form in the template variables, so we should not quote them again here.
trap "MissingRuntimeError" ERR
sdk_version="%sdk_version%"
TEST_DEVICE_ID=$(xcrun simctl create TestDevice %sim_device% com.apple.CoreSimulator.SimRuntime.iOS-${sdk_version//./-})
trap - ERR

function KillAllDevices() {
  # Kill all running simulators.under Xcode 7+. The error message "No matching
  # processes belonging to you were found" is expected when there's no running
  # simulator.
  pkill Simulator 2> /dev/null || true
}

# Kill the tail process (we redirect the app's output to a file and use tail to
# stream the file) when the app is not running.
# Default timeout is 600 secs. User could change it by running
# "export TIME_OUT=<new_timeout_in_secs>" before invoking "bazel run" command.
# $1: the PID of the app process
# $2: the PID of the tail process
function exit_when_app_not_running() {
  local time_out=${TIME_OUT:-600}
  local end_time=$(($(date +%s)+${time_out}))
  while kill -0 "$1" &> /dev/null; do
    if [[ $(date +%s) -gt $end_time ]]; then
      break
    fi
    sleep 1
  done
  kill -9 "$2" &> /dev/null
}

# Wait until the given simualtor is booted.
# $1: the simulator ID to boot
function wait_for_sim_to_boot() {
  i=0
  while [ "${i}" -lt 60 ]; do
    # The expected output of "xcrun simctl list" is like:
    # -- iOS 8.4 --
    # iPhone 5s (E946FA1C-26AB-465C-A7AC-24750D520BEA) (Shutdown)
    # TestDevice (8491C4BC-B18E-4E2D-934A-54FA76365E48) (Booted)
    # So if there's any booted simulator, $booted_device will not be empty.
    local booted_device=$(xcrun simctl list devices | grep "$1" | grep "Booted" || true)
    if [ -n "${booted_device}" ]; then
      # Simulator is booted.
      return
    fi
    sleep 1
    i=$(($i+1))
  done
  echo "Failed to launch the simulator. The existing simulators are:"
  xcrun simctl list
  exit 1
}

# Clean up the given simulator.
# $1: the simulator ID
function CleanupSimulator() {
  # Device may not have started up, so no guarantee shutdown is going to be good.
  xcrun simctl shutdown "$1" 2> /dev/null || true
  xcrun simctl delete "$1"
}

readonly STD_REDIRECT_DYLIB="$PWD/%std_redirect_dylib_path%"

readonly TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/bazel_temp.XXXXXX")

trap 'rm -rf "${TEMP_DIR}"; CleanupSimulator ${TEST_DEVICE_ID}' ERR EXIT

KillAllDevices

# Get the developer path, like: /Applications/Xcode.app/Contents/Developer
readonly DEVELOPER_PATH=$(xcode-select -p)

# Launch the simulator.
"${DEVELOPER_PATH}/Applications/Simulator.app/Contents/MacOS/Simulator" -CurrentDeviceUDID "${TEST_DEVICE_ID}" &
wait_for_sim_to_boot "${TEST_DEVICE_ID}"

# Pass environment variables prefixed with "IOS_" to the simulator, replace the
# prefix with "SIMCTL_CHILD_". bazel adds "IOS_" to the env vars which
# will be passed to the app as prefix to differentiate from other env vars. We
# replace the prefix "IOS_" with "SIMCTL_CHILD_" here, because "simctl" only
# pass the env vars prefixed with "SIMCTL_CHILD_" to the app.
libs_to_insert="${STD_REDIRECT_DYLIB}"
while read -r envvar; do
  if [[ "${envvar}" == IOS_* ]]; then
    if [[ "${envvar}" == IOS_DYLD_INSERT_LIBRARIES=* ]]; then
      libs_to_insert=SIMCTL_CHILD_"${envvar#IOS_}":"${libs_to_insert}"
    else
      export SIMCTL_CHILD_"${envvar#IOS_}"
    fi
  fi
done < <(env)
export SIMCTL_CHILD_DYLD_INSERT_LIBRARIES="${libs_to_insert}"

readonly RUN_LOG="${TEMP_DIR}/run.log"
touch "${RUN_LOG}"
export SIMCTL_CHILD_GSTDERR="${RUN_LOG}"
export SIMCTL_CHILD_GSTDOUT="${RUN_LOG}"

readonly APP_PARENT_DIR="${TEMP_DIR}/extracted_app"
mkdir -p "$APP_PARENT_DIR"

if [[ -d '%ipa_file%' ]]; then
  # App bundles are directories with the .app extension
  # simctl won't install symlinks so rsync to resolve them
  rsync -rL '%ipa_file%' "${APP_PARENT_DIR}"
  readonly APP_DIR="${APP_PARENT_DIR}/$(basename '%ipa_file%')"
else
  # The app bundle is contained within an compressed archive (zip)
  # Unpack the archive
  # TODO(kaipi): Remove this branch once tree artifacts are the default and only
  # option.
  unzip -qq '%ipa_file%' -d "${APP_PARENT_DIR}"
  # The zip file contains a Payload directory that is the parent of the .app directory.
  readonly APP_DIR="${APP_PARENT_DIR}/Payload/%app_name%.app"
fi

xcrun simctl install "$TEST_DEVICE_ID" "${APP_DIR}"

# Get the bundle ID of the app.
readonly BUNDLE_INFO_PLIST="${APP_DIR}/Info.plist"
readonly BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${BUNDLE_INFO_PLIST}")

USER_NAME=${USER:-"$(logname)"}
readonly SYSTEM_LOG="/Users/${USER_NAME}/Library/Logs/CoreSimulator/${TEST_DEVICE_ID}/system.log"
rm -f "${SYSTEM_LOG}"

# Launch the app. The expected output is:
# <bundle name, e.g. example.PrenotCalculatorBinary>: <pid of the app process>
IOS_PID=$(xcrun simctl launch "${TEST_DEVICE_ID}" "${BUNDLE_ID}" "$@")
# The awk command will abstract the pid of the app process.
IOS_PID=$(echo "${IOS_PID}" | awk '{ print $2 }')
echo "Start the app ${BUNDLE_ID} on ${TEST_DEVICE_ID}."

# Tail the file with the redirected outputs of the app.
tail -f "${RUN_LOG}" &
exit_when_app_not_running "${IOS_PID}" "$!"

# Wait for a while for the system.log to be updated.
sleep 5

if [ ! -f "${SYSTEM_LOG}" ];then
  output=$(cat "${RUN_LOG}")
  # If there's no system.log or output, might be a crash.
  if [ -z "${output}" ];then
    echo "no output or system.log"
    exit 1
  else
    exit 0
  fi
fi

# Check the system.log to see if there was an abnormal exit.
readonly ABNORMAL_EXIT_MSG=$(cat "${SYSTEM_LOG}" | \
    grep "com.apple.CoreSimulator.SimDevice.${TEST_DEVICE_ID}.launchd_sim" | \
    grep "Service exited with abnormal code")
if [ -n "${ABNORMAL_EXIT_MSG}" ]; then
  echo "The app exited abnormally: ${ABNORMAL_EXIT_MSG}"
  exit 1
fi
