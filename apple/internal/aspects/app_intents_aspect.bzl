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
    """Implementation of the App Intents aspect."""

    # TODO(b/365825041): Allow for App Intents to be defined from any dependency in "deps", as long
    # as there is only one found (for now). This will require transitively propagating the
    # AppIntentsInfo provider from all dependencies, and making sure that there's only one per top
    # level bundling rule (app, its extensions, its frameworks) at the top level bundling rule.

    if ctx.rule.kind != "swift_library":
        return []

    label = ctx.label
    sdk_frameworks = cc_info_support.get_sdk_frameworks(deps = [target], include_weak = True)
    if "AppIntents" not in sdk_frameworks.to_list():
        fail(
            "Target '%s' does not depend on the AppIntents framework. " % target.label +
            "Instead found the following system frameworks: %s" % sdk_frameworks.to_list(),
        )

    module_names = collections.uniq([x.name for x in target[SwiftInfo].direct_modules if x.swift])
    if not module_names:
        module_names = [derive_swift_module_name(label)]

    if len(module_names) > 1:
        fail("""
Found the following module names in the swift_library target {label} defining App Intents: \
{intents_module_names}

App Intents must have only one module name for metadata generation to work correctly.
""".format(
            module_names = ", ".join(module_names),
            label = str(label),
        ))
    elif len(module_names) == 0:
        fail("""
Could not find a module name for the swift_library target {label}. One is required for App Intents \
metadata generation.
""".format(
            label = str(label),
        ))

    return [
        AppIntentsInfo(
            metadata_bundle_inputs = depset([
                struct(
                    module_name = module_names[0],
                    swift_source_files = [f for f in ctx.rule.files.srcs if f.extension == "swift"],
                    swiftconstvalues_files = target[OutputGroupInfo]["const_values"].to_list(),
                ),
            ]),
        ),
    ]

app_intents_aspect = aspect(
    implementation = _app_intents_aspect_impl,
    doc = "Collects App Intents metadata dependencies from swift_library targets.",
)
