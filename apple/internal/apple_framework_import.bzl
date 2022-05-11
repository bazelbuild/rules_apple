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

"""Implementation of framework import rules."""

load(
    "@bazel_skylib//lib:collections.bzl",
    "collections",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
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
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleFrameworkImportInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:resources.bzl",
    "resources",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:swift_usage_aspect.bzl",
    "SwiftUsageInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_factory.bzl",
    "rule_factory",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "group_files_by_directory",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "SwiftInfo",
    "swift_clang_module_aspect",
    "swift_common",
)
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")

def _swiftmodule_for_cpu(swiftmodule_files, cpu):
    """Select the cpu specific swiftmodule."""

    # The paths will be of the following format:
    #   ABC.framework/Modules/ABC.swiftmodule/<arch>.swiftmodule
    # Where <arch> will be a common arch like x86_64, arm64, etc.
    named_files = {f.basename: f for f in swiftmodule_files}

    module = named_files.get("{}.swiftmodule".format(cpu))
    if not module and cpu == "armv7":
        module = named_files.get("arm.swiftmodule")

    return module

def _classify_framework_imports(framework_imports):
    """Classify a list of framework files.

    Args:
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
            module_map_imports.append(file)
            continue
        if file_extension in ["swiftmodule", "swiftinterface"]:
            # Add Swift's module files to header_imports so
            # that they are correctly included in the build
            # by Bazel but they aren't processed in any way
            header_imports.append(file)
            swift_module_imports.append(file)
            continue
        if file_extension == "swiftdoc":
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

def _grouped_framework_files(framework_imports):
    """Returns a dictionary of each framework's imports, grouped by path to the .framework root."""
    framework_groups = group_files_by_directory(
        framework_imports,
        ["framework"],
        attr = "framework_imports",
    )

    # Only check for unique basenames of these keys, since it's possible to
    # have targets that glob files from different locations but with the same
    # `.framework` name, causing them to be merged into the same framework
    # during bundling.
    unique_frameworks = collections.uniq(
        [paths.basename(path) for path in framework_groups.keys()],
    )
    if len(unique_frameworks) > 1:
        fail("A framework import target may only include files for a " +
             "single '.framework' bundle.", attr = "framework_imports")

    return framework_groups

def _objc_provider_with_dependencies(deps, objc_provider_fields, additional_objc_infos = []):
    """Returns a new Objc provider which includes transitive Objc dependencies."""
    objc_provider_fields["providers"] = [
        dep[apple_common.Objc]
        for dep in deps
    ] + additional_objc_infos
    return apple_common.new_objc_provider(**objc_provider_fields)

