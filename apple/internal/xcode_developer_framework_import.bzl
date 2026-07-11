# Copyright 2026 The Bazel Authors. All rights reserved.
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

"""Implementation of xcode_developer_framework_import."""

load(
    "@bazel_skylib//lib:collections.bzl",
    "collections",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
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
    "@build_bazel_rules_swift//swift:swift.bzl",
    "swift_clang_module_aspect",
    "swift_common",
)
load(
    "@rules_cc//cc:find_cc_toolchain.bzl",
    "find_cc_toolchain",
    "use_cc_toolchain",
)
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load(
    "//apple:providers.bzl",
    "AppleFrameworkImportInfo",
)
load(
    "//apple:utils.bzl",
    "group_files_by_directory",
)
load(
    "//apple/internal:apple_toolchains.bzl",
    "apple_toolchain_utils",
)
load(
    "//apple/internal:cc_toolchain_info_support.bzl",
    "cc_toolchain_info_support",
)
load(
    "//apple/internal:framework_import_support.bzl",
    "framework_import_support",
)
load(
    "//apple/internal:rule_attrs.bzl",
    "rule_attrs",
)
load(
    "//apple/internal/providers:developer_framework_import_info.bzl",
    "AppleDeveloperFrameworkImportInfo",
)
load(
    "//apple/internal/utils:bundle_paths.bzl",
    "bundle_paths",
)

def _grouped_framework_files(framework_imports):
    framework_groups = group_files_by_directory(
        framework_imports,
        ["framework"],
        attr = "framework_imports",
    )

    unique_frameworks = collections.uniq(
        [paths.basename(path) for path in framework_groups.keys()],
    )
    if len(unique_frameworks) > 1:
        fail(
            "An xcode_developer_framework_import target may only include files for a " +
            "single '.framework' bundle.",
            attr = "framework_imports",
        )

    return framework_groups

def _all_framework_binaries(frameworks_groups):
    binaries = []
    for framework_dir, framework_imports in frameworks_groups.items():
        binary = _get_framework_binary_file(framework_dir, framework_imports.to_list())
        if binary != None:
            binaries.append(binary)
    return binaries

def _get_framework_binary_file(framework_dir, framework_imports):
    framework_name = paths.split_extension(paths.basename(framework_dir))[0]
    framework_path = paths.join(framework_dir, framework_name)
    for framework_import in framework_imports:
        if framework_import.path == framework_path:
            return framework_import
    return None

def _framework_search_paths(header_imports):
    if not header_imports:
        return []
    header_groups = _grouped_framework_files(header_imports)
    search_paths = sets.make()
    for path in header_groups.keys():
        sets.insert(search_paths, paths.dirname(path))
    return sets.to_list(search_paths)

def _cc_info_for_force_loaded_archives(*, actions, label, archives):
    """Returns a CcInfo whose linking_context force-loads the given static archives."""
    if not archives:
        return None
    linker_input = cc_common.create_linker_input(
        owner = label,
        libraries = depset([
            cc_common.create_library_to_link(
                actions = actions,
                alwayslink = True,
                static_library = archive,
            )
            for archive in archives
        ]),
    )
    return CcInfo(
        linking_context = cc_common.create_linking_context(
            linker_inputs = depset([linker_input]),
        ),
    )

