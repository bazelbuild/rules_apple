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

"""Support methods for Apple framework import rules."""

load("@build_bazel_rules_apple//apple:providers.bzl", "AppleFrameworkImportInfo")
load("@build_bazel_rules_apple//apple/internal/utils:defines.bzl", "defines")
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "SwiftInfo",
    "swift_common",
)
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")

def _cc_info_with_dependencies(
        *,
        actions,
        additional_cc_infos = [],
        ctx,
        deps,
        disabled_features,
        features,
        framework_includes,
        grep_includes,
        header_imports,
        label,
        includes = [],
        is_framework = True):
    """Returns a new CcInfo which includes transitive Cc dependencies.

    Args:
        actions: The actions provider from `ctx.actions`.
        additional_cc_infos: List of additinal CcInfo providers to use for a merged compilation contexts.
        ctx: The Starlark context for a rule target being built.
        deps: List of dependencies for a given target to retrieve transitive CcInfo providers.
        disabled_features: List of features to be disabled for cc_common.compile
        features: List of features to be enabled for cc_common.compile.
        framework_includes: List of Apple framework search paths.
        grep_includes: File reference to grep_includes binary required by cc_common APIs.
        header_imports: List of imported header files.
        label: Label of the target being built.
        includes: List of include search paths.
        is_framework: Whether the target is a framework vs library.
    Returns:
        CcInfo provider.
    """
    all_cc_infos = [dep[CcInfo] for dep in deps] + additional_cc_infos
    dep_compilation_contexts = [cc_info.compilation_context for cc_info in all_cc_infos]

    cc_toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = features + ["lang_objc"],  # b/210775356
        unsupported_features = disabled_features,
    )

    (compilation_context, _compilation_outputs) = cc_common.compile(
        name = label.name,
        actions = actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        public_hdrs = header_imports,
        includes = includes,
        framework_includes = framework_includes if is_framework else [],
        compilation_contexts = dep_compilation_contexts,
        language = "objc",
        grep_includes = grep_includes,
    )

    dep_linking_contexts = [cc_info.linking_context for cc_info in all_cc_infos]
    linking_context = cc_common.merge_linking_contexts(
        linking_contexts = dep_linking_contexts,
    )

    return CcInfo(
        compilation_context = compilation_context,
        linking_context = linking_context,
    )

def _classify_framework_imports(config_vars, framework_imports):
    """Classify a list of framework files.

    Args:
        config_vars: A dictionary (String to String) of configuration variables. Can be from ctx.var.
        framework_imports: List of File for an imported Apple framework.
    Returns:
        A struct containing classified framework import files by categories:
            - bundle_name: The framework bundle name infered by filepaths.
            - binary_imports: Apple framework binary imports.
            - bundling_imports: Apple framework bundle imports.
            - header_imports: Apple framework header imports.
            - module_map_imports: Apple framework modulemap imports.
            - swift_module_imports: Apple framework swiftmodule imports.
    """
    bundle_name = None
    binary_imports = []
    bundling_imports = []
    header_imports = []
    module_map_imports = []
    swift_module_imports = []
    for file in framework_imports:
        # Directory matching
        parent_dir_name = paths.basename(file.dirname)
        is_bundle_root_file = parent_dir_name.endswith(".framework")
        if is_bundle_root_file:
            bundle_name, _ = paths.split_extension(parent_dir_name)
            if file.basename == bundle_name:
                binary_imports.append(file)
                continue

        # Extension matching
        file_extension = file.extension
        if file_extension == "h":
            header_imports.append(file)
            continue
        if file_extension == "modulemap":
            # With the flip of `--incompatible_objc_framework_cleanup`, the
            # `objc_library` implementation in Bazel no longer passes module
            # maps as inputs to the compile actions, so that `@import`
            # statements for user-provided framework no longer work in a
            # sandbox. This trap door allows users to continue using `@import`
            # statements for imported framework by adding module map to
            # header_imports so that they are included in Obj-C compilation but
            # they aren't processed in any way.
            if defines.bool_value(
                config_vars = config_vars,
                define_name = "apple.incompatible.objc_framework_propagate_modulemap",
                default = False,
            ):
                header_imports.append(file)
            module_map_imports.append(file)
            continue
        if file_extension in ["swiftmodule", "swiftinterface"]:
            # Add Swift's module files to header_imports so
            # that they are correctly included in the build
            # by Bazel but they aren't processed in any way
            header_imports.append(file)
            swift_module_imports.append(file)
            continue
        if file_extension in ["swiftdoc", "swiftsourceinfo"]:
            # Ignore swiftdoc files, they don't matter in the build, only for IDEs
            continue

        # Path matching
        if "Headers" in file.short_path:
            header_imports.append(file)
            continue

        # Unknown file type, sending tu bundling (i.e. resources)
        bundling_imports.append(file)

    return struct(
        bundle_name = bundle_name,
        binary_imports = binary_imports,
        bundling_imports = bundling_imports,
        header_imports = header_imports,
        module_map_imports = module_map_imports,
        swift_module_imports = swift_module_imports,
    )

