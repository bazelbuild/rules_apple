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

"""Intent definitions related actions."""

load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:xctoolrunner.bzl",
    "xctoolrunner",
)
load(
    "@bazel_skylib//lib:versions.bzl",
    "versions",
)

def generate_intent_classes_sources(
        *,
        actions,
        input_file,
        swift_output_src,
        objc_output_srcs,
        objc_output_hdrs,
        objc_public_header,
        language,
        class_prefix,
        swift_version,
        class_visibility,
        platform_prerequisites,
        resolved_xctoolrunner):
    """Creates an action that cgenerates intent classes from an intentdefinition file.

    Args:
        actions: The actions provider from `ctx.actions`.
        input_file: The intent definition file.
        swift_output_src: The output file when generating Swift sources.
        objc_output_srcs: The output sources directory when generating ObjC.
        objc_output_hdrs: The output headers directory when generating ObjC.
        objc_public_header: The output public header.
        language: Language of generated classes ("Objective-C", "Swift").
        class_prefix: Class prefix to use for the generated classes.
        swift_version: Version of Swift to use for the generated classes.
        class_visibility: Visibility attribute for the generated classes.
        platform_prerequisites: Struct containing information on the platform being targeted.
        resolved_xctoolrunner: A reference to the executable wrapper for "xcrun" tools.
    """

    is_swift = language == "Swift"

    arguments = [
        "intentbuilderc",
        "generate",
        "-input",
        xctoolrunner.prefixed_path(input_file.path),
        "-language",
        language,
        "-classPrefix",
        class_prefix,
        "-swiftVersion",
        swift_version,
    ]

    # Starting Xcode 12, intentbuilderc accepts new parameters
    xcode_version = str(platform_prerequisites.xcode_version_config.xcode_version())
    if versions.is_at_least("12.0.0", xcode_version):
        arguments += [
            "-visibility",
            class_visibility,
        ]

    outputs = []
    if is_swift:
        arguments += [
            "-swift_output_src",
            swift_output_src.path,
        ]
        outputs = [swift_output_src]
    else:
        arguments += [
            "-objc_output_srcs",
            objc_output_srcs.path,
            "-objc_output_hdrs",
            objc_output_hdrs.path,
            "-objc_public_header",
            objc_public_header.path,
        ]
        outputs = [objc_output_srcs, objc_output_hdrs, objc_public_header]

    apple_support.run(
        actions = actions,
        apple_fragment = platform_prerequisites.apple_fragment,
        arguments = arguments,
        executable = resolved_xctoolrunner.executable,
        inputs = depset([input_file], transitive = [resolved_xctoolrunner.inputs]),
        mnemonic = "IntentGenerate",
        outputs = outputs,
        xcode_config = platform_prerequisites.xcode_version_config,
    )
