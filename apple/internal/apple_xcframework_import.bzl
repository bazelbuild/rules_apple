# Copyright 2022 The Bazel Authors. All rights reserved.
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

"""Implementation of XCFramework import rules."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain", "use_cpp_toolchain")
load("@build_bazel_apple_support//lib:apple_support.bzl", "apple_support")
load(
    "@build_bazel_rules_apple//apple/internal:cc_toolchain_info_support.bzl",
    "cc_toolchain_info_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:experimental.bzl",
    "is_experimental_tree_artifact_enabled",
)
load(
    "@build_bazel_rules_apple//apple/internal:framework_import_support.bzl",
    "framework_import_support",
)
load("@build_bazel_rules_apple//apple/internal:intermediates.bzl", "intermediates")
load(
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "AppleFrameworkImportInfo",
)
load("@build_bazel_rules_apple//apple/internal:rule_attrs.bzl", "rule_attrs")
load(
    "@build_bazel_rules_apple//apple/internal/aspects:swift_usage_aspect.bzl",
    "SwiftUsageInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:apple_dynamic_framework_info.bzl",
    "AppleDynamicFrameworkInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/toolchains:apple_toolchains.bzl",
    "apple_toolchain_utils",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:bundle_paths.bzl",
    "bundle_paths",
)
load(
    "@build_bazel_rules_swift//swift:swift_clang_module_aspect.bzl",
    "swift_clang_module_aspect",
)
load("@build_bazel_rules_swift//swift:swift_common.bzl", "swift_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

# Currently, XCFramework bundles can contain Apple frameworks or libraries.
# This defines an _enum_ to identify an imported XCFramework bundle type.
_BUNDLE_TYPE = struct(frameworks = 1, libraries = 2)

# The name of the execution group that houses the Swift toolchain and is used to
# run Swift actions.
_SWIFT_EXEC_GROUP = "swift"

def _anticipated_framework_root_info_plist_path(
        *,
        bundle_name,
        has_versioned_framework_files,
        target_triplet):
    """Returns the anticipated path of the root Info.plist for a framework bundle.

    Args:
        bundle_name: The bundle name of the framework within the XCFramework.
        has_versioned_framework_files: Boolean indicating whether the XCFramework contains versioned
            framework files.
        target_triplet: Effective target triplet from CcToolchainInfo provider.
    Returns:
        A String representing the anticipated path of the root Info.plist for a framework bundle
            for actionable error messages.
    """
    example_root_info_plist_relative_path = ""
    if target_triplet.os == "macos":
        if has_versioned_framework_files:
            example_root_info_plist_relative_path = "{}/Info.plist".format(
                framework_import_support.macos_versioned_root_infoplist_path,
            )
        else:
            example_root_info_plist_relative_path = "{}/Info.plist".format(
                framework_import_support.macos_nonversioned_root_infoplist_path,
            )
    else:
        example_root_info_plist_relative_path = "Info.plist"

    return "{bundle_name}.framework/{relative_path}".format(
        bundle_name = bundle_name,
        relative_path = example_root_info_plist_relative_path,
    )

def _classify_xcframework_imports(
        *,
        apple_xplat_toolchain_info,
        config_vars,
        label_name,
        target_triplet,
        xcframework_imports):
    """Classifies XCFramework files for later processing, with some early validation applied.

    Args:
        apple_xplat_toolchain_info: An AppleXPlatToolsToolchainInfo provider.
        config_vars: A dictionary (String to String) of config variables. Typically from `ctx.var`.
        label_name: Name of the target being built.
        target_triplet: Effective target triplet from CcToolchainInfo provider.
        xcframework_imports: List of File for an imported Apple XCFramework.
    Returns:
        A struct containing xcframework import files information:
            - bundle_name: The XCFramework bundle name infered by filepaths.
            - bundle_type: The XCFramework bundle type (frameworks or libraries).
            - files: The XCFramework import files.
            - files_by_category: Classified XCFramework import files.
            - info_plist: The XCFramework bundle Info.plist file.
    """
    has_versioned_framework_files = framework_import_support.has_versioned_framework_files(
        xcframework_imports,
    )
    tree_artifact_enabled = (
        apple_xplat_toolchain_info.build_settings.use_tree_artifacts_outputs or
        is_experimental_tree_artifact_enabled(config_vars = config_vars)
    )
    if target_triplet.os == "macos" and has_versioned_framework_files and tree_artifact_enabled:
        # TODO(b/258492867): Add tree artifacts support when Bazel can handle remote actions with
        # symlinks. See https://github.com/bazelbuild/bazel/issues/16361.
        fail("""
