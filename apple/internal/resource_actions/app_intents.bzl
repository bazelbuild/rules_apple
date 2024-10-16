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

load("@build_bazel_apple_support//lib:apple_support.bzl", "apple_support")
load("@build_bazel_rules_apple//apple/internal:intermediates.bzl", "intermediates")

visibility("//apple/internal/...")

# Maps the strings passed in to the "families" attribute to the string represention used as an input
# for the App Intents Metadata Processor tool.
_PLATFORM_TYPE_TO_PLATFORM_FAMILY = {
    "ios": "iOS",
    "macos": "macOS",
    "tvos": "tvOS",
    "watchos": "watchOS",
    "visionos": "xrOS",
}

def generate_app_intents_metadata_bundle(
        *,
        actions,
        constvalues_files,
        intents_module_names,
        label,
        mac_exec_group,
        platform_prerequisites,
        source_files,
        target_triples):
    """Process and generate AppIntents metadata bundle (Metadata.appintents).

    Args:
        actions: The actions provider from `ctx.actions`.
        constvalues_files: List of swiftconstvalues files generated from Swift source files
            implementing the AppIntents protocol.
        intents_module_names: List of Strings with the module names corresponding to the modules
            found which have intents compiled.
        label: Label for the current target (`ctx.label`).
        mac_exec_group: A String. The exec_group for actions using the mac toolchain.
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

    args = actions.args()
    args.add("appintentsmetadataprocessor")

    # FB347041279: Though this is not required for --compile-time-extraction, which is the only
    # valid mode for extracting app intents metadata in Xcode 15.3, a string value is still
    # required by the appintentsmetadataprocessor.
    args.add("--binary-file", "/bazel_rules_apple/fakepath")

    if len(intents_module_names) > 1:
        fail("""
Found the following module names in the top level target {label} for app_intents: {intents_module_names}

App Intents must have only one module name for metadata generation to work correctly.
""".format(
            intents_module_names = ", ".join(intents_module_names),
            label = str(label),
        ))
    elif len(intents_module_names) == 0:
        fail("""
Could not find a module name for app_intents. One is required for App Intents metadata generation.
""")

    args.add("--module-name", intents_module_names[0])
    args.add("--output", output.dirname)
    args.add_all(
        source_files,
        before_each = "--source-files",
    )
    transitive_inputs = [depset(source_files)]
    args.add("--sdk-root", apple_support.path_placeholders.sdkroot())
    platform_type_string = str(platform_prerequisites.platform_type)
    platform_family = _PLATFORM_TYPE_TO_PLATFORM_FAMILY[platform_type_string]
    args.add("--platform-family", platform_family)
    args.add("--deployment-target", platform_prerequisites.minimum_os)
    args.add_all(target_triples, before_each = "--target-triple")
    args.add("--toolchain-dir", "{xcode_path}/Toolchains/XcodeDefault.xctoolchain".format(
        xcode_path = apple_support.path_placeholders.xcode(),
    ))
    args.add_all(
        constvalues_files,
        before_each = "--swift-const-vals",
    )
    transitive_inputs.append(depset(constvalues_files))
    args.add("--compile-time-extraction")

    # Read the build version from the fourth component of the Xcode version.
    xcode_version_split = str(xcode_version_config.xcode_version()).split(".")
    if len(xcode_version_split) < 4:
        fail("""\
Internal Error: Expected xcode_config to report the Xcode version with the build version as the \
fourth component of the full version string, but instead found {xcode_version_string}. Please file \
an issue with the Apple BUILD rules with repro steps.
""".format(
            xcode_version_string = str(xcode_version_config.xcode_version()),
        ))
    args.add("--xcode-version", xcode_version_split[3])
    if xcode_version_config.xcode_version() >= apple_common.dotted_version("16.0"):
        args.add("--validate-assistant-intents")

    apple_support.run(
        actions = actions,
        apple_fragment = platform_prerequisites.apple_fragment,
        arguments = [args],
        executable = "/usr/bin/xcrun",
        exec_group = mac_exec_group,
        inputs = depset(transitive = transitive_inputs),
        mnemonic = "AppIntentsMetadataProcessor",
        outputs = [output],
        xcode_config = xcode_version_config,
        xcode_path_resolve_level = apple_support.xcode_path_resolve_level.args,
    )

    return output
