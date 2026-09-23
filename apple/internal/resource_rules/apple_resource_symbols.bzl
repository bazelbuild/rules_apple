# Copyright 2026 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Rules that generate type-safe Swift symbols for Apple resources."""

load("@apple_support//lib:apple_support.bzl", "apple_support")
load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("//apple/internal:apple_toolchains.bzl", "apple_toolchain_utils")
load("//apple/internal:features_support.bzl", "features_support")
load("//apple/internal:platform_support.bzl", "platform_support")
load("//apple/internal:resource_actions.bzl", "resource_actions")
load("//apple/internal:resources.bzl", "resources")

def _platform_prerequisites(ctx):
    return platform_support.platform_prerequisites(
        apple_fragment = ctx.fragments.apple,
        apple_platform_info = platform_support.apple_platform_info_from_rule_ctx(ctx),
        build_settings = apple_toolchain_utils.get_xplat_toolchain(ctx).build_settings,
        config_vars = ctx.var,
        device_families = None,
        explicit_minimum_deployment_os = None,
        explicit_minimum_os = None,
        features = features_support.compute_enabled_features(
            requested_features = ctx.features,
            unsupported_features = ctx.disabled_features,
        ),
        objc_fragment = None,
        uses_swift = True,
        xcode_version_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
    )

def _apple_asset_catalog_symbols_impl(ctx):
    if not ctx.attr.bundle_id:
        fail("bundle_id must not be empty")

    output_file = ctx.actions.declare_file(
        "{}/GeneratedAssetSymbols.swift".format(ctx.label.name),
    )
    compiled_output_dir = ctx.actions.declare_directory(
        "{}.assetcatalog-symbols".format(ctx.label.name),
    )
    resource_actions.generate_asset_symbols(
        actions = ctx.actions,
        asset_files = ctx.files.asset_catalogs,
        bundle_id = ctx.attr.bundle_id,
        compiled_output_dir = compiled_output_dir,
        output_file = output_file,
        platform_prerequisites = _platform_prerequisites(ctx),
        xctoolrunner = apple_toolchain_utils.get_mac_toolchain(ctx).xctoolrunner,
    )
    return [
        DefaultInfo(files = depset([output_file])),
        resources.bucketize_typed([compiled_output_dir], "processed"),
    ]

def _apple_string_catalog_symbols_impl(ctx):
    table_name = paths.replace_extension(ctx.file.string_catalog.basename, "")
    compiled_output_dir = ctx.actions.declare_directory(
        "{}.stringcatalog-resources".format(ctx.label.name),
    )
    output_file = ctx.actions.declare_file(
        "{}/GeneratedStringSymbols_{}.swift".format(ctx.label.name, table_name),
    )
    platform_prerequisites = _platform_prerequisites(ctx)
    xctoolrunner = apple_toolchain_utils.get_mac_toolchain(ctx).xctoolrunner
    resource_actions.compile_xcstrings(
        actions = ctx.actions,
        input_file = ctx.file.string_catalog,
        output_dir = compiled_output_dir,
        platform_prerequisites = platform_prerequisites,
        xctoolrunner = xctoolrunner,
    )
    resource_actions.generate_xcstrings_symbols(
        actions = ctx.actions,
        input_file = ctx.file.string_catalog,
        output_file = output_file,
        platform_prerequisites = platform_prerequisites,
        xctoolrunner = xctoolrunner,
    )
    return [
        DefaultInfo(files = depset([output_file])),
        resources.bucketize_typed([compiled_output_dir], "processed"),
    ]

_common_attrs = dicts.add(
    apple_support.action_required_attrs(),
    apple_support.platform_constraint_attrs(),
    apple_toolchain_utils.shared_attrs(),
)

apple_asset_catalog_symbols = rule(
    implementation = _apple_asset_catalog_symbols_impl,
    exec_groups = apple_toolchain_utils.use_apple_exec_group_toolchain(),
    attrs = dicts.add(
        _common_attrs,
        {
            "asset_catalogs": attr.label_list(
                allow_empty = False,
                allow_files = True,
                mandatory = True,
                doc = "Files beneath the `.xcassets` directories for which to generate symbols.",
            ),
            "bundle_id": attr.string(
                mandatory = True,
                doc = "Bundle identifier used by actool when generating the symbols.",
            ),
        },
    ),
    fragments = ["apple"],
    doc = """Generates `GeneratedAssetSymbols.swift` from asset catalogs using Apple's `actool`.

Add this target to both a `swift_library`'s `srcs` and `data`. The generated Swift source is
compiled into the library, while the natively compiled asset catalog is propagated for bundling.
""",
)

apple_string_catalog_symbols = rule(
    implementation = _apple_string_catalog_symbols_impl,
    exec_groups = apple_toolchain_utils.use_apple_exec_group_toolchain(),
    attrs = dicts.add(
        _common_attrs,
        {
            "string_catalog": attr.label(
                allow_single_file = [".xcstrings"],
                mandatory = True,
                doc = "The `.xcstrings` catalog for which to generate symbols.",
            ),
        },
    ),
    fragments = ["apple"],
    doc = """Generates Swift symbols from a string catalog using Apple's `xcstringstool`.

Add this target to both a `swift_library`'s `srcs` and `data`. The generated Swift source is
compiled into the library, while the natively compiled strings are propagated for bundling. The
selected Xcode must provide the `xcstringstool generate-symbols` subcommand.
""",
)