Error: "{label_name}" does not currently support versioned frameworks with the tree artifact \
feature/build setting. Please ensure that the `apple.experimental.tree_artifact_outputs` variable \
is not set to 1 on the command line or in your active build configuration.
""".format(label_name = label_name))

    info_plist = None
    bundle_name = None

    framework_files = []
    xcframework_files = []
    for file in xcframework_imports:
        parent_dir_name = paths.basename(file.dirname)
        is_bundle_root_file = parent_dir_name.endswith(".xcframework")

        if not info_plist and is_bundle_root_file and file.basename == "Info.plist":
            bundle_name, _ = paths.split_extension(parent_dir_name)
            info_plist = file
            continue

        if ".framework/" in file.short_path:
            framework_files.append(file)
        else:
            xcframework_files.append(file)

    if not info_plist:
        fail("""
Error: XCFramework import files were expected to include a root Info.plist acting as a source of \
truth for the XCFramework's contents, but the root Info.plist could not be found.
""")
    if not bundle_name:
        fail("""
Error: Could not determine the XCFramework's bundle name from the root Info.plist file path. \
Please verify that an Info.plist was supplied at the root of the XCFramework bundle.
        """)

    if framework_files:
        files = framework_files
        bundle_type = _BUNDLE_TYPE.frameworks
        files_by_category = framework_import_support.classify_framework_imports(
            framework_imports = files,
        )

    else:
        files = xcframework_files
        bundle_type = _BUNDLE_TYPE.libraries
        files_by_category = framework_import_support.classify_file_imports(files)

    return struct(
        bundle_name = bundle_name,
        bundle_type = bundle_type,
        files = files,
        files_by_category = files_by_category,
        info_plist = info_plist,
    )

def _get_xcframework_library_with_xcframework_processor(
        *,
        actions,
        apple_fragment,
        apple_mac_toolchain_info,
        label,
        mac_exec_group,
        target_triplet,
        xcframework,
        xcode_config):
    """Identify the appropriate XCFramework library for the target platform and architecture.

    Additionally, this exports a dummy file to register an action that leverages the
    xcframework_processor tool to validate decisions made at analysis time.

    Args:
        actions: The actions provider from `ctx.actions`.
        apple_fragment: An Apple fragment (ctx.fragments.apple).
        apple_mac_toolchain_info: An AppleMacToolsToolchainInfo provider.
        label: Label of the target being built.
        mac_exec_group: The exec_group associated with apple_mac_toolchain
        target_triplet: Struct referring a Clang target triplet.
        xcframework: Struct containing imported XCFramework details.
        xcode_config: The `apple_common.XcodeVersionConfig` provider from the context.
    Returns:
        A struct containing processed XCFramework files:
            binary: File referencing the XCFramework library binary.
            framework_imports: List of File referencing XCFramework library files to be bundled
                by a top-level target (ios_application) consuming the target being built.
            framework_includes: List of strings referencing parent directories for framework
                bundles.
            headers: List of File referencing XCFramework library header files. This can be either
                a single tree artifact or a list of regular artifacts.
            processor_output: File that represents the output of the XCFramework validation action.
            clang_module_map: File referencing the XCFramework library Clang modulemap file.
            swift_module_interface: File referencing the XCFramework library Swift module interface
                file (`.swiftinterface`).
    """
    files_by_category = xcframework.files_by_category

    library_identifier = _get_library_identifier(
        binary_imports = xcframework.files_by_category.binary_imports,
        bundle_type = xcframework.bundle_type,
        target_architecture = target_triplet.architecture,
        target_environment = target_triplet.environment,
        target_platform = target_triplet.os,
    )

    if not library_identifier:
        fail("""
ERROR: Could not find a path within the XCFramework bundle referenced by {label} to determine the \
input files matching the target triple {architecture}-{environment}-{os}.

Attempted to find source paths containing those three identifiers from the following binary inputs:
{binary_imports}

Check that the referenced XCFramework has any subdirectories of the form \
"os-architecture-environment", such as "ios-arm64_x86_64-simulator", or "macos-arm64", and that \
you are building for a valid target Apple OS. (i.e., not Linux, not Windows)

Please file an issue with the Apple BUILD rules if the contents of the XCFramework and the build \
invocation appear to be valid.
""".format(
            architecture = target_triplet.architecture,
            binary_imports = "\n".join([
                f.path
                for f in xcframework.files_by_category.binary_imports
            ]),
            environment = target_triplet.environment,
            label = label,
            os = target_triplet.os,
        ))

    # With the library identifier at hand, we can reduce the set of Files to only those needed for
    # this specific platform without relying on the unstable behavior of an intermittent tree
    # artifact. From here on, reduce Files and split paths to what downstream logic expects.
    def filter_by_library_identifier(files):
        return [f for f in files if "/{}/".format(library_identifier) in f.short_path]

    # Do some extra filtering for binary_imports, in the event of a "Versioned" framework. These
    # will likely contain a symlink for the binary, which we want to filter out, as the dynamic
    # framework processor will insert one of its own.
    binary_imports = filter_by_library_identifier(files_by_category.binary_imports)
    has_versioned_framework_files = framework_import_support.has_versioned_framework_files(
        binary_imports,
    )
    if has_versioned_framework_files:
        binary_imports = framework_import_support.get_canonical_versioned_framework_files(
            binary_imports,
        )

    if len(binary_imports) > 1:
        fail("""
