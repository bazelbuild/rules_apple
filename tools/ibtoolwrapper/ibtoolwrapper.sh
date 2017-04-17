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
# ibtoolwrapper runs ibtool and zips up the output.
# This script only runs on darwin and you must have Xcode installed.
#
# $1 OUTZIP - the path to place the output zip file.
# $2 ARCHIVEROOT - the path in the zip to place the output, or an empty
#                  string for the root of the zip. e.g. 'Payload/foo.app'. If
#                  this tool outputs a single file, ARCHIVEROOT is the name of
#                  the only file in the zip file.

set -eu

source "$0.runfiles/build_bazel_rules_apple/tools/wrapper_common/wrapper_common.sh"
setup_common_tools

if [[ -n "${GOOGLE3:-}" ]]; then  # OSS: SHOULD_RESET_SIMULATORS
  reset_simulator_service
fi

OUTZIP="$(realpath "$1")"
ARCHIVEROOT="$2"
shift 2

TEMPDIR="$(create_temp_dir ibtoolZippingOutput.XXXXXX)"

# Create the directory used to expand compiled storyboards for linking if that
# options is present on the command line.
for i in "$@"; do
  if [[ "$i" == "--link" ]]; then
    LINKDIR="$(create_temp_dir ibtoolLinkingRoot.XXXXXX)"
  fi
done

FULLPATH="$TEMPDIR/$ARCHIVEROOT"
PARENTDIR="$(dirname "$FULLPATH")"
mkdir -p "$PARENTDIR"
FULLPATH="$(realpath "$FULLPATH")"

# IBTool needs to have absolute paths sent to it, so we call realpaths on
# on all arguments seeing if we can expand them.
# Radar 21045660 ibtool has difficulty dealing with relative paths.
TOOLARGS=()
# By default, have ibtool compile storyboards (to stay compatible with the
# native rules). If the command line includes "--link", we use it instead.
ACTION=--compile
for i in "$@"; do
  if [[ -e "$i" ]]; then
    if [[ "$i" == *.zip ]]; then
      unzip -qq "$i" -d "$LINKDIR"
    else
      ARG="$(realpath "$i")"
      TOOLARGS+=("$ARG")
    fi
  else
    if [[ "$i" == "--link" ]]; then
      ACTION="$i"
    else
      TOOLARGS+=("$i")
    fi
  fi
done

# Collect all the .storyboardc directories that were extracted earlier for
# the linking action.
if [[ "$ACTION" == "--link" ]]; then
  # We still have to use "$REALPATH" here instead of just "realpath" because
  # find -exec expects a command, not a function. We also intentionally do not
  # quote this command invocation so that the arguments are passed with spaces
  # between them instead of newlines.
  TOOLARGS+=($(find "$LINKDIR" -name "*.storyboardc" -exec "$REALPATH" {} \;))
fi

# If we are running into problems figuring out ibtool issues, there are a couple
# of env variables that may help. Both of the following must be set to work.
#   IBToolDebugLogFile=<OUTPUT FILE PATH>
#   IBToolDebugLogLevel=4
# you may also see if
#   IBToolNeverDeque=1
# helps.
xcrunwrapper ibtool --errors --warnings --notices \
    --auto-activate-custom-fonts --output-format human-readable-text \
    "$ACTION" "$FULLPATH" "${TOOLARGS[@]}"

finalize_output_as_zip "$TEMPDIR" "$OUTZIP"
