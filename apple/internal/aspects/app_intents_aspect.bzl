# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""Implementation of the aspect that propagates AppIntentsInfo providers."""

load(
    "@bazel_skylib//lib:collections.bzl",
    "collections",
)
load("@build_bazel_rules_apple//apple/internal:cc_info_support.bzl", "cc_info_support")
load(
    "@build_bazel_rules_apple//apple/internal/providers:app_intents_info.bzl",
    "AppIntentsInfo",
)
load(
    "@build_bazel_rules_swift//swift:module_name.bzl",
    "derive_swift_module_name",
)
load(
    "@build_bazel_rules_swift//swift:providers.bzl",
    "SwiftInfo",
)

visibility("//apple/internal/...")

def _app_intents_aspect_impl(target, ctx):
    """Implementation of the swift source files propation aspect."""
    if ctx.rule.kind != "swift_library":
        return []

    sdk_frameworks = cc_info_support.get_sdk_frameworks(deps = [target], include_weak = True)
    if "AppIntents" not in sdk_frameworks.to_list():
        fail(
            "Target '%s' does not depend on the AppIntents SDK framework. " % target.label +
            "Found the following SDK frameworks: %s" % sdk_frameworks.to_list(),
        )

    module_names = collections.uniq([x.name for x in target[SwiftInfo].direct_modules if x.swift])
    if not module_names:
        module_names = [derive_swift_module_name(ctx.label)]

    return [
        AppIntentsInfo(
            intent_module_names = module_names,
            swift_source_files = ctx.rule.files.srcs,
            swiftconstvalues_files = target[OutputGroupInfo]["const_values"].to_list(),
        ),
    ]

app_intents_aspect = aspect(
    implementation = _app_intents_aspect_impl,
    doc = "Collects Swift source files from swift_library targets required by AppIntents tooling.",
)
