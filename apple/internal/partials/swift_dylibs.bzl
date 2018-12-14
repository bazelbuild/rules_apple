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
    "@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:swift_support.bzl",
    "swift_support",
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
    "@build_bazel_rules_apple//apple:utils.bzl",
    "apple_actions_run",
    "xcrun_env",
)
load(
    "@bazel_skylib//lib:collections.bzl",
    "collections",
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

def _swift_dylib_action(ctx, platform_name, binary_files, output_dir):
    """Registers a swift-stlib-tool action to gather Swift dylibs to bundle."""

    swift_stdlib_tool_args = [
        "--platform",
        platform_name,
        "--output_path",
        output_dir.path,
        "--realpath",
        ctx.executable._realpath.path,
    ]

    apple_actions_run(
        ctx.actions,
        inputs = binary_files,
        tools = [ctx.executable._realpath],
        executable = ctx.executable._swift_stdlib_tool,
        outputs = [output_dir],
        arguments = swift_stdlib_tool_args + [x.path for x in binary_files],
        mnemonic = "SwiftStdlibCopy",
        env = xcrun_env(ctx),
    )

def _swift_dylibs_partial_impl(
        ctx,
        binary_artifact,
        dependency_targets,
        bundle_dylibs,
        package_swift_support):
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
    transitive_binaries = depset(transitive = transitive_binary_sets)

    if binary_artifact and swift_support.uses_swift(ctx.attr.deps):
        transitive_binaries = depset(
            direct = [binary_artifact],
            transitive = [transitive_binaries],
        )

    bundle_files = []
    propagated_binaries = depset([])
    if bundle_dylibs:
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

        if package_swift_support:
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
        package_swift_support = False):
    """Constructor for the Swift dylibs processing partial.

    This partial handles the Swift dylibs that may need to be packaged or propagated.

    Args:
      binary_artifact: The main binary artifact for this target.
      dependency_targets: List of targets that should be checked for binaries that might contain
        Swift, so that the Swift dylibs can be collected.
      bundle_dylibs: Whether the partial should return the Swift files to be bundled inside the
        target's bundle.
      package_swift_support: Whether the partial should also bundle the Swift dylib for each
        dependency platform into the SwiftSupport directory at the root of the archive.

    Returns:
      A partial that returns the bundle location of the Swift dylibs and propagates dylib
      information for upstream packaging.
    """
    return partial.make(
        _swift_dylibs_partial_impl,
        binary_artifact = binary_artifact,
        dependency_targets = dependency_targets,
        bundle_dylibs = bundle_dylibs,
        package_swift_support = package_swift_support,
    )
