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
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleFrameworkImportInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:bitcode_support.bzl",
    "bitcode_support",
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
    "@build_bazel_rules_apple//apple/internal/utils:defines.bzl",
    "defines",
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
load(
    "@bazel_skylib//lib:sets.bzl",
    "sets",
)

def _framework_import_partial_impl(
        *,
        actions,
        apple_toolchain_info,
        label_name,
        package_symbols,
        platform_prerequisites,
        provisioning_profile,
        rule_descriptor,
        targets,
        targets_to_avoid):
    """Implementation for the framework import file processing partial."""
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
    build_archs_found = depset(transitive = [
        x[AppleFrameworkImportInfo].build_archs
        for x in targets
        if AppleFrameworkImportInfo in x
    ]).to_list()

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
            actions,
            label_name,
            temp_path + ".zip",
        )
        temp_framework_bundle_path = paths.split_extension(framework_zip.path)[0]

        # Pass through all binaries, files, and relevant info as args.
        args = actions.args()

        for framework_binary in framework_binaries_by_framework[framework_basename]:
            args.add("--framework_binary", framework_binary.path)

        for build_arch in build_archs_found:
            args.add("--slice", build_arch)

        if bitcode_support.bitcode_mode_string(platform_prerequisites.apple_fragment) == "none":
            args.add("--strip_bitcode")

        args.add("--output_zip", framework_zip.path)

        args.add("--temp_path", temp_framework_bundle_path)

        for file in files_by_framework[framework_basename]:
            args.add("--framework_file", file.path)

        codesign_args = codesigning_support.codesigning_args(
            entitlements = None,
            full_archive_path = temp_framework_bundle_path,
            is_framework = True,
            platform_prerequisites = platform_prerequisites,
            provisioning_profile = provisioning_profile,
            rule_descriptor = rule_descriptor,
        )
        args.add_all(codesign_args)

        resolved_codesigningtool = apple_toolchain_info.resolved_codesigningtool
        resolved_imported_dynamic_framework_processor = apple_toolchain_info.resolved_imported_dynamic_framework_processor

        # Inputs of action are all the framework files, plus binaries needed for identifying the
        # current build's preferred architecture, plus a generated list of those binaries to prune
        # their dependencies so that future changes to the app/extension/framework binaries do not
        # force this action to re-run on incremental builds, plus the top-level target's
        # provisioning profile if the current build targets real devices.
        input_files = files_by_framework[framework_basename] + framework_binaries_by_framework[framework_basename]

        execution_requirements = {}
        if provisioning_profile:
            input_files.append(provisioning_profile)
            execution_requirements = {"no-sandbox": "1"}
            if platform_prerequisites.platform.is_device:
                # Added so that the output of this action is not cached
                # remotely, in case multiple developers sign the same artifact
                # with different identities.
                execution_requirements["no-remote"] = "1"

        transitive_inputs = [
            resolved_imported_dynamic_framework_processor.inputs,
            resolved_codesigningtool.inputs,
        ]

        apple_support.run(
            actions = actions,
            apple_fragment = platform_prerequisites.apple_fragment,
            arguments = [args],
            executable = resolved_imported_dynamic_framework_processor.executable,
            execution_requirements = execution_requirements,
            inputs = depset(input_files, transitive = transitive_inputs),
            input_manifests = resolved_imported_dynamic_framework_processor.input_manifests +
                              resolved_codesigningtool.input_manifests,
            mnemonic = "ImportedDynamicFrameworkProcessor",
            outputs = [framework_zip],
            tools = [resolved_codesigningtool.executable],
            xcode_config = platform_prerequisites.xcode_version_config,
            xcode_path_wrapper = platform_prerequisites.xcode_path_wrapper,
        )

        bundle_zips.append(
            (processor.location.framework, None, depset([framework_zip])),
        )
        signed_frameworks_list.append(framework_basename)

    symbols_requested = defines.bool_value(
        config_vars = platform_prerequisites.config_vars,
        define_name = "apple.package_symbols",
        default = False,
    )
    if package_symbols and symbols_requested:
        transitive_dsyms = [
            x[AppleFrameworkImportInfo].dsym_imports
            for x in targets
            if AppleFrameworkImportInfo in x
        ]
        symbols = _generate_symbols(
            actions,
            build_archs_found,
            files_by_framework,
            framework_binaries_by_framework,
            transitive_dsyms,
            label_name,
            platform_prerequisites,
        )
        bundle_files = [(
            processor.location.archive,
            "Symbols",
            depset(symbols),
        )]
    else:
        bundle_files = []

    return struct(
        bundle_files = bundle_files,
        bundle_zips = bundle_zips,
        signed_frameworks = depset(signed_frameworks_list),
    )