def _cc_info_with_dependencies(
        ctx,
        name,
        deps,
        grep_includes,
        header_imports,
        additional_cc_infos = []):
    """Returns a new CcInfo which includes transitive Cc dependencies."""

    all_cc_infos = [dep[CcInfo] for dep in deps] + additional_cc_infos
    dep_compilation_contexts = [cc_info.compilation_context for cc_info in all_cc_infos]
    cc_toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features + ["lang_objc"],  # b/210775356
        unsupported_features = ctx.disabled_features,
    )
    (compilation_context, _compilation_outputs) = cc_common.compile(
        name = name,
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        public_hdrs = header_imports,
        framework_includes = _framework_search_paths(header_imports),
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

def _transitive_framework_imports(deps):
    """Returns the list of transitive framework imports for the given deps."""
    return [
        dep[AppleFrameworkImportInfo].framework_imports
        for dep in deps
        if (AppleFrameworkImportInfo in dep and
            hasattr(dep[AppleFrameworkImportInfo], "framework_imports"))
    ]

def _framework_import_info(transitive_sets, arch_found):
    """Returns AppleFrameworkImportInfo containing transitive framework imports and build archs."""
    provider_fields = {}
    if transitive_sets:
        provider_fields["framework_imports"] = depset(transitive = transitive_sets)
    provider_fields["build_archs"] = depset([arch_found])
    return AppleFrameworkImportInfo(**provider_fields)

def _is_debugging(compilation_mode):
    """Returns `True` if the current compilation mode produces debug info.

    rules_apple specific implementation of rules_swift's `is_debugging`, which
    is not currently exported.

    See: https://github.com/bazelbuild/rules_swift/blob/44146fccd9e56fe1dc650a4e0f21420a503d301c/swift/internal/api.bzl#L315-L326
    """
    return compilation_mode in ("dbg", "fastbuild")

def _ensure_swiftmodule_is_embedded(swiftmodule):
    """Ensures that a `.swiftmodule` file is embedded in a library or binary.

    rules_apple specific implementation of rules_swift's
    `ensure_swiftmodule_is_embedded`, which is not currently exported.

    See: https://github.com/bazelbuild/rules_swift/blob/e78ceb37c401a9bf9e551a6accd1df7d864688d5/swift/internal/debugging.bzl#L20-L47
    """
    return dict(
        linkopt = depset(["-Wl,-add_ast_path,{}".format(swiftmodule.path)]),
        link_inputs = depset([swiftmodule]),
    )

def _framework_objc_provider_fields(
        framework_binary_field,
        module_map_imports,
        framework_binaries):
    """Return an objc_provider initializer dictionary with information for a given framework."""

    objc_provider_fields = {}
    if module_map_imports:
        objc_provider_fields["module_map"] = depset(module_map_imports)

    if framework_binaries:
        objc_provider_fields[framework_binary_field] = depset(framework_binaries)

    return objc_provider_fields

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

def _framework_search_paths(header_imports):
    """Return the list framework search paths for the headers_imports."""
    if header_imports:
        header_groups = _grouped_framework_files(header_imports)

        search_paths = sets.make()
        for path in header_groups.keys():
            sets.insert(search_paths, paths.dirname(path))
        return sets.to_list(search_paths)
    else:
        return []

def _apple_dynamic_framework_import_impl(ctx):
    """Implementation for the apple_dynamic_framework_import rule."""
    providers = []

    deps = ctx.attr.deps
    framework_imports = ctx.files.framework_imports
    framework_imports_by_category = _classify_framework_imports(framework_imports)

    transitive_sets = _transitive_framework_imports(deps)
    transitive_sets.append(depset(framework_imports_by_category.binary_imports))
    if framework_imports_by_category.bundling_imports:
        transitive_sets.append(depset(framework_imports_by_category.bundling_imports))
    providers.append(_framework_import_info(transitive_sets, ctx.fragments.apple.single_arch_cpu))

    framework_groups = _grouped_framework_files(framework_imports)
    framework_dirs_set = depset(framework_groups.keys())
    objc_provider_fields = _framework_objc_provider_fields(
        "dynamic_framework_file",
        framework_imports_by_category.module_map_imports,
        framework_imports_by_category.binary_imports,
    )

    objc_provider = _objc_provider_with_dependencies(deps, objc_provider_fields)
    cc_info = _cc_info_with_dependencies(
        ctx,
        ctx.label.name,
        ctx.attr.deps,
        ctx.file._grep_includes,
        framework_imports_by_category.header_imports,
    )
    providers.append(objc_provider)
    providers.append(cc_info)
    providers.append(apple_common.new_dynamic_framework_provider(
        objc = objc_provider,
        framework_dirs = framework_dirs_set,
        framework_files = depset(framework_imports),
    ))

    # For now, Swift interop is restricted only to a Clang module map inside
    # the framework.
    swift_interop_info = _swift_interop_info_with_dependencies(
        deps = deps,
        module_name = framework_imports_by_category.bundle_name,
        module_map_imports = framework_imports_by_category.module_map_imports,
    )
    if swift_interop_info:
        providers.append(swift_interop_info)

    return providers

def _apple_static_framework_import_impl(ctx):
    """Implementation for the apple_static_framework_import rule."""
    providers = []

    deps = ctx.attr.deps
    framework_imports = ctx.files.framework_imports
    framework_imports_by_category = _classify_framework_imports(framework_imports)

    transitive_sets = _transitive_framework_imports(deps)
    providers.append(_framework_import_info(transitive_sets, ctx.fragments.apple.single_arch_cpu))

    objc_provider_fields = _framework_objc_provider_fields(
        "static_framework_file",
        framework_imports_by_category.module_map_imports,
        framework_imports_by_category.binary_imports,
    )

    if ctx.attr.alwayslink:
        if not framework_imports_by_category.binary_imports:
            fail("ERROR: There has to be a binary file in the imported framework.")
        objc_provider_fields["force_load_library"] = depset(
            framework_imports_by_category.binary_imports,
        )
    if ctx.attr.sdk_dylibs:
        objc_provider_fields["sdk_dylib"] = depset(ctx.attr.sdk_dylibs)
    if ctx.attr.sdk_frameworks:
        objc_provider_fields["sdk_framework"] = depset(ctx.attr.sdk_frameworks)
    if ctx.attr.weak_sdk_frameworks:
        objc_provider_fields["weak_sdk_framework"] = depset(ctx.attr.weak_sdk_frameworks)

    additional_cc_infos = []
    additional_objc_infos = []
    if framework_imports_by_category.swift_module_imports:
        toolchain = swift_common.get_toolchain(ctx)
        providers.append(SwiftUsageInfo())

        # The Swift toolchain propagates Swift-specific linker flags (e.g.,
        # library/framework search paths) as an implicit dependency. In the
        # rare case that a binary has a Swift framework import dependency but
        # no other Swift dependencies, make sure we pick those up so that it
        # links to the standard libraries correctly.
        additional_objc_infos.extend(toolchain.implicit_deps_providers.objc_infos)
        additional_cc_infos.extend(toolchain.implicit_deps_providers.cc_infos)

        if _is_debugging(compilation_mode = ctx.var["COMPILATION_MODE"]):
            cpu = ctx.fragments.apple.single_arch_cpu
            swiftmodule = _swiftmodule_for_cpu(
                framework_imports_by_category.swift_module_imports,
                cpu,
            )
            if not swiftmodule:
                fail("ERROR: Missing imported swiftmodule for {}".format(cpu))
            objc_provider_fields.update(_ensure_swiftmodule_is_embedded(swiftmodule))

    providers.append(
        _objc_provider_with_dependencies(deps, objc_provider_fields, additional_objc_infos),
    )
    providers.append(
        _cc_info_with_dependencies(
            ctx,
            ctx.label.name,
            ctx.attr.deps,
            ctx.file._grep_includes,
            framework_imports_by_category.header_imports,
            additional_cc_infos,
        ),
    )

    # For now, Swift interop is restricted only to a Clang module map inside
    # the framework.
    swift_interop_info = _swift_interop_info_with_dependencies(
        deps = deps,
        module_name = framework_imports_by_category.bundle_name,
        module_map_imports = framework_imports_by_category.module_map_imports,
    )
    if swift_interop_info:
        providers.append(swift_interop_info)

    bundle_files = [x for x in framework_imports if ".bundle/" in x.short_path]
    if bundle_files:
        parent_dir_param = partial.make(
            resources.bundle_relative_parent_dir,
            extension = "bundle",
        )
        resource_provider = resources.bucketize_typed(
            bundle_files,
            owner = str(ctx.label),
            bucket_type = "unprocessed",
            parent_dir_param = parent_dir_param,
        )
        providers.append(resource_provider)

    return providers

apple_dynamic_framework_import = rule(
    implementation = _apple_dynamic_framework_import_impl,
    fragments = ["apple", "cpp"],
    attrs = dicts.add(
        rule_factory.common_tool_attributes,
        {
            "framework_imports": attr.label_list(
                allow_empty = False,
                allow_files = True,
                mandatory = True,
                doc = """
The list of files under a .framework directory which are provided to Apple based targets that depend
on this target.
""",
            ),
            "deps": attr.label_list(
                aspects = [swift_clang_module_aspect],
                doc = """
A list of targets that are dependencies of the target being built, which will be linked into that
target.
""",
                providers = [
                    [apple_common.Objc, CcInfo],
                    [apple_common.Objc, CcInfo, AppleFrameworkImportInfo],
                ],
            ),
            "_cc_toolchain": attr.label(
                default = "@bazel_tools//tools/cpp:current_cc_toolchain",
                doc = "The C++ toolchain to use.",
            ),
        },
    ),
    doc = """
This rule encapsulates an already-built dynamic framework. It is defined by a list of files in
exactly one .framework directory. apple_dynamic_framework_import targets need to be added to library
targets through the `deps` attribute.
""",
)

apple_static_framework_import = rule(
    implementation = _apple_static_framework_import_impl,
    fragments = ["apple", "cpp"],
    attrs = dicts.add(
        rule_factory.common_tool_attributes,
        swift_common.toolchain_attrs(),
        {
            "framework_imports": attr.label_list(
                allow_empty = False,
                allow_files = True,
                mandatory = True,
                doc = """
The list of files under a .framework directory which are provided to Apple based targets that depend
on this target.
""",
            ),
            "sdk_dylibs": attr.string_list(
                doc = """
Names of SDK .dylib libraries to link with. For instance, `libz` or `libarchive`. `libc++` is
included automatically if the binary has any C++ or Objective-C++ sources in its dependency tree.
When linking a binary, all libraries named in that binary's transitive dependency graph are used.
""",
            ),
            "sdk_frameworks": attr.string_list(
                doc = """
Names of SDK frameworks to link with (e.g. `AddressBook`, `QuartzCore`). `UIKit` and `Foundation`
are always included when building for the iOS, tvOS and watchOS platforms. For macOS, only
`Foundation` is always included. When linking a top level binary, all SDK frameworks listed in that
binary's transitive dependency graph are linked.
""",
            ),
            "weak_sdk_frameworks": attr.string_list(
                doc = """
Names of SDK frameworks to weakly link with. For instance, `MediaAccessibility`. In difference to
regularly linked SDK frameworks, symbols from weakly linked frameworks do not cause an error if they
are not present at runtime.
""",
            ),
            "deps": attr.label_list(
                aspects = [swift_clang_module_aspect],
                doc = """
A list of targets that are dependencies of the target being built, which will provide headers and be
linked into that target.
""",
                providers = [
                    [apple_common.Objc, CcInfo],
                    [apple_common.Objc, CcInfo, AppleFrameworkImportInfo],
                ],
            ),
            "alwayslink": attr.bool(
                default = False,
                doc = """
If true, any binary that depends (directly or indirectly) on this framework will link in all the
object files for the framework file, even if some contain no symbols referenced by the binary. This
is useful if your code isn't explicitly called by code in the binary; for example, if you rely on
runtime checks for protocol conformances added in extensions in the library but do not directly
reference any other symbols in the object file that adds that conformance.
""",
            ),
            "_cc_toolchain": attr.label(
                default = "@bazel_tools//tools/cpp:current_cc_toolchain",
                doc = "The C++ toolchain to use.",
            ),
        },
    ),
    doc = """
This rule encapsulates an already-built static framework. It is defined by a list of files in a
.framework directory. apple_static_framework_import targets need to be added to library targets
through the `deps` attribute.
""",
)
