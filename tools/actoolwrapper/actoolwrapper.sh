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

# actoolwrapper runs actool, working around issues with relative paths and
# managing creation of the output directory. This script only runs on Darwin and
# you must have Xcode installed.
#
# $1 OUTDIR - The directory where the output will be placed. This script will
#             create it.

set -eu

source "$0.runfiles/build_bazel_rules_apple/tools/wrapper_common/wrapper_common.sh"
setup_common_tools

if [[ -n "${SHOULD_RESET_SIMULATORS:-}" ]]; then
  reset_simulator_service
fi

OUTDIR="$1"
mkdir -p "$OUTDIR"
shift 1

# actool needs to have absolute paths sent to it, so we call realpaths on
# on all arguments seeing if we can expand them.
# actool and ibtool appear to depend on the same code base.
# Radar 21045660 ibtool has difficulty dealing with relative paths.

TOOLARGS=()
LASTARG=""
for i in "$@"; do
  # The argument for --output-partial-info-plist doesn't actually exist at the
  # time of flag parsing, so we create it so that we can call realpath on it
  # to make the path absolute.
  if [[ "$LASTARG" = "--output-partial-info-plist" ]]; then
    touch "$i"
  fi
  if [[ -e "$i" ]]; then
    ARG="$(realpath "$i")"
    TOOLARGS+=("$ARG")
  else
    TOOLARGS+=("$i")
  fi
  LASTARG="$i"
done

# If we are running into problems figuring out actool issues, there are a couple
# of env variables that may help. Both of the following must be set to work.
#   IBToolDebugLogFile=<OUTPUT FILE PATH>
#   IBToolDebugLogLevel=4
# you may also see if
#   IBToolNeverDeque=1
# helps.
# Yes IBTOOL appears to be correct here due to actool and ibtool being based
# on the same codebase.
xcrunwrapper actool --errors --warnings --notices \
    --compress-pngs --output-format human-readable-text \
    --compile "$(realpath "$OUTDIR")" "${TOOLARGS[@]}"
