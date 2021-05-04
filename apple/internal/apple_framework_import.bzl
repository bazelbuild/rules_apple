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
    "@build_bazel_rules_apple//apple/internal:resources.bzl",
    "resources",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:defines.bzl",
    "defines",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "group_files_by_directory",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleFrameworkImportInfo",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "SwiftInfo",
    "SwiftToolchainInfo",
    "SwiftUsageInfo",
    "swift_common",
)

def _is_swiftmodule(path):
    """Predicate to identify Swift modules/interfaces."""
    return path.endswith((".swiftmodule", ".swiftinterface"))

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

def _classify_framework_imports(config_vars, framework_imports):
    """Classify a list of framework files into bundling, header, or module_map."""

    bundling_imports = []
    header_imports = []
    module_map_imports = []
    for file in framework_imports:
        file_short_path = file.short_path
        if file_short_path.endswith(".h"):
            header_imports.append(file)
            continue
        if file_short_path.endswith(".modulemap"):
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
        if "Headers/" in file_short_path:
            # This matches /Headers/ and /PrivateHeaders/
            header_imports.append(file)
            continue
        if _is_swiftmodule(file_short_path):
            # Add Swift's module files to header_imports so that they are correctly included in the build
            # by Bazel but they aren't processed in any way
            header_imports.append(file)
            continue
        if file_short_path.endswith((".swiftdoc", ".swiftsourceinfo")):
            # Ignore swiftdoc files, they don't matter in the build, only for IDEs
            continue
        bundling_imports.append(file)

    return bundling_imports, header_imports, module_map_imports

def _all_framework_binaries(frameworks_groups):
    """Returns a list of Files of all imported binaries."""
    binaries = []
    for framework_dir, framework_imports in frameworks_groups.items():
        binary = _get_framework_binary_file(framework_dir, framework_imports.to_list())
        if binary != None:
            binaries.append(binary)

    return binaries

def _get_framework_binary_file(framework_dir, framework_imports):
    """Returns the File that is the framework's binary."""
    framework_name = paths.split_extension(paths.basename(framework_dir))[0]
    framework_path = paths.join(framework_dir, framework_name)
    for framework_import in framework_imports:
        if framework_import.path == framework_path:
            return framework_import

    return None

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

def _objc_provider_with_dependencies(ctx, objc_provider_fields):
    """Returns a new Objc provider which includes transitive Objc dependencies."""
    objc_provider_fields["providers"] = [dep[apple_common.Objc] for dep in ctx.attr.deps]
    return apple_common.new_objc_provider(**objc_provider_fields)

def _cc_info_with_dependencies(ctx, header_imports):
    """Returns a new CcInfo which includes transitive Cc dependencies."""
    cc_info = CcInfo(
        compilation_context = cc_common.create_compilation_context(
            headers = depset(header_imports),
            framework_includes = depset(_framework_search_paths(header_imports)),
        ),
    )
    dep_cc_infos = [dep[CcInfo] for dep in ctx.attr.deps]
    return cc_common.merge_cc_infos(
        cc_infos = [cc_info] + dep_cc_infos,
    )

def _transitive_framework_imports(deps):
    """Returns the list of transitive framework imports for the given deps."""
    return [
        dep[AppleFrameworkImportInfo].framework_imports
        for dep in deps
        if (AppleFrameworkImportInfo in dep and
            hasattr(dep[AppleFrameworkImportInfo], "framework_imports"))
    ]

def _framework_import_info(transitive_sets, arch_found, dsyms = []):
    """Returns AppleFrameworkImportInfo containing transitive framework imports and build archs."""
    provider_fields = {}
    if transitive_sets:
        provider_fields["framework_imports"] = depset(transitive = transitive_sets)
    provider_fields["build_archs"] = depset([arch_found])
    provider_fields["dsym_imports"] = depset(dsyms)
    return AppleFrameworkImportInfo(**provider_fields)

def _is_debugging(ctx):
    """Returns `True` if the current compilation mode produces debug info.

    rules_apple specific implementation of rules_swift's `is_debugging`, which
    is not currently exported.

    See: https://github.com/bazelbuild/rules_swift/blob/44146fccd9e56fe1dc650a4e0f21420a503d301c/swift/internal/api.bzl#L315-L326
    """
    return ctx.var["COMPILATION_MODE"] in ("dbg", "fastbuild")

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
        header_imports,
        module_map_imports,
        framework_binaries):
    """Return an objc_provider initializer dictionary with information for a given framework."""

    objc_provider_fields = {}
    if header_imports:
        objc_provider_fields["header"] = depset(header_imports)

    if module_map_imports:
        objc_provider_fields["module_map"] = depset(module_map_imports)

    if framework_binaries:
        objc_provider_fields[framework_binary_field] = depset(framework_binaries)

    return objc_provider_fields