def _xcode_developer_framework_import_impl(ctx):
    """Implementation for xcode_developer_framework_import."""
    actions = ctx.actions
    cc_toolchain = find_cc_toolchain(ctx)
    deps = ctx.attr.deps
    disabled_features = ctx.disabled_features
    features = ctx.features
    framework_imports = ctx.files.framework_imports
    linker_imports = ctx.files.linker_imports
    linkopts = list(ctx.attr.linkopts)
    label = ctx.label

    for linker_import in linker_imports:
        if linker_import.extension != "a":
            fail(
                "xcode_developer_framework_import 'linker_imports' may only contain " +
                "static archives (.a). Got: {}".format(linker_import.short_path),
                attr = "linker_imports",
            )

    target_triplet = cc_toolchain_info_support.get_apple_clang_triplet(cc_toolchain)
    providers = []
    framework = framework_import_support.classify_framework_imports(
        ctx.var,
        framework_imports,
    )

    dsym_binaries = framework_import_support.get_dsym_binaries(ctx.files.dsym_imports)
    dsym_imports = ctx.files.dsym_imports
    framework_groups = _grouped_framework_files(framework_imports)
    framework_binaries = _all_framework_binaries(framework_groups)
    debug_info_binaries = framework_import_support.get_debug_info_binaries(
        dsym_binaries = dsym_binaries,
        framework_binaries = framework_binaries,
    )

    providers.append(framework_import_support.framework_import_info_with_dependencies(
        build_archs = [target_triplet.architecture],
        deps = deps,
        debug_info_binaries = debug_info_binaries,
        dsyms = dsym_imports,
        framework_imports = (
            framework.binary_imports +
            framework.bundling_imports
        ),
    ))

    framework_includes = _framework_search_paths(
        framework.header_imports +
        framework.swift_interface_imports +
        framework.swift_module_imports,
    )

    additional_cc_infos = []
    static_linker_cc_info = _cc_info_for_force_loaded_archives(
        actions = actions,
        label = label,
        archives = linker_imports,
    )
    if static_linker_cc_info:
        additional_cc_infos.append(static_linker_cc_info)

    cc_info = framework_import_support.cc_info_with_dependencies(
        actions = actions,
        additional_cc_infos = additional_cc_infos,
        cc_toolchain = cc_toolchain,
        ctx = ctx,
        deps = deps,
        disabled_features = disabled_features,
        features = features,
        framework_includes = framework_includes,
        header_imports = framework.header_imports,
        kind = "dynamic",
        label = label,
        libraries = framework.binary_imports,
        linkopts = linkopts,
        swiftinterface_imports = framework.swift_interface_imports,
        swiftmodule_imports = framework.swift_module_imports,
    )
    providers.append(cc_info)

    framework_name = framework.bundle_name or ctx.attr.framework_name
    provider_linkopts = list(linkopts)
    provider_link_inputs = list(linker_imports)
    for archive in linker_imports:
        provider_linkopts.append("-Wl,-force_load,{}".format(archive.path))
    if framework.binary_imports and framework_name:
        binary_file = framework.binary_imports[0]
        framework_root = bundle_paths.farthest_parent(binary_file.path, "framework")
        framework_parent = paths.dirname(framework_root)
        provider_linkopts = [
            "-F",
            framework_parent,
            "-framework",
            framework_name,
        ] + provider_linkopts
        provider_link_inputs = [binary_file] + provider_link_inputs

    providers.append(AppleDeveloperFrameworkImportInfo(
        framework_name = framework_name,
        linker_imports = depset(provider_link_inputs),
        linkopts = depset(provider_linkopts),
    ))

    swiftinterface_files = []
    if (
        "apple.import_framework_via_swiftinterface" not in disabled_features and
        framework.swift_interface_imports
    ):
        swiftinterface_files = framework_import_support.get_swift_module_files_with_target_triplet(
            swift_module_files = framework.swift_interface_imports,
            target_triplet = target_triplet,
        )

    if swiftinterface_files:
        swift_toolchain = swift_common.get_toolchain(ctx)
        providers.append(
            framework_import_support.swift_info_from_module_interface(
                actions = actions,
                ctx = ctx,
                deps = deps,
                disabled_features = disabled_features,
                features = features,
                framework_includes = framework_includes,
                hdrs = framework.header_imports,
                module_map = framework.module_map_imports[0] if framework.module_map_imports else None,
                module_name = framework.bundle_name,
                rule_label = label,
                swift_toolchain = swift_toolchain,
                swiftinterface_files = swiftinterface_files,
            ),
        )
    else:
        swift_interop_info = framework_import_support.swift_interop_info_with_dependencies(
            deps = deps,
            module_name = framework.bundle_name,
            module_map_imports = framework.module_map_imports,
        )
        if swift_interop_info:
            providers.append(swift_interop_info)

    return providers

