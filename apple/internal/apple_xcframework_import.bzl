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
load("@build_bazel_rules_apple//apple:providers.bzl", "AppleFrameworkImportInfo")
load(
    "@build_bazel_rules_apple//apple/internal:apple_toolchains.bzl",
    "apple_toolchain_utils",
)
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
load("@build_bazel_rules_apple//apple/internal:rule_attrs.bzl", "rule_attrs")
load(
    "@build_bazel_rules_apple//apple/internal/aspects:swift_usage_aspect.bzl",
    "SwiftUsageInfo",
)
load(
    "@build_bazel_rules_swift//swift:swift_clang_module_aspect.bzl",
    "swift_clang_module_aspect",
)
load("@build_bazel_rules_swift//swift:swift_common.bzl", "swift_common")

visibility([
    "//apple/...",
    "//test/...",
])

# Currently, XCFramework bundles can contain Apple frameworks or libraries.
# This defines an _enum_ to identify an imported XCFramework bundle type.
_BUNDLE_TYPE = struct(frameworks = 1, libraries = 2)

# The name of the execution group that houses the Swift toolchain and is used to
# run Swift actions.
_SWIFT_EXEC_GROUP = "swift"

def _classify_xcframework_imports(xcframework_imports):
    """Classifies XCFramework files for later processing.

    Args:
        xcframework_imports: List of File for an imported Apple XCFramework.
    Returns:
        A struct containing xcframework import files information:
            - bundle_name: The XCFramework bundle name infered by filepaths.
            - bundle_type: The XCFramework bundle type (frameworks or libraries).
            - files: The XCFramework import files.
            - files_by_category: Classified XCFramework import files.
            - info_plist: The XCFramework bundle Info.plist file.
    """
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
        fail("XCFramework import files doesn't include an Info.plist file")
    if not bundle_name:
        fail("Could not infer XCFramework bundle name from Info.plist file path")

    if framework_files:
        files = framework_files
        bundle_type = _BUNDLE_TYPE.frameworks
        files_by_category = framework_import_support.classify_framework_imports(files)
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
                str(f.path)
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

    binary_imports = filter_by_library_identifier(files_by_category.binary_imports)
    framework_imports = filter_by_library_identifier(files_by_category.bundling_imports)
    header_imports = filter_by_library_identifier(files_by_category.header_imports)
    module_map_imports = filter_by_library_identifier(files_by_category.module_map_imports)
    swift_module_interfaces = framework_import_support.get_swift_module_files_with_target_triplet(
        swift_module_files = filter_by_library_identifier(
            files_by_category.swift_interface_imports,
        ),
        target_triplet = target_triplet,
    )

    args = actions.args()
    args.add("--library_identifier", library_identifier)
    args.add("--bundle_name", xcframework.bundle_name)
    args.add("--info_plist", xcframework.info_plist.path)

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
    args.add("--output_path", processor_output.path)
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
    if bundle_type == _BUNDLE_TYPE.frameworks:
        library_identifiers = [paths.basename(paths.dirname(f.dirname)) for f in binary_imports]
    elif bundle_type == _BUNDLE_TYPE.libraries:
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