def _swift_interop_info_with_dependencies(ctx, framework_groups, module_map_imports):
    """Return a Swift interop provider for the framework if it has a module map."""

    # TODO: Re-enable this once https://github.com/bazelbuild/rules_apple/issues/1147 is fixed
    if True:
        return None

    if not module_map_imports:
        return None

    # We can just take the first key because the rule implementation guarantees
    # that we only have files for a single framework.
    framework_dir = framework_groups.keys()[0]
    framework_name = paths.split_extension(paths.basename(framework_dir))[0]

    # Likewise, assume that there is only a single module map file (the
    # legacy implementation that read from the Objc provider made the same
    # assumption).
    return swift_common.create_swift_interop_info(
        module_map = module_map_imports[0],
        module_name = framework_name,
        swift_infos = [dep[SwiftInfo] for dep in ctx.attr.deps if SwiftInfo in dep],
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

    framework_imports = ctx.files.framework_imports
    bundling_imports, header_imports, module_map_imports = (
        _classify_framework_imports(ctx.var, framework_imports)
    )

    transitive_sets = _transitive_framework_imports(ctx.attr.deps)
    if bundling_imports:
        transitive_sets.append(depset(bundling_imports))
    providers.append(
        _framework_import_info(
            transitive_sets,
            ctx.fragments.apple.single_arch_cpu,
            ctx.files.dsym_imports,
        ),
    )

    framework_groups = _grouped_framework_files(framework_imports)
    framework_dirs_set = depset(framework_groups.keys())
    objc_provider_fields = _framework_objc_provider_fields(
        "dynamic_framework_file",
        header_imports,
        module_map_imports,
        [] if ctx.attr.bundle_only else _all_framework_binaries(framework_groups),
    )

    objc_provider = _objc_provider_with_dependencies(ctx, objc_provider_fields)
    cc_info = _cc_info_with_dependencies(ctx, header_imports)
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
        ctx = ctx,
        framework_groups = framework_groups,
        module_map_imports = module_map_imports,
    )
    if swift_interop_info:
        providers.append(swift_interop_info)

    return providers

def _apple_static_framework_import_impl(ctx):
    """Implementation for the apple_static_framework_import rule."""
    providers = []

    framework_imports = ctx.files.framework_imports
    _, header_imports, module_map_imports = _classify_framework_imports(ctx.var, framework_imports)

    transitive_sets = _transitive_framework_imports(ctx.attr.deps)
    providers.append(_framework_import_info(transitive_sets, ctx.fragments.apple.single_arch_cpu))

    framework_groups = _grouped_framework_files(framework_imports)
    framework_binaries = _all_framework_binaries(framework_groups)

    objc_provider_fields = _framework_objc_provider_fields(
        "static_framework_file",
        header_imports,
        module_map_imports,
        framework_binaries,
    )

    if ctx.attr.alwayslink:
        if not framework_binaries:
            fail("ERROR: There has to be a binary file in the imported framework.")
        objc_provider_fields["force_load_library"] = depset(framework_binaries)
    if ctx.attr.sdk_dylibs:
        objc_provider_fields["sdk_dylib"] = depset(ctx.attr.sdk_dylibs)
    if ctx.attr.sdk_frameworks:
        objc_provider_fields["sdk_framework"] = depset(ctx.attr.sdk_frameworks)
    if ctx.attr.weak_sdk_frameworks:
        objc_provider_fields["weak_sdk_framework"] = depset(ctx.attr.weak_sdk_frameworks)

    swiftmodule_imports = [
        header
        for header in header_imports
        if _is_swiftmodule(header.basename)
    ]

    if swiftmodule_imports:
        toolchain = ctx.attr._toolchain[SwiftToolchainInfo]
        providers.append(SwiftUsageInfo(toolchain = toolchain))

        if _is_debugging(ctx):
            cpu = ctx.fragments.apple.single_arch_cpu
            swiftmodule = _swiftmodule_for_cpu(swiftmodule_imports, cpu)
            if swiftmodule:
                objc_provider_fields.update(_ensure_swiftmodule_is_embedded(swiftmodule))

    providers.append(_objc_provider_with_dependencies(ctx, objc_provider_fields))
    providers.append(_cc_info_with_dependencies(ctx, header_imports))

    # For now, Swift interop is restricted only to a Clang module map inside
    # the framework.
    swift_interop_info = _swift_interop_info_with_dependencies(
        ctx = ctx,
        framework_groups = framework_groups,
        module_map_imports = module_map_imports,
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
    fragments = ["apple"],
    attrs = {
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
            doc = """
A list of targets that are dependencies of the target being built, which will be linked into that
target.
""",
            providers = [
                [apple_common.Objc, CcInfo],
                [apple_common.Objc, CcInfo, AppleFrameworkImportInfo],
            ],
        ),
        "dsym_imports": attr.label_list(
            allow_files = True,
            doc = """
The list of files under a .dSYM directory, that is the imported framework's dSYM bundle.
""",
        ),
        "bundle_only": attr.bool(
            default = False,
            doc = """
Avoid linking the dynamic framework, but still include it in the app. This is useful when you want
to manually dlopen the framework at runtime.
""",
        ),
    },
    doc = """
This rule encapsulates an already-built dynamic framework. It is defined by a list of
files in exactly one `.framework` directory. `apple_dynamic_framework_import` targets
need to be added to library targets through the `deps` attribute.
### Examples

```python
apple_dynamic_framework_import(
    name = "my_dynamic_framework",
    framework_imports = glob(["my_dynamic_framework.framework/**"]),
)

objc_library(
    name = "foo_lib",
    ...,
    deps = [
        ":my_dynamic_framework",
    ],
)
```
""",
)

apple_static_framework_import = rule(
    implementation = _apple_static_framework_import_impl,
    fragments = ["apple"],
    attrs = dicts.add(swift_common.toolchain_attrs(), {
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
    }),
    doc = """
This rule encapsulates an already-built static framework. It is defined by a list of
files in exactly one `.framework` directory. `apple_static_framework_import` targets
need to be added to library targets through the `deps` attribute.
### Examples

```python
apple_static_framework_import(
    name = "my_static_framework",
    framework_imports = glob(["my_static_framework.framework/**"]),
)

objc_library(
    name = "foo_lib",
    ...,
    deps = [
        ":my_static_framework",
    ],
)
```
""",
)
