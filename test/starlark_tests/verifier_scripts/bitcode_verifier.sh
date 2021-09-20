#!/bin/bash

# Copyright 2020 The Bazel Authors. All rights reserved.
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

set -euo pipefail

# This function lives in apple_shell_testutils.sh, which is sourced before this
# line is executed.
# TODO(b/131684084): Once no other integration tests are using that function,
# move its body into here and remove the legacy .ipa/.zip handling logic.
assert_ipa_contains_bitcode_maps \
    "$PLATFORM" "$ARCHIVE_ROOT" "$BC_SYMBOL_MAPS_ROOT" "${BITCODE_BINARIES[@]}"