def _framework_import_info_with_dependencies(
        *,
        build_archs,
        deps,
        debug_info_binaries,
        dsyms,
        framework_imports = []):
    """Returns AppleFrameworkImportInfo containing transitive framework imports and build archs.

    Args:
        build_archs: List of supported architectures for the imported framework.
        deps: List of transitive dependencies of the current target.
        debug_info_binaries: List of debug info binaries for the imported Framework.
        dsyms: List of dSYM files for the imported Framework.
        framework_imports: List of files to bundle for the imported framework.
    Returns:
        AppleFrameworkImportInfo provider.
    """
    transitive_framework_imports = [
        dep[AppleFrameworkImportInfo].framework_imports
        for dep in deps
        if (AppleFrameworkImportInfo in dep and
            hasattr(dep[AppleFrameworkImportInfo], "framework_imports"))
    ]

    return AppleFrameworkImportInfo(
        build_archs = depset(build_archs),
        debug_info_binaries = depset(debug_info_binaries),
        dsym_imports = depset(dsyms),
        framework_imports = depset(
            framework_imports,
            transitive = transitive_framework_imports,
        ),
    )

def _objc_provider_with_dependencies(
        *,
        additional_objc_provider_fields = {},
        additional_objc_providers = [],
        alwayslink = False,
        dynamic_framework_file = None,
        module_map,
        sdk_dylib = None,
        sdk_framework = None,
        static_framework_file = None,
        weak_sdk_framework = None):
    """Returns a new Objc provider which includes transitive Objc dependencies.

    Args:
        additional_objc_provider_fields: Additional fields to set for the Objc provider constructor.
        additional_objc_providers: Additional Objc providers to merge with this target provider.
        alwayslink: Boolean to indicate if force_load_library should be set with the static
            framework file.
        dynamic_framework_file: File referencing a framework dynamic library.
        module_map: File referencing imported framework module map.
        sdk_dylib: List of Apple SDK dylibs to link. Defaults to None.
        sdk_framework: List of Apple SDK frameworks to link. Defaults to None.
        static_framework_file: File referencing a framework static library.
        weak_sdk_framework: List of Apple SDK frameworks to weakly link. Defaults to None.
    Returns:
        apple_common.Objc provider
    """
    objc_provider_fields = {}
    objc_provider_fields["providers"] = additional_objc_providers

    if dynamic_framework_file:
        objc_provider_fields["dynamic_framework_file"] = dynamic_framework_file

    if static_framework_file:
        objc_provider_fields["static_framework_file"] = static_framework_file

        if alwayslink:
            objc_provider_fields["force_load_library"] = depset(static_framework_file)

    if module_map:
        objc_provider_fields["module_map"] = depset(module_map)
    if sdk_dylib:
        objc_provider_fields["sdk_dylib"] = depset(sdk_dylib)
    if sdk_framework:
        objc_provider_fields["sdk_framework"] = depset(sdk_framework)
    if weak_sdk_framework:
        objc_provider_fields["weak_sdk_framework"] = depset(weak_sdk_framework)

    objc_provider_fields.update(**additional_objc_provider_fields)
    return apple_common.new_objc_provider(**objc_provider_fields)

def _swift_interop_info_with_dependencies(deps, module_name, module_map_imports):
    """Return a Swift interop provider for the framework if it has a module map."""
    if not module_map_imports:
        return None

    # Assume that there is only a single module map file (the legacy
    # implementation that read from the Objc provider made the same
    # assumption).
    return swift_common.create_swift_interop_info(
        module_map = module_map_imports[0],
        module_name = module_name,
        swift_infos = [dep[SwiftInfo] for dep in deps if SwiftInfo in dep],
    )

framework_import_support = struct(
    cc_info_with_dependencies = _cc_info_with_dependencies,
    classify_framework_imports = _classify_framework_imports,
    framework_import_info_with_dependencies = _framework_import_info_with_dependencies,
    objc_provider_with_dependencies = _objc_provider_with_dependencies,
    swift_interop_info_with_dependencies = _swift_interop_info_with_dependencies,
)