xcode_developer_framework_import = rule(
    implementation = _xcode_developer_framework_import_impl,
    fragments = ["cpp"],
    attrs = dicts.add(
        rule_attrs.common_tool_attrs(),
        {
            "framework_imports": attr.label_list(
                allow_empty = False,
                allow_files = True,
                mandatory = True,
                doc = """
The list of files under a single `.framework` directory that compose an Xcode developer framework.
""",
            ),
            "framework_name": attr.string(
                doc = """
Optional. The framework's bundle name. If omitted, the name is inferred from `framework_imports`.
""",
            ),
            "linker_imports": attr.label_list(
                allow_files = True,
                doc = """
List of `.a` static archives (typically from `$DEVELOPER_DIR/usr/lib`) that must be
force-loaded at link time. Use this for companion archives whose ObjC `+load`
registrations must run for the framework to function at runtime. These files are
not embedded in the final bundle.

Common case: `XcodeKit` requires `libXcodeExtension.a` so `XCExtensionSubsystem`
and related classes are registered when the extension is loaded. Without
force-loading, the extension fails at runtime with messages like
`[XCExtensionSubsystem] not present; possible missing linkage`.
""",
            ),
            "linkopts": attr.string_list(
                doc = """
Additional link flag strings propagated to the link action via `CcInfo`.
""",
            ),
            "dsym_imports": attr.label_list(
                allow_files = True,
                doc = """
The list of files under a `.dSYM` directory for the imported developer framework.
""",
            ),
            "deps": attr.label_list(
                aspects = [swift_clang_module_aspect],
                doc = """
A list of targets that are dependencies of the target being built, which will be linked into that
target.
""",
                providers = [
                    [CcInfo],
                    [CcInfo, AppleFrameworkImportInfo],
                ],
            ),
            "_cc_toolchain": attr.label(
                default = "@rules_cc//cc:current_cc_toolchain",
                doc = "The C++ toolchain to use.",
            ),
        },
    ),
    doc = """
Encapsulates an already-built Xcode developer framework (one of the frameworks shipped under
`$DEVELOPER_DIR/Library/Frameworks`, e.g. `XcodeKit`) so it can be linked, compiled against, and
embedded under `Contents/Frameworks` of macOS bundles. Reuses the standard imported-framework
bundling path, including code signing.

The `@developer_frameworks` repository auto-generates a minimal target per framework. For most
frameworks you can use those targets directly:

```python
macos_extension(
    name = "MyExtension",
    frameworks = ["@developer_frameworks//:XcodeKit"],
    ...
)
```

### Companion archives (`linker_imports`)

Some developer frameworks need a companion static archive from `$DEVELOPER_DIR/usr/lib` to be
force-loaded at link time so the framework's ObjC runtime registrations happen. Apple does not
publish this mapping in the framework metadata, so consumers wire the archives they need by
wrapping the auto-generated target with their own `xcode_developer_framework_import` that sets
`linker_imports`.

The most common case is `XcodeKit`, which needs `libXcodeExtension.a` to register
`XCExtensionSubsystem` and related classes — without it, Xcode source-editor / ExtensionKit
extensions fail at runtime with `[XCExtensionSubsystem] not present; possible missing linkage`:

```python
load("@rules_apple//apple:apple.bzl", "xcode_developer_framework_import")

xcode_developer_framework_import(
    name = "XcodeKit",
    framework_name = "XcodeKit",
    framework_imports = ["@developer_frameworks//:XcodeKit_framework_files"],
    linker_imports = ["@developer_frameworks//:usr/lib/libXcodeExtension.a"],
)

macos_extension(
    name = "MyXcodeExtension",
    extensionkit_extension = True,
    frameworks = [":XcodeKit"],
    ...
)
```

The `<framework>_framework_files` filegroup and `usr/lib/**` files are exported by the
`@developer_frameworks` hub repo so the wrapper works across Xcode versions via the same
`--xcode_version` selection used elsewhere.

### Where to find the right archive

The framework-to-archive mapping is not encoded in the framework itself. To discover it, inspect
`$DEVELOPER_DIR/usr/lib/` and use `nm -gU <archive>` to find the class/symbol your runtime is
missing. For example, `nm -gU $DEVELOPER_DIR/usr/lib/libXcodeExtension.a` shows
`_OBJC_CLASS_$_XCExtensionSubsystem`, confirming that's the archive needed for XcodeKit-based
extensions.
""",
    exec_groups = apple_toolchain_utils.use_apple_exec_group_toolchain(),
    toolchains = swift_common.use_toolchain() + use_cc_toolchain(),
)
