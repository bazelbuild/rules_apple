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

"""CoreML related actions."""

load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:xctoolrunner.bzl",
    "xctoolrunner",
)

def compile_mlmodel(
        *,
        actions,
        input_file,
        output_bundle,
        output_plist,
        platform_prerequisites,
        resolved_xctoolrunner):
    """Creates an action that compiles an mlmodel file into an mlmodelc bundle.

    Args:
      actions: The actions provider from `ctx.actions`.
      input_file: The input mlmodel file.
      output_bundle: The directory reference for the output mlmodelc bundle.
      output_plist: The file reference for the output plist from coremlc that needs to be merged.
      platform_prerequisites: Struct containing information on the platform being targeted.
      resolved_xctoolrunner: A struct referencing the resolved wrapper for "xcrun" tools.
    """
    args = [
        "coremlc",
        "compile",
        xctoolrunner.prefixed_path(input_file.path),
        output_bundle.dirname,
        "--output-partial-info-plist",
        xctoolrunner.prefixed_path(output_plist.path),
    ]

    apple_support.run(
        actions = actions,
        apple_fragment = platform_prerequisites.apple_fragment,
        arguments = args,
        executable = resolved_xctoolrunner.executable,
        inputs = depset([input_file], transitive = [resolved_xctoolrunner.inputs]),
        input_manifests = resolved_xctoolrunner.input_manifests,
        mnemonic = "MlmodelCompile",
        outputs = [output_bundle, output_plist],
        xcode_config = platform_prerequisites.xcode_version_config,
        xcode_path_wrapper = platform_prerequisites.xcode_path_wrapper,
    )

def generate_objc_mlmodel_sources(
        *,
        actions,
        input_file,
        output_source,
        output_header,
        platform_prerequisites,
        resolved_xctoolrunner):
    """Creates an action that generates sources for an mlmodel file.

    Args:
      actions: The actions provider from `ctx.actions`.
      input_file: The png file to be copied.
      output_source: The file reference for the generated ObjC source.
      output_header: The file reference for the generated ObjC header.
      platform_prerequisites: Struct containing information on the platform being targeted.
      resolved_xctoolrunner: A struct referencing the resolved wrapper for "xcrun" tools.
    """
    args = [
        "coremlc",
        "generate",
        xctoolrunner.prefixed_path(input_file.path),
        output_source.dirname,
    ]

    apple_support.run(
        actions = actions,
        apple_fragment = platform_prerequisites.apple_fragment,
        arguments = args,
        executable = resolved_xctoolrunner.executable,
        inputs = depset([input_file], transitive = [resolved_xctoolrunner.inputs]),
        input_manifests = resolved_xctoolrunner.input_manifests,
        mnemonic = "MlmodelGenerate",
        outputs = [output_source, output_header],
        xcode_config = platform_prerequisites.xcode_version_config,
        xcode_path_wrapper = platform_prerequisites.xcode_path_wrapper,
    )
