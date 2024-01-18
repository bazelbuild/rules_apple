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

"""realitytool related actions."""

load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:xctoolrunner.bzl",
    "xctoolrunner",
)

visibility("//apple/internal/...")

# Maps the apple_common platforms supported for rkassets schema generation to the string
# represention used as an input for realitytool.
_PLATFORM_TO_TOOL_PLATFORM = {
    str(apple_common.platform.visionos_device): "xros",
    str(apple_common.platform.visionos_simulator): "xrsimulator",
}

def compile_rkassets(
        *,
        actions,
        input_files,
        input_path,
        mac_exec_group,
        output_file,
        platform_prerequisites,
        resolved_xctoolrunner,
        schema_file):
    """Creates an action that compiles Reality Composer Pro bundles (i.e. .rkassets).

    Args:
      actions: The actions provider from `ctx.actions`.
      input_files: The Reality Composer Pro File inputs that will be compiled.
      input_path: The path to the .rkassets directory to compile.
      mac_exec_group: The exec_group associated with Apple actions
      output_file: The File reference for the compiled .reality output.
      platform_prerequisites: Struct containing information on the platform being targeted.
      resolved_xctoolrunner: A reference to the executable wrapper for "xcrun" tools.
      schema_file: The File reference for the optional usda schema file, composed from swift sources
        if any were provided for this rkassets bundle through one or more associated swift_library
        targets.
    """

    if platform_prerequisites.platform_type != apple_common.platform_type.visionos:
        fail("""
rkassets processing is not yet supported outside of visionOS.

Please file an issue with the Apple BUILD rules with the platform you would like for the rules to
support if you have a project that desires this feature.
""")

    direct_inputs = []

    args = actions.args()
    args.add("realitytool")
    args.add("compile", xctoolrunner.prefixed_path(input_path))
    args.add("--platform", _PLATFORM_TO_TOOL_PLATFORM[str(platform_prerequisites.platform)])
    args.add("--deployment-target", platform_prerequisites.minimum_os)
    if schema_file:
        args.add("--schema-file", xctoolrunner.prefixed_path(schema_file.path))
        direct_inputs.append(schema_file)
    args.add("--output-reality", xctoolrunner.prefixed_path(output_file.path))

    apple_support.run(
        actions = actions,
        apple_fragment = platform_prerequisites.apple_fragment,
        arguments = [args],
        exec_group = mac_exec_group,
        executable = resolved_xctoolrunner.executable,
        inputs = depset(direct_inputs, transitive = [input_files, resolved_xctoolrunner.inputs]),
        input_manifests = resolved_xctoolrunner.input_manifests,
        mnemonic = "CompileRealityKitAssets",
        outputs = [output_file],
        xcode_config = platform_prerequisites.xcode_version_config,
    )
