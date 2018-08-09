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

"""File references to important output files from the rule.

These file references can be used across the bundling logic, but there must be only 1 action
registered to generate these files.
"""

load(
    "@build_bazel_rules_apple//apple/bundling/experimental:intermediates.bzl",
    "intermediates",
)

def _infoplist(ctx):
    """Returns a file reference for this target's Info.plist file."""
    return intermediates.file(ctx.actions, ctx.label.name, "Info.plist")

def _archive(ctx):
    """Returns a file reference for this target's archive."""

    # TODO(kaipi): Look into removing this rule implicit output and just return it using
    # DefaultInfo.
    return ctx.outputs.archive

outputs = struct(
    infoplist = _infoplist,
    archive = _archive,
)