def _apple_dynamic_xcframework_import_impl(ctx):
    """Implementation for the apple_dynamic_framework_import rule."""
    actions = ctx.actions
    apple_fragment = ctx.fragments.apple
    apple_mac_toolchain_info = apple_toolchain_utils.get_mac_toolchain(ctx)
    apple_xplat_toolchain_info = apple_toolchain_utils.get_xplat_toolchain(ctx)
    cc_toolchain = find_cpp_toolchain(ctx)
    deps = ctx.attr.deps
    disabled_features = ctx.disabled_features
    features = ctx.features
    label = ctx.label
    mac_exec_group = apple_toolchain_utils.get_mac_exec_group(ctx)
    xcframework_imports = ctx.files.xcframework_imports
    xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]

    # TODO(b/258492867): Add tree artifacts support when Bazel can handle remote actions with
    # symlinks. See https://github.com/bazelbuild/bazel/issues/16361.
    target_triplet = cc_toolchain_info_support.get_apple_clang_triplet(cc_toolchain)
    has_versioned_framework_files = framework_import_support.has_versioned_framework_files(
        xcframework_imports,
    )
    tree_artifact_enabled = (
        apple_xplat_toolchain_info.build_settings.use_tree_artifacts_outputs or
        is_experimental_tree_artifact_enabled(config_vars = ctx.var)
    )
    if target_triplet.os == "macos" and has_versioned_framework_files and tree_artifact_enabled:
        fail("The apple_dynamic_xcframework_import rule does not yet support versioned " +
             "frameworks with the experimental tree artifact feature/build setting. " +
             "Please ensure that the `apple.experimental.tree_artifact_outputs` variable is not " +
             "set to 1 on the command line or in your active build configuration.")

    xcframework = _classify_xcframework_imports(xcframework_imports)
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

    # Create AppleFrameworkImportInfo provider
    apple_framework_import_info = framework_import_support.framework_import_info_with_dependencies(
        build_archs = [target_triplet.architecture],
        deps = deps,
        framework_imports = [xcframework_library.binary] +
                            xcframework_library.framework_imports,
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
    apple_dynamic_framework_info = apple_common.new_dynamic_framework_provider(
        cc_info = cc_info,
    )
    providers.append(apple_dynamic_framework_info)

    if xcframework_library.swift_module_interface:
        # Create SwiftInfo provider
        swift_toolchain = swift_common.get_toolchain(ctx, exec_group = _SWIFT_EXEC_GROUP)
        providers.append(
            framework_import_support.swift_info_from_module_interface(
                actions = actions,
                ctx = ctx,
                deps = deps,
                disabled_features = disabled_features,
                features = features,
                module_name = xcframework.bundle_name,
                swift_toolchain = swift_toolchain,
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
    cc_toolchain = find_cpp_toolchain(ctx)
    deps = ctx.attr.deps
    disabled_features = ctx.disabled_features
    features = ctx.features
    has_swift = ctx.attr.has_swift
    label = ctx.label
    linkopts = ctx.attr.linkopts
    mac_exec_group = apple_toolchain_utils.get_mac_exec_group(ctx)
    xcframework_imports = ctx.files.xcframework_imports
    xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]

    xcframework = _classify_xcframework_imports(xcframework_imports)
    target_triplet = cc_toolchain_info_support.get_apple_clang_triplet(cc_toolchain)

    if xcframework.bundle_type == _BUNDLE_TYPE.frameworks:
        fail("Importing XCFrameworks with static frameworks is not supported.")

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
        DefaultInfo(
            files = depset(xcframework_imports),
        ),
        OutputGroupInfo(
            _validation = depset([xcframework_library.processor_output]),
        ),
    ]

    # Create AppleFrameworkImportInfo provider
    apple_framework_import_info = framework_import_support.framework_import_info_with_dependencies(
        build_archs = [apple_fragment.single_arch_cpu],
        deps = deps,
    )
    providers.append(apple_framework_import_info)

    additional_cc_infos = []
    if xcframework.files_by_category.swift_interface_imports or has_swift:
        swift_toolchain = swift_common.get_toolchain(ctx, exec_group = _SWIFT_EXEC_GROUP)
        providers.append(SwiftUsageInfo())

        # The Swift toolchain propagates Swift-specific linker flags (e.g.,
        # library/framework search paths) as an implicit dependency. In the
        # rare case that a binary has a Swift framework import dependency but
        # no other Swift dependencies, make sure we pick those up so that it
        # links to the standard libraries correctly.
        additional_cc_infos.extend(swift_toolchain.implicit_deps_providers.cc_infos)

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
        swift_toolchain = swift_common.get_toolchain(ctx, exec_group = _SWIFT_EXEC_GROUP)
        providers.append(
            framework_import_support.swift_info_from_module_interface(
                actions = actions,
                ctx = ctx,
                deps = deps,
                disabled_features = disabled_features,
                features = features,
                module_name = xcframework.bundle_name,
                swift_toolchain = swift_toolchain,
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
            "xcframework_imports": attr.label_list(
                allow_empty = False,
                allow_files = True,
                mandatory = True,
                doc = """
List of files under a .xcframework directory which are provided to Apple based targets that depend
on this target.
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
            "_cc_toolchain": attr.label(
                default = "@bazel_tools//tools/cpp:current_cc_toolchain",
                doc = "The C++ toolchain to use.",
            ),
            # TODO(b/301253335): Enable AEGs and switch from `swift` exec_group to swift `toolchain` param.
            "_use_auto_exec_groups": attr.bool(default = False),
        },
    ),
    exec_groups = dicts.add(
        {
            _SWIFT_EXEC_GROUP: exec_group(
                toolchains = swift_common.use_toolchain(),
            ),
        },
        apple_toolchain_utils.use_apple_exec_group_toolchain(),
    ),
    fragments = ["apple", "cpp"],
    provides = [
        AppleFrameworkImportInfo,
        CcInfo,
        apple_common.AppleDynamicFramework,
    ],
    toolchains = use_cpp_toolchain(),
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
                mandatory = False,
                default = False,
            ),
            "linkopts": attr.string_list(
                mandatory = False,
                doc = """
A list of strings representing extra flags that should be passed to the linker.
""",
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
            "_cc_toolchain": attr.label(
                default = "@bazel_tools//tools/cpp:current_cc_toolchain",
                doc = "The C++ toolchain to use.",
            ),
            # TODO(b/301253335): Enable AEGs and add `toolchain` param once this rule starts using toolchain resolution.
            "_use_auto_exec_groups": attr.bool(default = False),
        },
    ),
    exec_groups = dicts.add(
        {
            _SWIFT_EXEC_GROUP: exec_group(
                toolchains = swift_common.use_toolchain(),
            ),
        },
        apple_toolchain_utils.use_apple_exec_group_toolchain(),
    ),
    fragments = ["apple", "cpp", "objc"],
    toolchains = use_cpp_toolchain(),
)
