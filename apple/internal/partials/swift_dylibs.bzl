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

"""Partial implementation for Swift dylib processing for bundles."""

load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:bitcode_support.bzl",
    "bitcode_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:defines.bzl",
    "defines",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

_AppleSwiftDylibsInfo = provider(
    doc = """
Private provider to propagate the transitive binary `File`s that depend on
Swift.
""",
    fields = {
        "binary": """
Depset of binary `File`s containing the transitive dependency binaries that use
Swift.
""",
        "swift_support_files": """
List of 2-element tuples that represent which files should be bundled as part of the SwiftSupport
archive directory. The first element of the tuple is the platform name, and the second element is a
File object that represents a directory containing the Swift dylibs to package for that platform.
""",
    },
)

# Minimum OS versions for which we no longer need to potentially bundle any
# Swift dylibs with the application. The first cutoff point was when the
# platforms bundled the standard libraries, the second was when they started
# bundling the Concurrency library. There may be future libraries that require
# us to continue bumping these values.
#
# Values are the first version where bundling is no longer required and should
# correspond with the Swift compilers values for these which is the source of
# truth https://github.com/apple/swift/blob/998d3518938bd7229e7c5e7b66088d0501c02051/lib/Basic/Platform.cpp#L82-L105
_MIN_OS_PLATFORM_SWIFT_PRESENCE = {
    "ios": apple_common.dotted_version("12.2"),
    "macos": apple_common.dotted_version("10.14.4"),
    "tvos": apple_common.dotted_version("12.2"),
    "watchos": apple_common.dotted_version("5.2"),
}

_MIN_OS_PLATFORM_SWIFT_CONCURRENCY_PRESENCE = {
    "ios": apple_common.dotted_version("15.0"),
    "macos": apple_common.dotted_version("12.0"),
    "tvos": apple_common.dotted_version("15.0"),
    "watchos": apple_common.dotted_version("8.0"),
}

def _swift_dylib_action(
        *,
        actions,
        binary_files,
        output_dir,
        platform_name,
        platform_prerequisites,
        resolved_swift_stdlib_tool,
        strip_bitcode,
        swift_dylibs_paths):
    """Registers a swift-stlib-tool action to gather Swift dylibs to bundle."""
    swift_stdlib_tool_args = [
        "--platform",
        platform_name,
        "--output_path",
        output_dir.path,
    ]
    for x in swift_dylibs_paths:
        swift_stdlib_tool_args.extend([
            "--swift_dylibs_path",
            x,
        ])
    for x in binary_files:
        swift_stdlib_tool_args.extend([
            "--binary",
            x.path,
        ])

    if strip_bitcode:
        swift_stdlib_tool_args.append("--strip_bitcode")

    apple_support.run(
        actions = actions,
        apple_fragment = platform_prerequisites.apple_fragment,
        arguments = swift_stdlib_tool_args,
        executable = resolved_swift_stdlib_tool.executable,
        inputs = depset(binary_files, transitive = [resolved_swift_stdlib_tool.inputs]),
        input_manifests = resolved_swift_stdlib_tool.input_manifests,
        mnemonic = "SwiftStdlibCopy",
        outputs = [output_dir],
        xcode_config = platform_prerequisites.xcode_version_config,
    )

def _target_platform_is_arm_simulator(platform_prerequisites):
    """Returns True if the target platform is a simulator with arm64 architecture, otherwise False.

    Args:
      platform_prerequisites: Struct containing information on the platform being targeted.
    """

    return (platform_prerequisites.apple_fragment.single_arch_cpu == "arm64" and
            not platform_prerequisites.platform.is_device)

