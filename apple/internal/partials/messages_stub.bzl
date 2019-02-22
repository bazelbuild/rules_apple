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

"""Partial implementation for placing the messages support stub file in the archive."""

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

_AppleMessagesStubInfo = provider(
    doc = """
Private provider to propagate the messages stub that needs to be package in the iOS archive.
""",
    fields = {
        "binary": """
File artifact that contains a reference to the stub binary that needs to be packaged in the iOS
archive.
""",
    },
)

def _messages_stub_partial_impl(ctx, binary_artifact, package_messages_support):
    """Implementation for the messages support stub processing partial."""

    bundle_files = []
    providers = []

    if package_messages_support:
        # TODO(kaipi): Make extensions a parameter of the partial, not a hardcoded lookup in the
        # partial.
        if hasattr(ctx.attr, "extensions"):
            extension_binaries = [
                x[_AppleMessagesStubInfo].binary
                for x in ctx.attr.extensions
                if _AppleMessagesStubInfo in x
            ]
        elif hasattr(ctx.attr, "extension") and _AppleMessagesStubInfo in ctx.attr.extension:
            extension_binaries = [ctx.attr.extension[_AppleMessagesStubInfo].binary]
        else:
            extension_binaries = []

        if extension_binaries:
            bundle_files.append(
                (
                    processor.location.archive,
                    "MessagesApplicationExtensionSupport",
                    depset([extension_binaries[0]]),
                ),
            )

        if binary_artifact:
            intermediate_file = intermediates.file(
                ctx.actions,
                ctx.label.name,
                "MessagesApplicationSupportStub",
            )
            file_support.symlink(ctx, binary_artifact, intermediate_file)

            bundle_files.append(
                (
                    processor.location.archive,
                    "MessagesApplicationSupport",
                    depset([intermediate_file]),
                ),
            )

    elif binary_artifact:
        intermediate_file = intermediates.file(
            ctx.actions,
            ctx.label.name,
            "MessagesApplicationExtensionSupportStub",
        )
        file_support.symlink(ctx, binary_artifact, intermediate_file)
        providers.append(_AppleMessagesStubInfo(binary = intermediate_file))

    return struct(
        bundle_files = bundle_files,
        providers = providers,
    )

def messages_stub_partial(binary_artifact = None, package_messages_support = False):
    """Constructor for the messages support stub processing partial.

    This partial copies the messages support stubs into the expected location for iOS archives.

    Args:
        binary_artifact: The stub binary to copy.
        package_messages_support: Whether to package the messages stub binary in the archive root.

    Returns:
        A partial that returns the bundle location of the stub binaries.
    """
    return partial.make(
        _messages_stub_partial_impl,
        binary_artifact = binary_artifact,
        package_messages_support = package_messages_support,
    )
