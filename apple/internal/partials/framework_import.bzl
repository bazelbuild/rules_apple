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

"""Partial implementation for framework import file processing."""

load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:apple_framework_import.bzl",
    "AppleFrameworkImportInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:codesigning_support.bzl",
    "codesigning_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:bundle_paths.bzl",
    "bundle_paths",
)
load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

def _framework_import_partial_impl(ctx, targets, targets_to_avoid):
    """Implementation for the framework import file processing partial."""
    _ignored = [ctx]

    transitive_sets = [
        x[AppleFrameworkImportInfo].framework_imports
        for x in targets
        if AppleFrameworkImportInfo in x
    ]
    files_to_bundle = depset(transitive = transitive_sets).to_list()

    if targets_to_avoid:
        avoid_transitive_sets = [
            x[AppleFrameworkImportInfo].framework_imports
            for x in targets_to_avoid
            if AppleFrameworkImportInfo in x
        ]
        if avoid_transitive_sets:
            avoid_files = depset(transitive = avoid_transitive_sets).to_list()

            # Remove any files present in the targets to avoid from framework files that need to be
            # bundled.
            files_to_bundle = [x for x in files_to_bundle if x not in avoid_files]

    # Collect the architectures that we are using for the build.
    build_archs_found = [
        build_arch
        for x in targets
        if AppleFrameworkImportInfo in x
        for build_arch in x[AppleFrameworkImportInfo].build_archs.to_list()
    ]

    # Start assembling our partial's outputs.
    bundle_zips = []
    signed_frameworks_list = []

    # Separating our files by framework path, to better address what should be passed in.
    framework_binaries_by_framework = dict()
    files_by_framework = dict()

    for file in files_to_bundle:
        framework_path = bundle_paths.farthest_parent(file.short_path, "framework")

        # Use the framework path's basename to distinguish groups of files.
        framework_basename = paths.basename(framework_path)
        if not files_by_framework.get(framework_basename):
            files_by_framework[framework_basename] = []
        if not framework_binaries_by_framework.get(framework_basename):
            framework_binaries_by_framework[framework_basename] = []

        # Check if this file is a binary to slice and code sign.
        framework_relative_path = paths.relativize(file.short_path, framework_path)

        parent_dir = framework_basename
        framework_relative_dir = paths.dirname(framework_relative_path).strip("/")
        if framework_relative_dir:
            parent_dir = paths.join(parent_dir, framework_relative_dir)

        if paths.replace_extension(parent_dir, "") == file.basename:
            framework_binaries_by_framework[framework_basename].append(file)
            continue

        # Treat the rest as files to copy into the bundle.
        files_by_framework[framework_basename].append(file)

    for framework_basename in files_by_framework.keys():
        # Create a temporary path for intermediate files and the anticipated zip output.
        temp_path = paths.join("_imported_frameworks/", framework_basename)
        framework_zip = intermediates.file(
            ctx.actions,
            ctx.label.name,
            temp_path + ".zip",
        )
        temp_framework_bundle_path = paths.split_extension(framework_zip.path)[0]

        # Pass through all binaries, files, and relevant info as args.
        args = ctx.actions.args()

        for framework_binary in framework_binaries_by_framework[framework_basename]:
            args.add("--framework_binary", framework_binary.path)

        for build_arch in build_archs_found:
            args.add("--slice", build_arch)

        args.add("--output_zip", framework_zip.path)

        args.add("--temp_path", temp_framework_bundle_path)

        for file in files_by_framework[framework_basename]:
            args.add("--framework_file", file.path)

        codesign_args = codesigning_support.codesigning_args(
            ctx,
            entitlements = None,
            full_archive_path = temp_framework_bundle_path,
            is_framework = True,
        )
        args.add_all(codesign_args)

        # Inputs of action are all the framework files, plus binaries needed for identifying the
        # current build's preferred architecture, plus a generated list of those binaries to prune
        # their dependencies so that future changes to the app/extension/framework binaries do not
        # force this action to re-run on incremental builds, plus the top-level target's
        # provisioning profile if the current build targets real devices.
        inputs = files_by_framework[framework_basename] + framework_binaries_by_framework[framework_basename]

        provisioning_profile = codesigning_support.provisioning_profile(ctx)
        execution_requirements = {}
        if provisioning_profile:
            inputs.append(provisioning_profile)
            execution_requirements = {"no-sandbox": "1"}

        apple_support.run(
            ctx,
            inputs = inputs,
            tools = [ctx.executable._codesigningtool],
            executable = ctx.executable._imported_dynamic_framework_processor,
            outputs = [framework_zip],
            arguments = [args],
            mnemonic = "ImportedDynamicFrameworkProcessor",
            execution_requirements = execution_requirements,
        )

        bundle_zips.append(
            (processor.location.framework, None, depset([framework_zip])),
        )
        signed_frameworks_list.append(framework_basename)

    return struct(
        bundle_zips = bundle_zips,
        signed_frameworks = depset(signed_frameworks_list),
    )

def framework_import_partial(targets, targets_to_avoid = []):
    """Constructor for the framework import file processing partial.

    This partial propagates framework import file bundle locations. The files are collected through
    the framework_import_aspect aspect.

    Args:
        targets: The list of targets through which to collect the framework import files.
        targets_to_avoid: The list of targets that may already be bundling some of the frameworks,
            to be used when deduplicating frameworks already bundled.

    Returns:
        A partial that returns the bundle location of the framework import files.
    """
    return partial.make(
        _framework_import_partial_impl,
        targets = targets,
        targets_to_avoid = targets_to_avoid,
    )
