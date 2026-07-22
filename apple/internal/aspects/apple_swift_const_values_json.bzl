# Copyright 2026 The Bazel Authors. All rights reserved.
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

"""Implementation of the apple_swift_const_values_json rule.

This rule provides a target that defines the swift const values JSON file, either by extracting
it directly from the Mac toolchain's Apple SDK (for Xcode >= 26.4), or by falling back to a
provided JSON file for older SDKs.
"""

load(
    "@build_bazel_rules_swift//swift:providers.bzl",
    "SwiftInfo",
)

visibility([
    "@build_bazel_rules_apple//apple/internal/...",
])

def _apple_swift_const_values_json_impl(ctx):
    framework_swift_info = ctx.attr.sdk_source[SwiftInfo]
    sdk_name = ctx.attr.sdk_source.label.name
    const_gather_protocols = None
    for module in framework_swift_info.direct_modules:
        if module.name == sdk_name and module.const_gather_protocols:
            const_gather_protocols = module.const_gather_protocols
            break
    if not const_gather_protocols:
        fail("Internal Error: No Swift const values JSON file found for SDK: %s" % sdk_name)

    swift_const_values_json_file = ctx.actions.declare_file(
        "{sdk_name}.json".format(
            sdk_name = sdk_name,
        ),
    )
    ctx.actions.write(
        output = swift_const_values_json_file,
        content = json.encode(struct(
            version = 1,
            constValueProtocols = const_gather_protocols,
        )),
    )

    return DefaultInfo(files = depset([swift_const_values_json_file]))

apple_swift_const_values_json = rule(
    implementation = _apple_swift_const_values_json_impl,
    attrs = {
        "sdk_source": attr.label(
            mandatory = True,
            doc = "The SDK framework to extract the Swift const values JSON (e.g. 'AppIntents').",
        ),
    },
    doc = "Generates a JSON file for evaluation of Swift const values.",
)
