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
A rule for handling the cc_toolchains and their constraints for a potential universal Mach-O binary.
"""

load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)
load(
    "@bazel_tools//tools/cpp:toolchain_utils.bzl",
    "find_cpp_toolchain",
    "use_cpp_toolchain",
)
load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "ApplePlatformInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:platform_support.bzl",
    "platform_support",
)

visibility("public")

def _cc_toolchain_forwarder_impl(ctx):
    return [
        find_cpp_toolchain(ctx),
        platform_support.apple_platform_info_from_rule_ctx(ctx),
    ]

cc_toolchain_forwarder = rule(
    implementation = _cc_toolchain_forwarder_impl,
    attrs = dicts.add(
        apple_support.platform_constraint_attrs(),
        {
        },
    ),
    doc = """
Shared rule that returns CcToolchainInfo, plus a rules_apple defined provider based on querying
ctx.target_platform_has_constraint(...) that covers all Apple cpu, platform, environment constraints
for the purposes of understanding what constraints the results of each Apple split transition
resolve to from the perspective of any bundling and binary rules that generate universal Apple
binaries.
""",
    provides = [cc_common.CcToolchainInfo, ApplePlatformInfo],
    # Anticipated "new" toolchain assignment.
    toolchains = use_cpp_toolchain(),
)
