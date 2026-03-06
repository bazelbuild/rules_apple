# Copyright 2022 The Bazel Authors. All rights reserved.
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

"""
A rule for handling the cc_toolchains and their constraints for a potential "fat" Mach-O binary.
"""

load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)
load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@rules_cc//cc:find_cc_toolchain.bzl",
    "find_cc_toolchain",
    "use_cc_toolchain",
)
load(
    "//apple/internal:platform_support.bzl",
    "platform_support",
)

visibility("public")

def _cc_toolchain_forwarder_impl(ctx):
    return [
        find_cc_toolchain(ctx),
        platform_support.apple_platform_info_from_rule_ctx(ctx),
    ]

cc_toolchain_forwarder = rule(
    implementation = _cc_toolchain_forwarder_impl,
    attrs = dicts.add(
        apple_support.platform_constraint_attrs(),
        {
            # Legacy style toolchain assignment.
            "_cc_toolchain": attr.label(
                default = Label("@rules_cc//cc:current_cc_toolchain"),
            ),
        },
    ),
    doc = """
Shared rule that returns CcToolchainInfo, plus a rules_apple defined provider based on querying
ctx.target_platform_has_constraint(...) that covers all Apple cpu, platform, environment constraints
for the purposes of understanding what constraints the results of each Apple split transition
resolve to from the perspective of any bundling and binary rules that generate "fat" Apple binaries.
""",
    # Anticipated "new" toolchain assignment.
    toolchains = use_cc_toolchain(),
)