Error: Unexpectedly found more than one candidate for a framework binary:

{binary_imports}

There should only be one valid framework binary, given a name that matches its XCFramework bundle.
""".format(binary_imports = "\n".join([f.path for f in binary_imports])))

    framework_imports = filter_by_library_identifier(files_by_category.bundling_imports)

    framework_info_plist = None
    if xcframework.bundle_type == _BUNDLE_TYPE.frameworks:
        # For XCFrameworks that contain frameworks, go through an extra filtering step for root
        # Info.plists to ensure that we have only one valid candidate for the framework's root
        # Info.plist.
        root_info_plists = filter_by_library_identifier(files_by_category.root_info_plists)
        if has_versioned_framework_files:
            root_info_plists = framework_import_support.get_canonical_versioned_framework_files(
                root_info_plists,
            )

        if len(root_info_plists) == 0:
            fail("""
Error: Unexpectedly found no root Info.plist from the non-binary files found in the XCFramework:

{framework_imports}

There must be one root Info.plist in the framework bundle at \
\"{example_root_info_plist_path}\".

Make sure that the precompiled XCFramework has included a root Info.plist declaring a valid \
minimum OS version appropriate for the given platform at the specified location.
""".format(
                framework_imports = "\n".join([f.short_path for f in framework_imports]),
                example_root_info_plist_path = _anticipated_framework_root_info_plist_path(
                    bundle_name = xcframework.bundle_name,
                    has_versioned_framework_files = has_versioned_framework_files,
                    target_triplet = target_triplet,
                ),
            ))

        if len(root_info_plists) > 1:
            fail("""
Error: Unexpectedly found more than one candidate for a root Info.plist from the non-binary files \
found in the XCFramework:

{root_info_plists}

There must be only one root Info.plist in the framework bundle at \
\"{example_root_info_plist_path}\".

