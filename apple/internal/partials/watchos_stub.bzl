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

"""Partial implementation for placing the watchOS stub file in the archive."""

load(
    "@build_bazel_rules_apple//apple/internal:file_support.bzl",
    "file_support",
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
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)

_AppleWatchosStubInfo = provider(
    doc = """
Private provider to propagate the watchOS stub that needs to be package in the iOS archive.
""",
    fields = {
        "binary": """
File artifact that contains a reference to the stub binary that needs to be packaged in the iOS
archive.
""",
    },
)

def _watchos_stub_partial_impl(ctx, binary_artifact, package_watchkit_support):
    """Implementation for the watchOS stub processing partial."""

    bundle_files = []
    providers = []
    if binary_artifact:
        # Create intermediate file with proper name for the binary.
        intermediate_file = intermediates.file(
            ctx.actions,
            ctx.label.name,
            "WK",
        )
        file_support.symlink(ctx, binary_artifact, intermediate_file)
        bundle_files.append(
            (processor.location.bundle, "_WatchKitStub", depset([intermediate_file])),
        )
        providers.append(_AppleWatchosStubInfo(binary = intermediate_file))

    if package_watchkit_support:
        binary_artifact = ctx.attr.watch_application[_AppleWatchosStubInfo].binary
        bundle_files.append(
            (processor.location.archive, "WatchKitSupport2", depset([binary_artifact])),
        )

    return struct(
        bundle_files = bundle_files,
        providers = providers,
    )

def watchos_stub_partial(binary_artifact = None, package_watchkit_support = False):
    """Constructor for the watchOS stub processing partial.

    This partial copies the WatchKit stub into the expected location inside the watchOS bundle.
    This partial only applies to the watchos_application rule for bundling the WK stub binary, and
    to the ios_application rule for packaging the stub in the WatchKitSupport2 root directory.

    Args:
        binary_artifact: The stub binary to copy.
        package_watchkit_support: Whether to package the watchOS stub binary in the archive root.

    Returns:
      A partial that returns the bundle location of the stub binary.
    """
    return partial.make(
        _watchos_stub_partial_impl,
        binary_artifact = binary_artifact,
        package_watchkit_support = package_watchkit_support,
    )
