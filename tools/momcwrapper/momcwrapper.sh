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
# momcwrapper runs momc and zips up the output.
# This script only runs on darwin and you must have Xcode installed.
#
# $1 OUTZIP - the path to place the output zip file.
# $2 NAME - output file name

set -eu

source "$0.runfiles/build_bazel_rules_apple/tools/wrapper_common/wrapper_common.sh"
setup_common_tools

OUTZIP="$(realpath "$1")"
NAME="$2"
shift 2
TEMPDIR="$(create_temp_dir momcZippingOutput.XXXXXX)"

xcrunwrapper momc "$@" "$TEMPDIR/$NAME"

finalize_output_as_zip "$TEMPDIR" "$OUTZIP"
