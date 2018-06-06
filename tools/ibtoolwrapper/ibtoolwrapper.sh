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

# ibtoolwrapper runs ibtool, working around relative path issues and handling
# the differences between file outputs and directory outputs appropriately. This
# script only runs on Darwin and you must have Xcode installed.
#
# $1 ACTION - The action to execute: --compile, --link, or
#             --compilation-directory. (The last one is not technically an
#             action, but we treat it as such to unify the output path
#             handling.)
# $2 OUTPUT - The path to the file or directory where the output will be written
#             (depending on the action specified).

set -eu

source "$0.runfiles/build_bazel_rules_apple/tools/wrapper_common/wrapper_common.sh"
setup_common_tools

ACTION="$1"
OUTPUT="$2"
shift 2

if [[ "$ACTION" == "--compilation-directory" || "$ACTION" == "--link" ]]; then
  # When compiling storyboards, $OUTPUT is the directory where the .storyboardc
  # directory will be written. When linking storyboards, $OUTPUT is the
  # directory where all of the .storyboardc directories will be copied. In
  # either case, we ensure that that directory is created.
  mkdir -p "$OUTPUT"
  FULLPATH="$(realpath "$OUTPUT")"
else
  # When compiling XIBs, we know the name that we pass to the --compile option
  # but it could be mangled by ibtool, depending on the minimum OS version (for
  # example, iOS < 8.0 will produce separate FOO~iphone.nib/ and FOO~ipad.nib/
  # folders given the flag --compile FOO.nib. So all we do is ensure that the
  # _parent_ directory is created and let ibtool create the files in it.
  mkdir -p "$(dirname "$OUTPUT")"

  touch "$OUTPUT"
  FULLPATH="$(realpath "$OUTPUT")"
  rm -f "$OUTPUT"
fi

# IBTool needs to have absolute paths sent to it, so we call realpaths on
# on all arguments seeing if we can expand them.
# Radar 21045660 ibtool has difficulty dealing with relative paths.
TOOLARGS=()
for i in "$@"; do
  if [[ -e "$i" ]]; then
    ARG="$(realpath "$i")"
    TOOLARGS+=("$ARG")
  else
    TOOLARGS+=("$i")
  fi
done

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
