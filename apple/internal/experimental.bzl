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

"""Temporary file to centralize configuration of the experimental bundling logic."""

load(
    "@build_bazel_rules_apple//apple/internal/utils:defines.bzl",
    "defines",
)

def is_experimental_tree_artifact_enabled(ctx):
    """Returns whether tree artifact outputs experiment is enabled."""
    return defines.bool_value(ctx, "apple.experimental.tree_artifact_outputs", False)
