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
# mapcwrapper runs mapc.
# This script only runs on darwin and you must have Xcode installed.
#
# $1 SOURCE_PATH - the path to the .xcmappingmodel directory.
# $2 DEST_PATH - the path to the output .cdm file.

set -eu

source "$0.runfiles/build_bazel_rules_apple/tools/wrapper_common/wrapper_common.sh"
setup_common_tools

SOURCE_PATH="$(realpath "$1")"
DEST_PATH="$2"
shift 2

# The output file doesn't exist it, so we have to touch it before we can call
# realpath.
touch "$DEST_PATH"
DEST_PATH="$(realpath "$DEST_PATH")"

xcrunwrapper mapc "$SOURCE_PATH" "$DEST_PATH" "$@"