Conflicting Info.plists might have come from trying to build an Apple target relying on an \
XCFramework with simulator and device architectures. Check that your build invocation is not \
attempting to mix simulator and device architectures.
""".format(
                example_root_info_plist_path = _anticipated_framework_root_info_plist_path(
                    bundle_name = xcframework.bundle_name,
                    has_versioned_framework_files = has_versioned_framework_files,
                    target_triplet = target_triplet,
                ),
                root_info_plists = "\n".join([f.path for f in root_info_plists]),
            ))

        framework_info_plist = root_info_plists[0]

    header_imports = filter_by_library_identifier(files_by_category.header_imports)
    module_map_imports = filter_by_library_identifier(files_by_category.module_map_imports)
    swift_module_interfaces = framework_import_support.get_swift_module_files_with_target_triplet(
        swift_module_files = filter_by_library_identifier(
            files_by_category.swift_interface_imports,
        ),
        target_triplet = target_triplet,
    )

    args = actions.args()
    args.add("validate-root-info-plist")
    args.add("--library-identifier", library_identifier)
    args.add("--bundle-name", xcframework.bundle_name)
    args.add("--info-plist-input-path", xcframework.info_plist.path)

    args.add("--platform", target_triplet.os)
    args.add("--architecture", target_triplet.architecture)
    args.add("--environment", target_triplet.environment)

    inputs = [xcframework.info_plist]
    processor_output = intermediates.file(
        actions = actions,
        file_name = "xcframework_processor_output.txt",
        target_name = label.name,
        output_discriminator = "",
    )
    args.add("--output-path", processor_output.path)
    outputs = [processor_output]

    xcframework_processor_tool = apple_mac_toolchain_info.xcframework_processor_tool

    apple_support.run(
        actions = actions,
        apple_fragment = apple_fragment,
        arguments = [args],
        executable = xcframework_processor_tool,
        exec_group = mac_exec_group,
        inputs = inputs,
        mnemonic = "ProcessXCFrameworkFiles",
        outputs = outputs,
        xcode_config = xcode_config,
    )

    framework_includes = []
    includes = []
    if xcframework.bundle_type == _BUNDLE_TYPE.frameworks:
        if has_versioned_framework_files:
            # Going up to {bundle_name}.framework/Versions/A/{binary_file}
            framework_includes = [
                paths.dirname(paths.dirname(paths.dirname(f.dirname)))
                for f in binary_imports
            ]
        else:
            framework_includes = [paths.dirname(f.dirname) for f in binary_imports]
    else:
        # For library XCFrameworks, in Xcode the contents of "Headers" are copied to an intermediate
        # directory for referencing artifacts to include in the build; to replicate this behavior,
        # make sure "includes" is set at the point where "Headers" is found, adjacent to any
        # binaries.
        if header_imports:
            includes = [paths.join(f.dirname, "Headers") for f in binary_imports]

    return struct(
        binary = binary_imports[0],
        framework_imports = framework_imports,
        framework_includes = framework_includes,
        framework_info_plist = framework_info_plist,
        headers = header_imports,
        includes = includes,
        processor_output = processor_output,
        clang_module_map = module_map_imports[0] if module_map_imports else None,
        swift_module_interface = swift_module_interfaces[0] if swift_module_interfaces else None,
    )

def _get_library_identifier(
        *,
        binary_imports,
        bundle_type,
        target_architecture,
        target_environment,
        target_platform):
    """Returns an XCFramework library identifier for a given target triplet based on import files.

    Args:
        binary_imports: List of files referencing XCFramework binaries.
        bundle_type: The XCFramework bundle type (frameworks or libraries).
        target_architecture: The target Apple architecture for the target being built (e.g. x86_64,
            arm64).
        target_environment: The target Apple environment for the target being built (e.g. simulator,
            device).
        target_platform: The target Apple platform for the target being built (e.g. macos, ios).
    Returns:
        A string for a XCFramework library identifier.
    """

    # Look for the library identifiers in directory paths, based on binary files passed through.
    if bundle_type == _BUNDLE_TYPE.frameworks:
        # For an XCFramework of frameworks, this will potentially be a mix of macOS binaries and *OS
        # binaries. Check for both types if we are looking at an XCFramework of frameworks.
        library_identifiers = []
        for binary_file in binary_imports:
            if paths.dirname(binary_file.dirname).endswith("/Versions"):
                # Accounting for binaries in Versions/.../ here...
                #
                # Going up {library_identifier}/{bundle_name}.framework/Versions/A/{binary_file}
                library_identifier = paths.basename(
                    paths.dirname(paths.dirname(paths.dirname(binary_file.dirname))),
                )
                library_identifiers.append(library_identifier)
            else:
                # Otherwise, assume the binary is at the root of the framework bundle.
                #
                # Going up {library_identifier}/{bundle_name}.framework/{binary_file}
                library_identifiers.append(paths.basename(paths.dirname(binary_file.dirname)))

    elif bundle_type == _BUNDLE_TYPE.libraries:
        # For an XCFramework of libraries, these will always be easily identified one level up from
        # the binary in question.
        #
        # Going up {library_identifier}/{binary_file}
        library_identifiers = [paths.basename(f.dirname) for f in binary_imports]
    else:
        fail("Unrecognized XCFramework bundle type: %s" % bundle_type)

    for library_identifier in library_identifiers:
        platform, _, suffix = library_identifier.partition("-")
        architectures, _, environment = suffix.partition("-")

        if platform != target_platform:
            continue

        if target_architecture not in architectures:
            continue

        # Extra handling of path matching for arm64* architectures.
        if target_architecture == "arm64":
            arm64_index = architectures.find(target_architecture)
            arm64e_index = architectures.find("arm64e")
            arm64_32_index = architectures.find("arm64_32")

            if arm64_index == arm64e_index or arm64_index == arm64_32_index:
                continue

        if target_environment == "device" and not environment:
            return library_identifier

        if target_environment != "device" and target_environment == environment:
            return library_identifier

    return None

def _collect_signature_from_xcframework(
        *,
        actions,
        apple_fragment,
        apple_mac_toolchain_info,
        binary,
        codesigned_xcframework_imports,
        label,
        mac_exec_group,
        platform_type,
        xcode_config):
    """Given codesigned_xcframework_imports produces a signatures XML plist for the archive.

    Args:
        actions: The actions provider from `ctx.actions`.
        apple_fragment: An Apple fragment (ctx.fragments.apple).
        apple_mac_toolchain_info: An AppleMacToolsToolchainInfo provider.
        binary: The singular binary File to help us identify the library to report in metadata.
        codesigned_xcframework_imports: A List of Files representing the complete XCFramework to
            generate the signature XML plist from, representing its code signed status.
        label: Label of the target being built.
        mac_exec_group: The exec_group associated with apple_mac_toolchain.
        platform_type: Platform to report in metadata.
        xcode_config: The `apple_common.XcodeVersionConfig` provider from the context.
    Returns:
        A File representing a generated signatures XML plist if one is necessary or None.
    """
    if not codesigned_xcframework_imports:
        return None

    args = actions.args()
    args.add("collect-signatures")

    xcframework_path = bundle_paths.farthest_parent(binary.path, "xcframework")
    args.add("--signatures-input-path", xcframework_path)

    inputs = codesigned_xcframework_imports
    signature_output = intermediates.file(
        actions = actions,
        file_name = "{xcframework_basename}-{platform_type}.signature".format(
            platform_type = platform_type,
            xcframework_basename = paths.basename(xcframework_path),
        ),
        target_name = label.name,
        output_discriminator = "",
    )
    args.add("--signatures-output-path", signature_output.path)

    args.add("--metadata-info", "platform={0}".format(platform_type))

    library_path = ""
    if binary.extension == "a":
        library_path = binary.path
    elif not binary.extension:
        library_path = bundle_paths.farthest_parent(binary.path, "framework")
    else:
        fail("""
