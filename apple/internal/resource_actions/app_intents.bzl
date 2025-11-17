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

"""AppIntents intents related actions."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@build_bazel_apple_support//lib:apple_support.bzl", "apple_support")
load("@build_bazel_rules_apple//apple/internal:intermediates.bzl", "intermediates")

visibility("@build_bazel_rules_apple//apple/internal/...")

# Maps the strings passed in to the "families" attribute to the string representation used as an
# input for the App Intents Metadata Processor tool.
_PLATFORM_TYPE_TO_PLATFORM_FAMILY = {
    "ios": "iOS",
    "macos": "macOS",
    "tvos": "tvOS",
    "watchos": "watchOS",
    "visionos": "xrOS",
}

def _generate_intermediate_file_list(
        *,
        actions,
        file_extension,
        input_paths,
        intents_module_name,
        label):
    """Generate an intermediate file list for the AppIntents metadata processor tool.

    Args:
        actions: The actions provider from `ctx.actions`.
        file_extension: The file extension to use for the generated file list.
        input_paths: A list of paths to the files or a list of Files to include in the file list.
        intents_module_name: A String with the module name corresponding to the module found which
            defines a set of compiled App Intents.
        label: Label for the current target (`ctx.label`).
    Returns:
        A File referencing the generated file list.
    """

    file_list = intermediates.file(
        actions = actions,
        target_name = label.name,
        output_discriminator = None,
        file_name = "{module_name}.{file_extension}".format(
            file_extension = file_extension,
            module_name = intents_module_name,
        ),
    )
    file_list_args = actions.args()
    file_list_args.set_param_file_format("multiline")
    file_list_args.add_all(input_paths)
    actions.write(
        output = file_list,
        content = file_list_args,
    )
    return file_list

def _xcode_build_version(*, xcode_version_config):
    """Read the build version from the fourth component of the Xcode version."""
    xcode_version_split = str(xcode_version_config.xcode_version()).split(".")
    if len(xcode_version_split) < 4:
        fail("""\
Internal Error: Expected xcode_config to report the Xcode version with the build version as the \
fourth component of the full version string, but instead found {xcode_version_string}. Please file \
an issue with the Apple BUILD rules with repro steps.
""".format(
            xcode_version_string = str(xcode_version_config.xcode_version()),
        ))
    return xcode_version_split[3]

def generate_app_intents_metadata_bundle(
        *,
        actions,
        apple_mac_toolchain_info,
        bundle_id,
        constvalues_files,
        intents_module_name,
        label,
        mac_exec_group,
        owned_metadata_bundles,
        platform_prerequisites,
        source_files,
        target_triples):
    """Process and generate AppIntents metadata bundle (Metadata.appintents).

    Args:
        actions: The actions provider from `ctx.actions`.
        apple_mac_toolchain_info: `struct` of tools from the shared Apple toolchain.
        bundle_id: The bundle ID to configure for this target.
        constvalues_files: List of swiftconstvalues files generated from Swift source files
            implementing the AppIntents protocol.
        intents_module_name: A String with the module name corresponding to the module found which
            defines a set of compiled App Intents.
        label: Label for the current target (`ctx.label`).
        mac_exec_group: A String. The exec_group for actions using the mac toolchain.
        owned_metadata_bundles: List of depsets of (bundle, owner) pairs collected from the
            AppIntentsBundleInfo providers found from embedded targets.
        platform_prerequisites: Struct containing information on the platform being targeted.
        source_files: List of Swift source files implementing the AppIntents protocol.
        target_triples: List of Apple target triples from `CcToolchainInfo` providers.
    Returns:
        File referencing the Metadata.appintents bundle.
    """

    xcode_version_config = platform_prerequisites.xcode_version_config

    output = intermediates.directory(
        actions = actions,
        target_name = label.name,
        output_discriminator = None,
        dir_name = "Metadata.appintents",
    )

    direct_inputs = []

    args = actions.args()

    # Custom xctoolrunner options.
    args.add("passthrough-commands")
    args.add("appintentsmetadataprocessor")

    # Standard appintentsmetadataprocessor options.
    args.add("--toolchain-dir", "{xcode_path}/Toolchains/XcodeDefault.xctoolchain".format(
        xcode_path = apple_support.path_placeholders.xcode(),
    ))
    args.add("--module-name", intents_module_name)
    args.add("--sdk-root", apple_support.path_placeholders.sdkroot())
    args.add("--xcode-version", _xcode_build_version(xcode_version_config = xcode_version_config))
    args.add(
        "--platform-family",
        _PLATFORM_TYPE_TO_PLATFORM_FAMILY[platform_prerequisites.platform_type],
    )
    args.add("--deployment-target", platform_prerequisites.minimum_os)
    args.add("--bundle-identifier", bundle_id)
    args.add("--output", output.dirname)
    args.add_all(target_triples, before_each = "--target-triple")

    # Absent but not needed; --binary-file, --dependency-file, --stringsdata-file.

    source_file_list = _generate_intermediate_file_list(
        actions = actions,
        file_extension = "SwiftFileList",
        input_paths = source_files,
        intents_module_name = intents_module_name,
        label = label,
    )
    direct_inputs.append(source_file_list)
    args.add("--source-file-list", source_file_list.path)
    transitive_inputs = [depset(source_files)]

    if owned_metadata_bundles:
        owned_metadata_bundle_files = [
            p.bundle
            for x in owned_metadata_bundles
            for p in x.to_list()
        ]
        direct_inputs.extend(owned_metadata_bundle_files)

        dependency_metadata_file_list = _generate_intermediate_file_list(
            actions = actions,
            file_extension = "DependencyMetadataFileList",
            input_paths = [
                paths.join(x.path, "extract.actionsdata")
                for x in owned_metadata_bundle_files
            ],
            intents_module_name = intents_module_name,
            label = label,
        )
        direct_inputs.append(dependency_metadata_file_list)
        args.add("--metadata-file-list", dependency_metadata_file_list.path)

    swift_const_vals_file_list = _generate_intermediate_file_list(
        actions = actions,
        file_extension = "SwiftConstValuesFileList",
        input_paths = constvalues_files,
        intents_module_name = intents_module_name,
        label = label,
    )
    direct_inputs.append(swift_const_vals_file_list)
    args.add("--swift-const-vals-list", swift_const_vals_file_list.path)
    transitive_inputs.append(depset(constvalues_files))

    # Absent but seemingly not needed (b/449684440); --force.

    args.add("--compile-time-extraction")

    # Absent but not needed; --deployment-aware-processing.

    args.add("--validate-assistant-intents")

    # Absent but seemingly not needed (b/460769318); --no-app-shortcuts-localization.

    apple_support.run(
        actions = actions,
        apple_fragment = platform_prerequisites.apple_fragment,
        arguments = [args],
        executable = apple_mac_toolchain_info.xctoolrunner_alternative,
        exec_group = mac_exec_group,
        inputs = depset(direct_inputs, transitive = transitive_inputs),
        mnemonic = "AppIntentsMetadataProcessor",
        outputs = [output],
        xcode_config = xcode_version_config,
        xcode_path_resolve_level = apple_support.xcode_path_resolve_level.args,
    )

    return output
