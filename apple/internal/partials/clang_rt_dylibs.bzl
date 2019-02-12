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

"""Partial implementation for Clang runtime libraries processing."""

load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:legacy_actions.bzl",
    "legacy_actions",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)

def _should_package_clang_runtime(ctx):
    """Returns whether the Clang runtime should be bundled."""

    # List of crosstool sanitizer features that require packaging some clang
    # runtime libraries.
    features_requiring_clang_runtime = {
        "asan": True,
        "tsan": True,
        "ubsan": True,
    }

    for feature in ctx.features:
        if feature in features_requiring_clang_runtime:
            return True
    return False

def _clang_rt_dylibs_partial_impl(ctx, binary_artifact):
    """Implementation for the Clang runtime dylibs processing partial."""
    bundle_zips = []
    if _should_package_clang_runtime(ctx):
        clang_rt_zip = intermediates.file(
            ctx.actions,
            ctx.label.name,
            "clang_rt.zip",
        )

        legacy_actions.run(
            ctx,
            inputs = [binary_artifact],
            outputs = [clang_rt_zip],
            executable = ctx.executable._clangrttool,
            arguments = [
                binary_artifact.path,
                clang_rt_zip.path,
            ],
            mnemonic = "ClangRuntimeLibsCopy",
            # This action needs to read the contents of the Xcode bundle.
            execution_requirements = {"no-sandbox": "1"},
        )

        bundle_zips.append(
            (processor.location.framework, None, depset([clang_rt_zip])),
        )

    return struct(
        bundle_zips = bundle_zips,
    )

def clang_rt_dylibs_partial(binary_artifact):
    """Constructor for the Clang runtime dylibs processing partial.

    Args:
      binary_artifact: The main binary artifact for this target.

    Returns:
      A partial that returns the bundle location of the Clang runtime dylibs, if there were any to
      bundle.
    """
    return partial.make(
        _clang_rt_dylibs_partial_impl,
        binary_artifact = binary_artifact,
    )