Error: Could not determine metadata needed to generate a Signatures XML file for the \
framework referenced by {label_name}.

Found binary with path of {binary_path} that does not end with a static library archive .a or \
resemble a binary within a framework bundle.

Please file an issue with the Apple BUILD rules if the contents of the XCFramework and the build \
invocation appear to be valid.
""".format(
            binary_path = binary.path,
            label_name = label.name,
        ))
    args.add(
        "--metadata-info",
        "library={library_basename}".format(
            library_basename = paths.basename(library_path),
        ),
    )

    signature_tool = apple_mac_toolchain_info.signature_tool

    apple_support.run(
        actions = actions,
        apple_fragment = apple_fragment,
        arguments = [args],
        executable = signature_tool,
        exec_group = mac_exec_group,
        inputs = inputs,
        mnemonic = "CollectXCFrameworkSignature",
        outputs = [signature_output],
        xcode_config = xcode_config,
    )

    return signature_output

def _generate_empty_dylib(
        *,
        actions,
        apple_fragment,
        apple_mac_toolchain_info,
        framework_info_plist,
        label,
        mac_exec_group,
        target_triplet,
        xcode_config):
    """Generates the empty dylib required for Apple static frameworks in Xcode 15.4 "bundle & sign".

    Args:
        actions: The actions provider from `ctx.actions`.
        apple_fragment: An Apple fragment (ctx.fragments.apple).
        apple_mac_toolchain_info: An AppleMacToolsToolchainInfo provider.
        framework_info_plist: The Info.plist file to base the generated framework binary path on and
            to use for the empty dylib.
        label: Label of the target being built.
        mac_exec_group: The exec_group associated with apple_mac_toolchain.
        target_triplet: The target triplet to use for the empty dylib.
        xcode_config: The `apple_common.XcodeVersionConfig` provider from the context.

    Returns:
        An empty dylib suitable for embedding within a static framework bundle for a shipping app in
            Xcode 15+.
    """

    if not framework_info_plist:
        fail("""