def _swift_dylibs_partial_impl(
        *,
        actions,
        apple_mac_toolchain_info,
        binary_artifact,
        bundle_dylibs,
        dependency_targets,
        label_name,
        output_discriminator,
        package_swift_support_if_needed,
        platform_prerequisites):
    """Implementation for the Swift dylibs processing partial."""

    # Collect transitive data.
    transitive_binary_sets = []
    transitive_swift_support_files = []
    for dependency in dependency_targets:
        if _AppleSwiftDylibsInfo not in dependency:
            # Skip targets without the _AppleSwiftDylibsInfo provider, as they don't use Swift
            # (i.e. sticker extensions that have stubs).
            continue
        provider = dependency[_AppleSwiftDylibsInfo]
        transitive_binary_sets.append(provider.binary)
        transitive_swift_support_files.extend(provider.swift_support_files)

    direct_binaries = []
    target_min_os = apple_common.dotted_version(platform_prerequisites.minimum_os)
    if binary_artifact and platform_prerequisites.uses_swift:
        swift_concurrency_min_os = _MIN_OS_PLATFORM_SWIFT_CONCURRENCY_PRESENCE[str(platform_prerequisites.platform_type)]

        # Only check this binary for Swift dylibs if the minimum OS version is lower than the
        # minimum OS version under which Swift dylibs are already packaged with the OS.
        if target_min_os < swift_concurrency_min_os:
            direct_binaries.append(binary_artifact)

    swift_min_os = _MIN_OS_PLATFORM_SWIFT_PRESENCE[str(platform_prerequisites.platform_type)]
    swift_dylibs_path_prefix = "Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-"
    swift_dylibs_paths = [swift_dylibs_path_prefix + "5.5"]

    # Workaround for https://bugs.swift.org/browse/SR-16010.
    if (target_min_os < swift_min_os and
        # There's no such a simulator on Apple silicon Macs with a minimum OS
        # version before ABI stability, so it's unnecessary to bundle the
        # original Swift runtime here.
        not _target_platform_is_arm_simulator(platform_prerequisites)):
        swift_dylibs_paths.append(swift_dylibs_path_prefix + "5.0")

    transitive_binaries = depset(
        direct = direct_binaries,
        transitive = transitive_binary_sets,
    )

    strip_bitcode = bitcode_support.bitcode_mode_string(platform_prerequisites.apple_fragment) == "none"

    swift_support_requested = defines.bool_value(
        config_vars = platform_prerequisites.config_vars,
        define_name = "apple.package_swift_support",
        default = True,
    )
    needs_swift_support = platform_prerequisites.platform.is_device and swift_support_requested

    bundle_files = []
    if bundle_dylibs:
        propagated_binaries = depset()
        binaries_to_check = transitive_binaries.to_list()
        if binaries_to_check:
            platform_name = platform_prerequisites.platform.name_in_plist.lower()
            output_dir = intermediates.directory(
                actions = actions,
                target_name = label_name,
                output_discriminator = output_discriminator,
                dir_name = "swiftlibs",
            )
            _swift_dylib_action(
                actions = actions,
                binary_files = binaries_to_check,
                output_dir = output_dir,
                platform_name = platform_name,
                platform_prerequisites = platform_prerequisites,
                resolved_swift_stdlib_tool = apple_mac_toolchain_info.resolved_swift_stdlib_tool,
                strip_bitcode = strip_bitcode,
                swift_dylibs_paths = swift_dylibs_paths,
            )

            bundle_files.append((processor.location.framework, None, depset([output_dir])))

            if needs_swift_support:
                if strip_bitcode:
                    # We're not allowed to modify stdlibs that are used for
                    # Swift Support, so we register another action for copying
                    # them without stripping bitcode.
                    swift_support_output_dir = intermediates.directory(
                        actions = actions,
                        target_name = label_name,
                        output_discriminator = output_discriminator,
                        dir_name = "swiftlibs_for_swiftsupport",
                    )
                    _swift_dylib_action(
                        actions = actions,
                        binary_files = binaries_to_check,
                        output_dir = swift_support_output_dir,
                        platform_name = platform_name,
                        platform_prerequisites = platform_prerequisites,
                        resolved_swift_stdlib_tool = apple_mac_toolchain_info.resolved_swift_stdlib_tool,
                        strip_bitcode = False,
                        swift_dylibs_paths = swift_dylibs_paths,
                    )
                else:
                    # When not building with bitcode, we can reuse Swift dylibs
                    # for bundling in both SwiftSupport and in the app bundle's
                    # "Frameworks" directory.
                    swift_support_output_dir = output_dir

                swift_support_file = (platform_name, swift_support_output_dir)
                transitive_swift_support_files.append(swift_support_file)

        if package_swift_support_if_needed and needs_swift_support:
            # Package all the transitive SwiftSupport dylibs into the archive for this target.
            bundle_files.extend([
                (
                    processor.location.archive,
                    paths.join("SwiftSupport", platform),
                    depset([directory]),
                )
                for platform, directory in transitive_swift_support_files
            ])
    else:
        # If this target does not bundle dylibs, then propagate the transitive binaries to be
        # consumed by higher-level dependents. If this target does bundle dylibs, then remove the
        # transitive binaries from the provider graph, as they don't need to be processed again.
        # This also provides a clear separation of transitive binaries when jumping between
        # platforms (i.e. watchOS dependencies in iOS).
        propagated_binaries = transitive_binaries

    return struct(
        bundle_files = bundle_files,
        providers = [_AppleSwiftDylibsInfo(
            binary = propagated_binaries,
            swift_support_files = transitive_swift_support_files,
        )],
    )

def swift_dylibs_partial(
        *,
        actions,
        apple_mac_toolchain_info,
        binary_artifact,
        bundle_dylibs = False,
        dependency_targets = [],
        label_name,
        output_discriminator = None,
        package_swift_support_if_needed = False,
        platform_prerequisites):
    """Constructor for the Swift dylibs processing partial.

    This partial handles the Swift dylibs that may need to be packaged or propagated.

    Args:
      actions: The actions provider from `ctx.actions`.
      apple_mac_toolchain_info: `struct` of tools from the shared Apple toolchain.
      binary_artifact: The main binary artifact for this target.
      bundle_dylibs: Whether the partial should return the Swift files to be bundled inside the
        target's bundle.
      dependency_targets: List of targets that should be checked for binaries that might contain
        Swift, so that the Swift dylibs can be collected.
      label_name: Name of the target being built.
      output_discriminator: A string to differentiate between different target intermediate files
          or `None`.
      package_swift_support_if_needed: Whether the partial should also bundle the Swift dylib for
        each dependency platform into the SwiftSupport directory at the root of the archive. It
        might still not be included depending on what it is being built for.
      platform_prerequisites: Struct containing information on the platform being targeted.

    Returns:
      A partial that returns the bundle location of the Swift dylibs and propagates dylib
      information for upstream packaging.
    """
    return partial.make(
        _swift_dylibs_partial_impl,
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        binary_artifact = binary_artifact,
        bundle_dylibs = bundle_dylibs,
        dependency_targets = dependency_targets,
        label_name = label_name,
        output_discriminator = output_discriminator,
        package_swift_support_if_needed = package_swift_support_if_needed,
        platform_prerequisites = platform_prerequisites,
    )
