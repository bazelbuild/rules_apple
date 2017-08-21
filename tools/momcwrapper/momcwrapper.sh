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

# momcwrapper runs momc, working around issues with relative paths. This script
# only runs on Darwin and you must have Xcode installed.
#
# $1 OUTPUT - The path to the desired output file (.mom) or directory (.momd),
#             depending on whether or not the input is a versioned data model.

set -eu

source "$0.runfiles/build_bazel_rules_apple/tools/wrapper_common/wrapper_common.sh"
setup_common_tools

OUTPUT="$1"
mkdir -p "$(dirname "$OUTPUT")"
shift 1

xcrunwrapper momc "$@" "$(realpath "$OUTPUT")"