Error: The framework generated by the target "{label_name}" does not have a root Info.plist. One \
is needed to submit a framework that is bundled and signed as a "codeless framework" for Xcode, \
such as a static framework or a framework with mergeable libraries.
        """.format(label_name = label.name))

    args = actions.args()
    args.add("generate-stub-dylib")

    inputs = [framework_info_plist]
    args.add("--framework-info-plist-input-path", framework_info_plist.path)
    args.add("--sdk-root-input-path", apple_support.path_placeholders.sdkroot())
    args.add(
        "--xcode-toolchain-input-path",
        "{xcode_path}/Toolchains/XcodeDefault.xctoolchain".format(
            xcode_path = apple_support.path_placeholders.xcode(),
        ),
    )

    args.add("--platform", target_triplet.os)
    args.add("--architecture", target_triplet.architecture)
    args.add("--environment", target_triplet.environment)

    framework_path = bundle_paths.farthest_parent(framework_info_plist.path, "framework")
    framework_basename = paths.basename(framework_path)
    framework_name = paths.split_extension(framework_basename)[0]

    framework_binary_subdir = ""
    if framework_import_support.has_versioned_framework_files([framework_info_plist]):
        framework_binary_subdir = framework_import_support.macos_versioned_root_binary_path

    stub_binary_relative_path = ""
    if framework_binary_subdir:
        stub_binary_relative_path = paths.join(
            framework_basename,
            framework_binary_subdir,
            framework_name,
        )
    else:
        stub_binary_relative_path = paths.join(framework_basename, framework_name)

    stub_binary = intermediates.file(
        actions = actions,
        file_name = stub_binary_relative_path,
        output_discriminator = "",
        target_name = label.name,
    )

    args.add("--output-path", stub_binary.path)

    xcframework_processor_tool = apple_mac_toolchain_info.xcframework_processor_tool

    apple_support.run(
        actions = actions,
        apple_fragment = apple_fragment,
        arguments = [args],
        executable = xcframework_processor_tool,
        exec_group = mac_exec_group,
        inputs = inputs,
        mnemonic = "GenerateFrameworkEmptyDylib",
        outputs = [stub_binary],
        xcode_config = xcode_config,
        xcode_path_resolve_level = apple_support.xcode_path_resolve_level.args,
    )

    return stub_binary

def _apple_dynamic_xcframework_import_impl(ctx):
    """Implementation for the apple_dynamic_framework_import rule."""
    actions = ctx.actions
    apple_fragment = ctx.fragments.apple
    apple_mac_toolchain_info = apple_toolchain_utils.get_mac_toolchain(ctx)
    apple_xplat_toolchain_info = apple_toolchain_utils.get_xplat_toolchain(ctx)
    cc_toolchain = find_cpp_toolchain(ctx)
    codesigned_xcframework_imports = ctx.files.codesigned_xcframework_imports
    deps = ctx.attr.deps
    disabled_features = ctx.disabled_features
    features = ctx.features
    label = ctx.label
    mac_exec_group = apple_toolchain_utils.get_mac_exec_group(ctx)
    xcframework_imports = ctx.files.xcframework_imports
    xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]

    target_triplet = cc_toolchain_info_support.get_apple_clang_triplet(cc_toolchain)

    xcframework = _classify_xcframework_imports(
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        config_vars = ctx.var,
        label_name = label.name,
        target_triplet = target_triplet,
        xcframework_imports = xcframework_imports,
    )
    if xcframework.bundle_type == _BUNDLE_TYPE.libraries:
        fail("Importing XCFrameworks with dynamic libraries is not supported.")

    xcframework_library = _get_xcframework_library_with_xcframework_processor(
        actions = actions,
        apple_fragment = apple_fragment,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        label = label,
        mac_exec_group = mac_exec_group,
        target_triplet = target_triplet,
        xcframework = xcframework,
        xcode_config = xcode_config,
    )

    providers = [
        OutputGroupInfo(
            _validation = depset([xcframework_library.processor_output]),
        ),
    ]

    signature_file = _collect_signature_from_xcframework(
        actions = actions,
        apple_fragment = apple_fragment,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        binary = xcframework_library.binary,
        codesigned_xcframework_imports = codesigned_xcframework_imports,
        label = label,
        mac_exec_group = mac_exec_group,
        platform_type = target_triplet.os,
        xcode_config = xcode_config,
    )

    # Create AppleFrameworkImportInfo provider
    apple_framework_import_info = framework_import_support.framework_import_info_with_dependencies(
        binary_imports = [xcframework_library.binary],
        build_archs = [target_triplet.architecture],
        bundling_imports = xcframework_library.framework_imports,
        deps = deps,
        signature_files = [signature_file] if signature_file else [],
    )
    providers.append(apple_framework_import_info)

    # Create CcInfo provider
    cc_info = framework_import_support.cc_info_with_dependencies(
        actions = actions,
        cc_toolchain = cc_toolchain,
        ctx = ctx,
        deps = deps,
        disabled_features = disabled_features,
        features = features,
        framework_includes = xcframework_library.framework_includes,
        header_imports = xcframework_library.headers,
        kind = "dynamic",
        label = label,
        libraries = [xcframework_library.binary],
    )
    providers.append(cc_info)

    # Create AppleDynamicFrameworkInfo provider
    providers.append(AppleDynamicFrameworkInfo(
        framework_linking_context = cc_info.linking_context,
    ))

    if xcframework_library.swift_module_interface:
        # Create SwiftInfo provider
        swift_toolchains = swift_common.find_all_toolchains(ctx)
        providers.append(
            framework_import_support.swift_info_from_module_interface(
                actions = actions,
                ctx = ctx,
                deps = deps,
                disabled_features = disabled_features,
                features = features,
                module_name = xcframework.bundle_name,
                swift_toolchains = swift_toolchains,
                swiftinterface_file = xcframework_library.swift_module_interface,
            ),
        )
    else:
        # Create SwiftInteropInfo provider for swift_clang_module_aspect
        swift_interop_info = framework_import_support.swift_interop_info_with_dependencies(
            deps = deps,
            module_name = xcframework.bundle_name,
            module_map_imports = [xcframework_library.clang_module_map],
        )
        if swift_interop_info:
            providers.append(swift_interop_info)

    return providers

def _apple_static_xcframework_import_impl(ctx):
    """Implementation of apple_static_xcframework_import."""
    actions = ctx.actions
    alwayslink = ctx.attr.alwayslink or ctx.fragments.objc.alwayslink_by_default
    apple_fragment = ctx.fragments.apple
    apple_mac_toolchain_info = apple_toolchain_utils.get_mac_toolchain(ctx)
    apple_xplat_toolchain_info = apple_toolchain_utils.get_xplat_toolchain(ctx)
    cc_toolchain = find_cpp_toolchain(ctx)
    codesigned_xcframework_imports = ctx.files.codesigned_xcframework_imports
    deps = ctx.attr.deps
    disabled_features = ctx.disabled_features
    features = ctx.features
    has_swift = ctx.attr.has_swift
    label = ctx.label
    linkopts = ctx.attr.linkopts
    mac_exec_group = apple_toolchain_utils.get_mac_exec_group(ctx)
    xcframework_imports = ctx.files.xcframework_imports
    xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]

    target_triplet = cc_toolchain_info_support.get_apple_clang_triplet(cc_toolchain)

    xcframework = _classify_xcframework_imports(
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        config_vars = ctx.var,
        label_name = label.name,
        target_triplet = target_triplet,
        xcframework_imports = xcframework_imports,
    )

    xcframework_library = _get_xcframework_library_with_xcframework_processor(
        actions = actions,
        apple_fragment = apple_fragment,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        label = label,
        mac_exec_group = mac_exec_group,
        target_triplet = target_triplet,
        xcframework = xcframework,
        xcode_config = xcode_config,
    )

    providers = [
        OutputGroupInfo(
            _validation = depset([xcframework_library.processor_output]),
        ),
    ]

    if xcframework.bundle_type == _BUNDLE_TYPE.libraries:
        providers.append(DefaultInfo(files = depset(xcframework_imports)))

    signature_file = _collect_signature_from_xcframework(
        actions = actions,
        apple_fragment = apple_fragment,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        binary = xcframework_library.binary,
        codesigned_xcframework_imports = codesigned_xcframework_imports,
        label = label,
        mac_exec_group = mac_exec_group,
        platform_type = target_triplet.os,
        xcode_config = xcode_config,
    )

    stub_binary_imports = []
    bundling_imports = []
    if xcframework.bundle_type == _BUNDLE_TYPE.frameworks:
        # Add an empty dylib to the bundle to make the static framework valid for App Store Connect.
        stub_binary = _generate_empty_dylib(
            actions = actions,
            apple_fragment = apple_fragment,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            framework_info_plist = xcframework_library.framework_info_plist,
            label = label,
            mac_exec_group = mac_exec_group,
            target_triplet = target_triplet,
            xcode_config = xcode_config,
        )
        stub_binary_imports.append(stub_binary)
        bundling_imports = xcframework_library.framework_imports

    # Create AppleFrameworkImportInfo provider
    apple_framework_import_info = framework_import_support.framework_import_info_with_dependencies(
        binary_imports = stub_binary_imports,
        build_archs = [target_triplet.architecture],
        bundling_imports = bundling_imports,
        deps = deps,
        signature_files = [signature_file] if signature_file else [],
    )
    providers.append(apple_framework_import_info)

    additional_cc_infos = []
    if xcframework.files_by_category.swift_interface_imports or has_swift:
        swift_toolchains = swift_common.find_all_toolchains(ctx)
        providers.append(SwiftUsageInfo())

        # The Swift toolchain propagates Swift-specific linker flags (e.g.,
        # library/framework search paths) as an implicit dependency. In the
        # rare case that a binary has a Swift framework import dependency but
        # no other Swift dependencies, make sure we pick those up so that it
        # links to the standard libraries correctly.
        additional_cc_infos.extend(swift_toolchains.swift.implicit_deps_providers.cc_infos)

    # Create CcInfo provider
    cc_info = framework_import_support.cc_info_with_dependencies(
        actions = actions,
        additional_cc_infos = additional_cc_infos,
        alwayslink = alwayslink,
        cc_toolchain = cc_toolchain,
        ctx = ctx,
        deps = deps,
        disabled_features = disabled_features,
        features = features,
        framework_includes = xcframework_library.framework_includes,
        header_imports = xcframework_library.headers,
        kind = "static",
        label = label,
        libraries = [xcframework_library.binary],
        linkopts = linkopts,
        includes = xcframework_library.includes,
    )
    providers.append(cc_info)

    if xcframework_library.swift_module_interface:
        # Create SwiftInfo provider
        swift_toolchains = swift_common.find_all_toolchains(ctx)
        providers.append(
            framework_import_support.swift_info_from_module_interface(
                actions = actions,
                ctx = ctx,
                deps = deps,
                disabled_features = disabled_features,
                features = features,
                module_name = xcframework.bundle_name,
                swift_toolchains = swift_toolchains,
                swiftinterface_file = xcframework_library.swift_module_interface,
            ),
        )
    else:
        # Create SwiftInteropInfo provider for swift_clang_module_aspect
        swift_interop_info = framework_import_support.swift_interop_info_with_dependencies(
            deps = deps,
            module_name = xcframework.bundle_name,
            module_map_imports = [xcframework_library.clang_module_map],
        )
        if swift_interop_info:
            providers.append(swift_interop_info)

    return providers

apple_dynamic_xcframework_import = rule(
    doc = """
