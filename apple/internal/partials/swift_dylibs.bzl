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
    "@build_bazel_apple_support//lib:xcode_support.bzl",
    "xcode_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/internal:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)
load(
    "@build_bazel_rules_apple//apple/internal:swift_support.bzl",
    "swift_support",
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

# Minimum OS versions after which the Swift StdLib dylibs are packaged with the OS. If the minimum
# OS version for the current target and platform is equal or above to the versions defined here,
# then we can skip copying the Swift dylibs into Frameworks and SwiftSupport.
_MIN_OS_PLATFORM_SWIFT_PRESENCE = {
    "ios": apple_common.dotted_version("12.2"),
    "macos": apple_common.dotted_version("10.14.4"),
    "tvos": apple_common.dotted_version("12.2"),
    "watchos": apple_common.dotted_version("5.2"),
}

def _swift_dylib_action(ctx, platform_name, binary_files, output_dir):
    """Registers a swift-stlib-tool action to gather Swift dylibs to bundle."""

    swift_dylibs_path = "Toolchains/XcodeDefault.xctoolchain/usr/lib/swift"

    # Xcode 11 changed the location of the Swift dylibs within the default toolchain, so we need to
    # make the dylibs path conditional on the Xcode version.
    xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]
    if xcode_support.is_xcode_at_least_version(xcode_config, "11"):
        swift_dylibs_path += "-5.0"

    swift_stdlib_tool_args = [
        "--platform",
        platform_name,
        "--output_path",
        output_dir.path,
        "--realpath",
        ctx.executable._realpath.path,
        "--swift_dylibs_path",
        swift_dylibs_path,
    ]

    apple_support.run(
        ctx,
        inputs = binary_files,
        tools = [ctx.executable._realpath],
        executable = ctx.executable._swift_stdlib_tool,
        outputs = [output_dir],
        arguments = swift_stdlib_tool_args + [x.path for x in binary_files],
        mnemonic = "SwiftStdlibCopy",
    )

def _swift_dylibs_partial_impl(
        ctx,
        binary_artifact,
        dependency_targets,
        bundle_dylibs,
        package_swift_support_if_needed):
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
    if binary_artifact and swift_support.uses_swift(ctx.attr.deps):
        target_min_os = apple_common.dotted_version(platform_support.minimum_os(ctx))
        swift_min_os = _MIN_OS_PLATFORM_SWIFT_PRESENCE[str(platform_support.platform_type(ctx))]

        # Only check this binary for Swift dylibs if the minimum OS version is lower than the
        # minimum OS version under which Swift dylibs are already packaged with the OS.
        if target_min_os < swift_min_os:
            direct_binaries.append(binary_artifact)

    transitive_binaries = depset(
        direct = direct_binaries,
        transitive = transitive_binary_sets,
    )

    bundle_files = []
    if bundle_dylibs:
        propagated_binaries = depset()
        binaries_to_check = transitive_binaries.to_list()
        if binaries_to_check:
            platform_name = platform_support.platform(ctx).name_in_plist.lower()
            output_dir = intermediates.directory(
                ctx.actions,
                ctx.label.name,
                "swiftlibs",
            )
            _swift_dylib_action(
                ctx,
                platform_name,
                binaries_to_check,
                output_dir,
            )

            bundle_files.append((processor.location.framework, None, depset([output_dir])))

            swift_support_file = (platform_name, output_dir)
            transitive_swift_support_files.append(swift_support_file)

        swift_support_requested = defines.bool_value(ctx, "apple.package_swift_support", True)
        needs_swift_support = platform_support.is_device_build(ctx) and swift_support_requested
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
        binary_artifact,
        dependency_targets = [],
        bundle_dylibs = False,
        package_swift_support_if_needed = False):
    """Constructor for the Swift dylibs processing partial.

    This partial handles the Swift dylibs that may need to be packaged or propagated.

    Args:
      binary_artifact: The main binary artifact for this target.
      dependency_targets: List of targets that should be checked for binaries that might contain
        Swift, so that the Swift dylibs can be collected.
      bundle_dylibs: Whether the partial should return the Swift files to be bundled inside the
        target's bundle.
      package_swift_support_if_needed: Whether the partial should also bundle the Swift dylib for
        each dependency platform into the SwiftSupport directory at the root of the archive. It
        might still not be included depending on what it is being built for.

    Returns:
      A partial that returns the bundle location of the Swift dylibs and propagates dylib
      information for upstream packaging.
    """
    return partial.make(
        _swift_dylibs_partial_impl,
        binary_artifact = binary_artifact,
        dependency_targets = dependency_targets,
        bundle_dylibs = bundle_dylibs,
        package_swift_support_if_needed = package_swift_support_if_needed,
    )
