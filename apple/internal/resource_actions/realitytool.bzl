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
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:xctoolrunner.bzl",
    xctoolrunner_support = "xctoolrunner",
)

visibility("//apple/internal/...")

# Maps the apple_common platforms supported for rkassets schema generation to the string
# represention used as an input for realitytool.
_PLATFORM_TO_TOOL_PLATFORM = {
    str(apple_common.platform.visionos_device): "xros",
    str(apple_common.platform.visionos_simulator): "xrsimulator",
}

def create_schema_rkassets(
        *,
        actions,
        label_name,
        mac_exec_group,
        module_name,
        output_discriminator,
        output_file,
        platform_prerequisites,
        swift_files,
        transitive_swift_srcs):
    """Creates an action that generates a USDA schema from Swift source files for a reality bundle.

    Args:
      actions: The actions provider from `ctx.actions`.
      label_name: The String representing the target that owns this action.
      mac_exec_group: The exec_group associated with Apple actions
      module_name: The String representing the module name for the target that owns this action.
      output_discriminator: A String to differentiate between different target intermediate files or
        `None`.
      output_file: The File reference for the output schema (Pixar usda format).
      platform_prerequisites: Struct containing information on the platform being targeted.
      swift_files: A depset of swift source File inputs that will be used to build the schema.
      transitive_swift_srcs: A list of AppleResourceSwiftSourcesInfo providers representing
        transitive Swift module names and source files if any are required for building the schema.
    """

    # Intermediate step; create a JSON file with json.encode(...) on a struct and write that to a
    # file that will be the argument for the following action, as well as one of its arguments.

    transitive_inputs = [swift_files]
    dependencies = []
    for source_provider in transitive_swift_srcs:
        for swift_src_info in source_provider.transitive_swift_src_infos.to_list():
            src_files = swift_src_info.src_files
            transitive_inputs.append(src_files)
            dependencies.append(struct(
                moduleName = swift_src_info.module_name,
                swiftFiles = [x.short_path for x in src_files.to_list()],
            ))
    module_with_deps = struct(
        dependencies = dependencies,
        module = struct(
            moduleName = module_name,
            swiftFiles = [x.short_path for x in swift_files.to_list()],
        ),
    )
    module_with_deps_json_file = intermediates.file(
        actions = actions,
        target_name = label_name,
        output_discriminator = output_discriminator,
        file_name = "ModuleWithDependencies.json",
    )
    actions.write(
        output = module_with_deps_json_file,
        content = json.encode(module_with_deps),
    )
    apple_support.run(
        actions = actions,
        apple_fragment = platform_prerequisites.apple_fragment,
        arguments = [
            "realitytool",
            "create-schema",
            "--output-schema",
            output_file.path,
            module_with_deps_json_file.path,
        ],
        exec_group = mac_exec_group,
        executable = "/usr/bin/xcrun",
        inputs = depset([module_with_deps_json_file], transitive = transitive_inputs),
        mnemonic = "CreateSchemaRealityKitAssets",
        outputs = [output_file],
        xcode_config = platform_prerequisites.xcode_version_config,
    )

def compile_rkassets(
        *,
        actions,
        input_files,
        input_path,
        mac_exec_group,
        output_file,
        platform_prerequisites,
        xctoolrunner,
        schema_file):
    """Creates an action that compiles Reality Composer Pro bundles (i.e. .rkassets).

    Args:
      actions: The actions provider from `ctx.actions`.
      input_files: The Reality Composer Pro File inputs that will be compiled.
      input_path: The path to the .rkassets directory to compile.
      mac_exec_group: The exec_group associated with Apple actions.
      output_file: The File reference for the compiled .reality output.
      platform_prerequisites: Struct containing information on the platform being targeted.
      xctoolrunner: A files_to_run for the wrapper around the "xcrun" tool.
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
    args.add("compile")

    # This is a custom arg to signal to xctool runner that this is the *actual* input bundle.
    # Unfortunately, realitytool writes directly to the rkassets bundle it is given when the
    # --schema-file option is supplied, requiring an intermediate temp bundle path to be given to
    # the tool itself.
    args.add("--bazel_input_path", input_path)

    args.add("--platform", _PLATFORM_TO_TOOL_PLATFORM[str(platform_prerequisites.platform)])
    args.add("--deployment-target", platform_prerequisites.minimum_os)
    if schema_file:
        args.add("--schema-file", xctoolrunner_support.prefixed_path(schema_file.path))
        direct_inputs.append(schema_file)
    args.add("--output-reality", xctoolrunner_support.prefixed_path(output_file.path))

    execution_requirements = {}

    apple_support.run(
        actions = actions,
        apple_fragment = platform_prerequisites.apple_fragment,
        arguments = [args],
        exec_group = mac_exec_group,
        executable = xctoolrunner,
        execution_requirements = execution_requirements,
        inputs = depset(direct_inputs, transitive = [input_files]),
        mnemonic = "CompileRealityKitAssets",
        outputs = [output_file],
        xcode_config = platform_prerequisites.xcode_version_config,
    )
