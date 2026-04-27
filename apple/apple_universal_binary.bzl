# Copyright 2018 The Bazel Authors. All rights reserved.
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

"""Rule for creating Apple universal binaries."""

load(
    "@build_bazel_rules_apple//apple/internal:apple_universal_binary.bzl",
    _apple_universal_binary = "apple_universal_binary",
)

visibility("public")

apple_universal_binary = _apple_universal_binary