This rule encapsulates an already-built XCFramework. Defined by a list of files in a .xcframework
directory. apple_xcframework_import targets need to be added as dependencies to library targets
through the `deps` attribute.
""",
    implementation = _apple_dynamic_xcframework_import_impl,
    attrs = dicts.add(
        rule_attrs.common_tool_attrs(),
        {
            # TODO: b/449684779 - Add an "expected_secure_features" attribute to declare what
            # features are expected to be present in the precompiled framework, so the rules can
            # validate against that and set required entitlements if necessary.
            "codesigned_xcframework_imports": attr.label_list(
                allow_files = True,
                doc = """
Optional List of code signed Files under an .xcframework directory which will be used to generate a
"Signatures" file. The entire contents of the .xcframework must be provided here to get accurate
code signing information, which will be relayed to App Store Connect via the xcarchive or IPA.
""",
            ),
            "deps": attr.label_list(
                doc = """
List of targets that are dependencies of the target being built, which will provide headers and be
linked into that target.
""",
                providers = [
                    [CcInfo],
                    [CcInfo, AppleFrameworkImportInfo],
                ],
                aspects = [swift_clang_module_aspect],
            ),
            "xcframework_imports": attr.label_list(
                allow_empty = False,
                allow_files = True,
                mandatory = True,
                doc = """