def _generate_symbols(
        actions,
        build_archs_found,
        files_by_framework,
        framework_binaries_by_framework,
        transitive_dsyms,
        label_name,
        platform_prerequisites):
    # Collect dSYM binaries and framework binaries of frameworks that don't
    # have dSYMs
    all_binaries = []

    # Keep track of frameworks that provide dSYM, so that we can avoid
    # unnecessarily extracting symbols from said frameworks' binaries
    has_dsym_framework_basenames = sets.make()

    for file in depset(transitive = transitive_dsyms).to_list():
        # Any files that aren't Info.plist are DWARF binaries. There may be
        # more than one binary per framework depending on how the dSYM bundle
        # is packaged.
        if file.basename.lower() != "info.plist":
            all_binaries.append(file)

            # Update the set of frameworks that provide dSYMs
            framework_dsym_path = bundle_paths.farthest_parent(
                file.short_path,
                "framework.dSYM",
            )
            framework_dsym_basename = paths.basename(framework_dsym_path)
            framework_basename = framework_dsym_basename.rstrip(".dSYM")
            sets.insert(has_dsym_framework_basenames, framework_basename)

    # Find binaries of frameworks that don't provide dSYMs
    for framework_basename in files_by_framework.keys():
        for framework_binary in framework_binaries_by_framework[framework_basename]:
            if not sets.contains(has_dsym_framework_basenames, framework_basename):
                all_binaries.append(framework_binary)

    temp_path = paths.join("_imported_frameworks", "symbols_files")
    symbols_dir = intermediates.directory(
        actions,
        label_name,
        temp_path,
    )
    outputs = [symbols_dir]

    commands = ["mkdir -p \"${OUTPUT_DIR}\""]

    for binary in all_binaries:
        # If dSYMs are bundled with multiple non-fat binaries, the 'symbols'
        # command may try to extract symbols from a binary that doesn't have a
        # slice for an architecture, but it's fine since it won't return a
        # non-zero code in that case.
        for arch in build_archs_found:
            commands.append(
                ("/usr/bin/xcrun symbols -noTextInSOD -noDaemon -arch {0} " +
                 "-symbolsPackageDir \"${{OUTPUT_DIR}}\" \"{1}\"").format(
                    arch,
                    binary.path,
                ),
            )

    apple_support.run_shell(
        actions = actions,
        xcode_config = platform_prerequisites.xcode_version_config,
        apple_fragment = platform_prerequisites.apple_fragment,
        inputs = all_binaries,
        outputs = outputs,
        command = "\n".join(commands),
        env = {"OUTPUT_DIR": symbols_dir.path},
        mnemonic = "ImportedDynamicFrameworkSymbols",
    )

    return outputs

def framework_import_partial(
        *,
        actions,
        apple_toolchain_info,
        label_name,
        package_symbols = False,
        platform_prerequisites,
        provisioning_profile,
        rule_descriptor,
        targets,
        targets_to_avoid = []):
    """Constructor for the framework import file processing partial.

    This partial propagates framework import file bundle locations. The files are collected through
    the framework_import_aspect aspect.

    Args:
        actions: The actions provider from `ctx.actions`.
        apple_toolchain_info: `struct` of tools from the shared Apple toolchain.
        label_name: Name of the target being built.
        package_symbols: Whether the partial should package the symbols files for all binaries.
        platform_prerequisites: Struct containing information on the platform being targeted.
        provisioning_profile: File for the provisioning profile.
        rule_descriptor: A rule descriptor for platform and product types from the rule context.
        targets: The list of targets through which to collect the framework import files.
        targets_to_avoid: The list of targets that may already be bundling some of the frameworks,
            to be used when deduplicating frameworks already bundled.

    Returns:
        A partial that returns the bundle location of the framework import files.
    """
    return partial.make(
        _framework_import_partial_impl,
        actions = actions,
        apple_toolchain_info = apple_toolchain_info,
        label_name = label_name,
        package_symbols = package_symbols,
        platform_prerequisites = platform_prerequisites,
        provisioning_profile = provisioning_profile,
        rule_descriptor = rule_descriptor,
        targets = targets,
        targets_to_avoid = targets_to_avoid,
    )
