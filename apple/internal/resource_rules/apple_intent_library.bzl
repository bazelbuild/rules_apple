# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Implementation of Apple CoreML library rule."""

load(
    "@build_bazel_rules_apple//apple/internal:resource_actions.bzl",
    "resource_actions",
)
load(
    "@build_bazel_rules_apple//apple/internal:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

def _apple_intent_library_impl(ctx):
    """Implementation of the apple_intent_library."""

    is_swift = ctx.attr.language == "Swift"

    swift_output_src = None
    objc_output_srcs = None
    objc_output_hdrs = None

    if is_swift:
        swift_output_src = ctx.actions.declare_file("{}.swift".format(ctx.attr.name))
    else:
        objc_output_srcs = ctx.actions.declare_directory("{}.srcs.m".format(ctx.attr.name))
        objc_output_hdrs = ctx.actions.declare_directory("{}.hdrs.h".format(ctx.attr.name))

    platform_prerequisites = platform_support.platform_prerequisites(
        apple_fragment = ctx.fragments.apple,
        config_vars = ctx.var,
        device_families = None,
        objc_fragment = None,
        platform_type_string = str(ctx.fragments.apple.single_arch_platform.platform_type),
        uses_swift = False,
        xcode_path_wrapper = ctx.executable._xcode_path_wrapper,
        xcode_version_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
    )

    for src in ctx.files.srcs:
        resource_actions.generate_intent_classes_sources(
            actions = ctx.actions,
            input_file = src,
            swift_output_src = swift_output_src,
            objc_output_srcs = objc_output_srcs,
            objc_output_hdrs = objc_output_hdrs,
            language = ctx.attr.language,
            class_prefix = ctx.attr.class_prefix,
            swift_version = ctx.attr.swift_version,
            class_visibility = ctx.attr.class_visibility,
            module_name = ctx.attr.module_name,
            platform_prerequisites = platform_prerequisites,
            xctoolrunner_executable = ctx.executable._xctoolrunner,
        )

    if is_swift:
        return [
            DefaultInfo(files = depset([swift_output_src])),
        ]

    return [
        DefaultInfo(
            files = depset([objc_output_srcs, objc_output_hdrs]),
        ),
        OutputGroupInfo(
            srcs = depset([objc_output_srcs]),
            hdrs = depset([objc_output_hdrs]),
        ),
    ]

apple_intent_library = rule(
    implementation = _apple_intent_library_impl,
    attrs = dicts.add(apple_support.action_required_attrs(), {
        "srcs": attr.label_list(
            allow_files = [".intentdefinition"],
            mandatory = True,
            doc = """
Label to a single or multiple intentdefinition files from which to generate sources files.
""",
        ),
        "language": attr.string(
            mandatory = True,
            values = ["Objective-C", "Swift"],
            doc = "Language of generated classes (\"Objective-C\", \"Swift\")",
        ),
        "class_prefix": attr.string(
            doc = "Class prefix to use for the generated classes.",
        ),
        "swift_version": attr.string(
            doc = "Version of Swift to use for the generated classes",
        ),
        "class_visibility": attr.string(
            values = ["public", "private", "project"],
            default = "public",
            doc = "Visibility attribute for the generated classes (\"public\", \"private\", \"project\")",
        ),
        "module_name": attr.string(
            doc = "The name of the module that contains generated classes.",
        ),
        "_xctoolrunner": attr.label(
            cfg = "host",
            executable = True,
            default = Label("@build_bazel_rules_apple//tools/xctoolrunner"),
        ),
    }),
    output_to_genfiles = True,
    fragments = ["apple"],
    doc = """
This rule takes a single mlmodel file and creates a target that can be added as a dependency from
objc_library or swift_library targets. For Swift, just import like any other objc_library target.
For objc_library, this target generates a header named `<target_name>.h` that can be imported from
within the package where this target resides. For example, if this target's label is
`//my/package:coreml`, you can import the header as `#import "my/package/coreml.h"`.

This rule currently only returns an ObjC interface since the Swift generated files do not have the
necessary public interfaces to export its symbols outside of the module.
""",
)
