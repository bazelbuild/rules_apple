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

def _should_package_clang_runtime(*, features):
    """Returns whether the Clang runtime should be bundled."""

    # List of crosstool sanitizer features that require packaging some clang
    # runtime libraries.
    features_requiring_clang_runtime = {
        "asan": True,
        "tsan": True,
        "ubsan": True,
    }

    for feature in features:
        if feature in features_requiring_clang_runtime:
            return True
    return False

# TODO(b/161370390): Remove ctx from the args when ctx is removed from all partials.
def _clang_rt_dylibs_partial_impl(
        *,
        ctx,
        actions,
        binary_artifact,
        clangrttool,
        features,
        label_name,
        platform_prerequisites):
    """Implementation for the Clang runtime dylibs processing partial."""
    bundle_zips = []
    if _should_package_clang_runtime(features = features):
        clang_rt_zip = intermediates.file(
            actions,
            label_name,
            "clang_rt.zip",
        )

        legacy_actions.run(
            actions = actions,
            arguments = [
                binary_artifact.path,
                clang_rt_zip.path,
            ],
            executable = clangrttool,
            # This action needs to read the contents of the Xcode bundle.
            execution_requirements = {"no-sandbox": "1"},
            inputs = [binary_artifact],
            outputs = [clang_rt_zip],
            mnemonic = "ClangRuntimeLibsCopy",
            platform_prerequisites = platform_prerequisites,
        )

        bundle_zips.append(
            (processor.location.framework, None, depset([clang_rt_zip])),
        )

    return struct(
        bundle_zips = bundle_zips,
    )

def clang_rt_dylibs_partial(
        *,
        actions,
        binary_artifact,
        clangrttool,
        features,
        label_name,
        platform_prerequisites):
    """Constructor for the Clang runtime dylibs processing partial.

    Args:
      actions: The actions provider from `ctx.actions`.
      binary_artifact: The main binary artifact for this target.
      clangrttool: A reference to a tool to find all Clang runtime libs linked to a binary.
      features: List of features enabled by the user. Typically from `ctx.features`.
      label_name: Name of the target being built.
      platform_prerequisites: Struct containing information on the platform being targeted.

    Returns:
      A partial that returns the bundle location of the Clang runtime dylibs, if there were any to
      bundle.
    """
    return partial.make(
        _clang_rt_dylibs_partial_impl,
        actions = actions,
        binary_artifact = binary_artifact,
        clangrttool = clangrttool,
        features = features,
        label_name = label_name,
        platform_prerequisites = platform_prerequisites,
    )