List of files under a .xcframework directory which are provided to Apple based targets that depend
on this target.
""",
            ),
        },
    ),
    exec_groups = apple_toolchain_utils.use_apple_exec_group_toolchain(),
    fragments = ["apple", "cpp"],
    provides = [
        AppleFrameworkImportInfo,
        CcInfo,
        AppleDynamicFrameworkInfo,
    ],
    toolchains = swift_common.use_all_toolchains() + use_cpp_toolchain(),
)

apple_static_xcframework_import = rule(
    doc = """
This rule encapsulates an already-built XCFramework with static libraries. Defined by a list of
files in a .xcframework directory. apple_xcframework_import targets need to be added as dependencies
to library targets through the `deps` attribute.
""",
    implementation = _apple_static_xcframework_import_impl,
    attrs = dicts.add(
        rule_attrs.common_tool_attrs(),
        {
            # TODO: b/449684779 - Add an "expected_secure_features" attribute to declare what
            # features are expected to be present in the precompiled framework, so the rules can
            # validate against that and set required entitlements if necessary.
            "alwayslink": attr.bool(
                default = False,
                doc = """
If true, any binary that depends (directly or indirectly) on this XCFramework will link in all the
object files for the XCFramework bundle, even if some contain no symbols referenced by the binary.
This is useful if your code isn't explicitly called by code in the binary; for example, if you rely
on runtime checks for protocol conformances added in extensions in the library but do not directly
reference any other symbols in the object file that adds that conformance.
""",
            ),
            "codesigned_xcframework_imports": attr.label_list(
                allow_files = True,
                doc = """
Optional List of code signed Files under an .xcframework directory which will be used to generate a
"Signatures" file. The entire contents of the .xcframework must be provided here to get accurate
code signing information, which will be relayed to App Store Connect via the xcarchive or IPA.
""",
            ),
            "deps": attr.label_list(
                doc = """
List of targets that are dependencies of the target being built, which will provide headers and be
linked into that target.
""",
                providers = [
                    [CcInfo],
                    [CcInfo, AppleFrameworkImportInfo],
                ],
            ),
            "has_swift": attr.bool(
                doc = """
A boolean indicating if the target has Swift source code. This helps flag XCFrameworks that do not
include Swift interface files.
""",
                default = False,
            ),
            "linkopts": attr.string_list(
                doc = """
A list of strings representing extra flags that should be passed to the linker.
""",
            ),
            "xcframework_imports": attr.label_list(
                allow_empty = False,
                allow_files = True,
                mandatory = True,
                doc = """
List of files under an .xcframework directory which are provided to Apple based targets that depend
on this target.
""",
            ),
        },
    ),
    exec_groups = apple_toolchain_utils.use_apple_exec_group_toolchain(),
    fragments = ["apple", "cpp", "objc"],
    toolchains = swift_common.use_all_toolchains() + use_cpp_toolchain(),
)
