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

"""Intent definitions related actions."""

load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:xctoolrunner.bzl",
    "xctoolrunner",
)

def generate_intent_classes_sources(
        *,
        actions,
        input_file,
        output_srcs_directory,
        output_hdrs_directory,
        language,
        class_prefix,
        swift_version,
        class_visibility,
        module_name,
        platform_prerequisites,
        xctoolrunner_executable):
    """Creates an action that code generates intent classes from an
    intentdefinition file.

    Args:
        actions: The actions provider from `ctx.actions`.
        input_file: The intent definition file.
        output_directory: Output directory.
        language: Language of generated classes ("Objective-C", "Swift").
        class_prefix: Class prefix to use for the generated classes.
        swift_version: Version of Swift to use for the generated classes.
        class_visibility: Visibility attribute for the generated classes.
        module_name: The name of the module that contains generated classes.
        platform_prerequisites: Struct containing information on the platform being targeted.
    """

    apple_support.run(
        actions = actions,
        apple_fragment = platform_prerequisites.apple_fragment,
        arguments = [
            "intentbuilderc",
            "generate",
            "-input",
            xctoolrunner.prefixed_path(input_file.path),
            "-output",
            output_srcs_directory.path,
            "-language",
            language,
            "-classPrefix",
            class_prefix,
            "-swiftVersion",
            swift_version,
            "-visibility",
            class_visibility,
            "-moduleName",
            module_name,

            # Custom to rules_apple
            "-output_hdrs",
            output_hdrs_directory.path,
        ],
        executable = xctoolrunner_executable,
        inputs = [input_file],
        mnemonic = "IntentGenerate",
        outputs = [output_srcs_directory, output_hdrs_directory],
        xcode_config = platform_prerequisites.xcode_version_config,
        xcode_path_wrapper = platform_prerequisites.xcode_path_wrapper,
    )
