"""Implementation of apple_developer_framework_import."""

load("@bazel_skylib//lib:collections.bzl", "collections")
load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:sets.bzl", "sets")
load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load(
    "//apple:providers.bzl",
    "AppleDeveloperFrameworkImportInfo",
)
load(
    "//apple:utils.bzl",
    "group_files_by_directory",
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
    "//apple/internal:providers.bzl",
    "new_appledeveloperframeworkimportinfo",
)
load(
    "//apple/internal:rule_attrs.bzl",
    "rule_attrs",
)

_REPOSITORY_NAME = "local_developer_frameworks"

def _grouped_framework_files(framework_imports):
    framework_groups = group_files_by_directory(
        framework_imports,
        ["framework"],
        attr = "build_imports",
    )

    unique_frameworks = collections.uniq(
        [paths.basename(path) for path in framework_groups.keys()],
    )
    if len(unique_frameworks) > 1:
        fail("A developer framework import target may only include files for a single '.framework' bundle.")

    return framework_groups

def _get_framework_binary_file(framework_dir, framework_imports):
    framework_name = paths.split_extension(paths.basename(framework_dir))[0]
    framework_path = paths.join(framework_dir, framework_name)
    for framework_import in framework_imports:
        if framework_import.path == framework_path:
            return framework_import

    versioned_candidates = [
        framework_import
        for framework_import in framework_imports
        if framework_import.basename == framework_name
    ]
    if len(versioned_candidates) == 1:
        return versioned_candidates[0]

    return None

def _framework_search_paths(header_imports):
    if header_imports:
        header_groups = _grouped_framework_files(header_imports)

        search_paths = sets.make()
        for path in header_groups.keys():
            sets.insert(search_paths, paths.dirname(path))
        return sets.to_list(search_paths)
    else:
        return []

def _apple_developer_framework_import_impl(ctx):
    if not ctx.attr.preserve_signature:
        fail("apple_developer_framework_import currently only supports preserve_signature = True")

    cc_toolchain = find_cc_toolchain(ctx)
    target_triplet = cc_toolchain_info_support.get_apple_clang_triplet(cc_toolchain)
    if target_triplet.os != "macos":
        fail("apple_developer_framework_import is currently only supported for macOS builds.")

    build_imports = ctx.files.build_imports
    runtime_imports = ctx.files.runtime_imports
    classified_framework = framework_import_support.classify_framework_imports(
        ctx.var,
        build_imports,
    )
    framework_groups = _grouped_framework_files(build_imports)
    framework_binaries = [
        _get_framework_binary_file(framework_dir, framework_imports.to_list())
        for framework_dir, framework_imports in framework_groups.items()
    ]
    framework_binaries = [binary for binary in framework_binaries if binary]
    if len(framework_binaries) != 1:
        fail("Expected exactly one framework binary for developer framework '{}'.".format(ctx.attr.framework_name))
    framework_binary = framework_binaries[0]

    cc_info = framework_import_support.cc_info_with_dependencies(
        actions = ctx.actions,
        cc_toolchain = cc_toolchain,
        ctx = ctx,
        deps = ctx.attr.deps,
        disabled_features = ctx.disabled_features,
        features = ctx.features,
        framework_includes = _framework_search_paths(
            classified_framework.header_imports +
            classified_framework.swift_interface_imports +
            classified_framework.swift_module_imports,
        ),
        header_imports = classified_framework.header_imports,
        kind = "dynamic",
        label = ctx.label,
        libraries = [framework_binary],
        swiftinterface_imports = classified_framework.swift_interface_imports,
        swiftmodule_imports = classified_framework.swift_module_imports,
    )

    return [
        DefaultInfo(files = depset(build_imports + runtime_imports)),
        cc_info,
        new_appledeveloperframeworkimportinfo(
            binary = framework_binary,
            bundle = ctx.attr.bundle,
            framework_name = ctx.attr.framework_name,
            preserve_signature = ctx.attr.preserve_signature,
            runtime_imports = depset(runtime_imports),
        ),
    ]

_apple_developer_framework_import = rule(
    implementation = _apple_developer_framework_import_impl,
    attrs = dicts.add(
        rule_attrs.common_tool_attrs(),
        {
            "bundle": attr.bool(default = True),
            "build_imports": attr.label_list(
                allow_files = True,
                mandatory = True,
            ),
            "deps": attr.label_list(
                providers = [[CcInfo]],
            ),
            "framework_name": attr.string(mandatory = True),
            "preserve_signature": attr.bool(default = True),
            "runtime_imports": attr.label_list(
                allow_files = True,
                mandatory = True,
            ),
        },
    ),
    fragments = ["apple", "cpp", "objc"],
    provides = [AppleDeveloperFrameworkImportInfo, CcInfo],
    toolchains = use_cc_toolchain(),
)

def apple_developer_framework_import(
        name,
        framework_name,
        preserve_signature = True,
        bundle = True,
        **kwargs):
    """Imports a framework shipped inside `$DEVELOPER_DIR/Library/Frameworks`."""
    repository = "@{}//:".format(_REPOSITORY_NAME)
    _apple_developer_framework_import(
        name = name,
        framework_name = framework_name,
        preserve_signature = preserve_signature,
        bundle = bundle,
        build_imports = [repository + framework_name + "_build_files"],
        runtime_imports = [repository + framework_name + "_runtime_files"],
        **kwargs
    )
