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
load(
    "@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:swift_support.bzl",
    "swift_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:processor.bzl",
    "processor",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "xcrun_action",
)

_AppleSwiftDylibsInfo = provider(
    doc="""
Private provider to propagate the transitive binary `File`s that depend on
Swift.
""",
    fields={
        "binary": """
Depset of binary `File`s containing the transitive dependency binaries that use
Swift.
""",
    },
)

def _swift_dylib_action(ctx, platform_name, binary_files, output_dir):
  """Registers a swift-stlib-tool action to gather Swift dylibs to bundle."""
  args = [
      "swift-stdlib-tool",
      "--copy",
      "--destination", output_dir.path,
      "--platform", platform_name,
  ] + collections.before_each("--scan-executable", [
      x.path for x in binary_files
  ])

  xcrun_action(
      ctx,
      inputs=binary_files,
      outputs=[output_dir],
      arguments=args,
      mnemonic="SwiftStdlibCopy",
      no_sandbox=True,
  )

def _swift_dylibs_partial_impl(ctx, dependency_targets, package_dylibs, provider_key):
  """Implementation for the Swift dylibs processing partial."""
  # TODO(kaipi): Don't find the binary through the provider, but through a
  # direct File reference.
  binary_provider = ctx.attr.deps[0][provider_key]
  binary_file = binary_provider.binary

  transitive_binaries = depset(transitive=[
      x[_AppleSwiftDylibsInfo].binary for x in dependency_targets
  ])

  if swift_support.uses_swift(ctx.attr.deps):
    transitive_binaries = depset(
        [binary_file], transitive=[transitive_binaries],
    )

  bundle_files = []
  if package_dylibs:
    # TODO(kaipi): Handle multiple platforms in the same build (i.e.
    # watchos_application targets)
    platform_name = platform_support.platform(ctx).name_in_plist.lower()
    output_dir = intermediates.directory(
        ctx.actions, ctx.label.name, "swiftlibs",
    )
    _swift_dylib_action(
        ctx, platform_name, transitive_binaries.to_list(), output_dir
    )

    bundle_files.append(
        (processor.location.framework, None, depset([output_dir])),
    )

    # TODO(kaipi): Revisit if we can add this only for non enterprise optimized
    # builds, or at least only for device builds.
    swift_support_path = paths.join("SwiftSupport", platform_name)
    bundle_files.append(
        (processor.location.archive, swift_support_path, depset([output_dir])),
    )

  return struct(
      bundle_files=bundle_files,
      providers=[_AppleSwiftDylibsInfo(binary=transitive_binaries)],
  )

def swift_dylibs_partial(dependency_targets, provider_key, package_dylibs=False):
  """Constructor for the Swift dylibs processing partial.

  This partial handles the Swift dylibs that may need to be packaged or
  propagated.

  Args:
    dependency_targets: List of targets that should be checked for
      binaries that might contain Swift, so that the Swift dylibs can be
      collected.
    provider_key: The provider key under which to find the binary provider
      containing the binary artifact.
    package_dylibs: Whether the partial should return the Swift files to be
      packaged inside the target's bundle.

  Returns:
    A partial that returns the bundle location of the Swift dylibs, if there
    were any to bundle.
  """
  return partial.make(
      _swift_dylibs_partial_impl,
      dependency_targets=dependency_targets,
      package_dylibs=package_dylibs,
      provider_key=provider_key,
  )
