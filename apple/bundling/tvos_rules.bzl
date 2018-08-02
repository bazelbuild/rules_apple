# Copyright 2017 The Bazel Authors. All rights reserved.
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

"""Bazel rules for creating tvOS applications and bundles.

DO NOT load this file directly; use the macro in
@build_bazel_rules_apple//apple:tvos.bzl instead. Bazel rules receive their name at
*definition* time based on the name of the global to which they are assigned.
We want the user to call macros that have the same name, to get automatic
binary creation, entitlements support, and other features--which requires a
wrapping macro because rules cannot invoke other rules.
"""

load("@build_bazel_rules_apple//apple/bundling:binary_support.bzl", "binary_support")
load("@build_bazel_rules_apple//apple/bundling:bundler.bzl", "bundler")
load(
    "@build_bazel_rules_apple//apple/bundling:bundling_support.bzl",
    "bundling_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:product_support.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/bundling:rule_factory.bzl",
    "rule_factory",
)
load("@build_bazel_rules_apple//apple/bundling:run_actions.bzl", "run_actions")
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "AppleResourceInfo",
    "AppleResourceSet",
    "TvosApplicationBundleInfo",
    "TvosExtensionBundleInfo",
)

def _tvos_application_impl(ctx):
    """Implementation of the `tvos_application` Skylark rule."""

    if ctx.attr.platform_type != "tvos":
        fail("platform_type must be 'tvos'")

    if ctx.attr.binary_type != "executable":
        fail("binary_type must be 'executable'")

    app_icons = ctx.files.app_icons
    if app_icons:
        bundling_support.ensure_single_xcassets_type(
            "app_icons",
            app_icons,
            "brandassets",
        )
    launch_images = ctx.files.launch_images
    if launch_images:
        bundling_support.ensure_single_xcassets_type(
            "launch_images",
            launch_images,
            "launchimage",
        )

    # Collect asset catalogs and launch images, if any are present.
    additional_resource_sets = []
    additional_resources = depset(app_icons + launch_images)
    if additional_resources:
        additional_resource_sets.append(AppleResourceSet(
            resources = additional_resources,
        ))

    # If a settings bundle was provided, pass in its files as if they were
    # objc_bundle imports, but forcing the "Settings.bundle" name.
    settings_bundle = ctx.attr.settings_bundle
    if settings_bundle:
        additional_resource_sets.append(AppleResourceSet(
            bundle_dir = "Settings.bundle",
            objc_bundle_imports = [
                bf.file
                for bf in settings_bundle.objc.bundle_file
            ],
        ))

    # TODO(b/32910122): Obtain framework information from extensions.
    embedded_bundles = [
        bundling_support.embedded_bundle(
            "PlugIns",
            extension,
            verify_has_child_plist = True,
        )
        for extension in ctx.attr.extensions
    ]

    binary_provider_struct = apple_common.link_multi_arch_binary(ctx = ctx)
    binary_provider = binary_provider_struct.binary_provider
    debug_outputs_provider = binary_provider_struct.debug_outputs_provider

    resource_info_providers = [
        dep[AppleResourceInfo]
        for dep in ctx.attr.deps
        if AppleResourceInfo in dep
    ]

    binary_artifact = binary_provider.binary
    deps_objc_provider = binary_provider.objc
    additional_providers, legacy_providers = bundler.run(
        ctx,
        "TvosExtensionArchive",
        "tvOS application",
        ctx.attr.bundle_id,
        binary_artifact = binary_artifact,
        additional_resource_sets = additional_resource_sets,
        embedded_bundles = embedded_bundles,
        deps_objc_providers = [deps_objc_provider],
        extra_runfiles = run_actions.start_simulator(ctx),
        debug_outputs = debug_outputs_provider,
        resource_info_providers = resource_info_providers,
    )

    return struct(
        providers = [
            TvosApplicationBundleInfo(),
            binary_provider,
        ] + additional_providers,
        **legacy_providers
    )

tvos_application = rule_factory.make_bundling_rule(
    _tvos_application_impl,
    additional_attrs = {
        "app_icons": attr.label_list(allow_files = True),
        "extensions": attr.label_list(
            providers = [[
                AppleBundleInfo,
                TvosExtensionBundleInfo,
            ]],
        ),
        "launch_images": attr.label_list(allow_files = True),
        "settings_bundle": attr.label(providers = [["objc"]]),
        "platform_type": attr.string(
            default = "tvos",
            doc = """
This attribute is public as an implementation detail while we migrate the
architecture of the rules. Do not change its value.
""",
        ),
        "_child_configuration_dummy": attr.label(
            cfg = apple_common.multi_arch_split,
            default = configuration_field(
                name = "cc_toolchain",
                fragment = "cpp",
            ),
        ),
        "_cc_toolchain": attr.label(
            default = configuration_field(
                name = "cc_toolchain",
                fragment = "cpp",
            ),
        ),
        "_googlemac_proto_compiler": attr.label(
            cfg = "host",
            default = Label("@bazel_tools//tools/objc:protobuf_compiler_wrapper"),
        ),
        "_googlemac_proto_compiler_support": attr.label(
            cfg = "host",
            default = Label("@bazel_tools//tools/objc:protobuf_compiler_support"),
        ),
        "_protobuf_well_known_types": attr.label(
            cfg = "host",
            default = Label("@bazel_tools//tools/objc:protobuf_well_known_types"),
        ),
        "binary_type": attr.string(
            default = "executable",
            doc = """
This attribute is public as an implementation detail while we migrate the
architecture of the rules. Do not change its value.
""",
        ),
        # TODO(dabelknap): Move these attributes into rule_factory
        "bundle_loader": attr.label(
            aspects = [apple_common.objc_proto_aspect],
            doc = """
This attribute is public as an implementation detail while we migrate the
architecture of the rules. Do not change its value.
""",
        ),
        "dylibs": attr.label_list(
            aspects = [apple_common.objc_proto_aspect],
            doc = """
This attribute is public as an implementation detail while we migrate the
architecture of the rules. Do not change its value.
""",
        ),
        "linkopts": attr.string_list(),
    },
    archive_extension = ".ipa",
    bundles_frameworks = True,
    code_signing = rule_factory.code_signing(".mobileprovision"),
    device_families = rule_factory.device_families(allowed = ["tv"]),
    needs_pkginfo = True,
    executable = True,
    deps_cfg = apple_common.multi_arch_split,
    path_formats = rule_factory.simple_path_formats(
        path_in_archive_format = "Payload/%s",
    ),
    platform_type = apple_common.platform_type.tvos,
    product_type = rule_factory.product_type(
        apple_product_type.application,
        private = True,
    ),
)

def _tvos_extension_impl(ctx):
    """Implementation of the `tvos_extension` Skylark rule."""
    binary_provider = binary_support.get_binary_provider(
        ctx.attr.deps,
        apple_common.AppleExecutableBinary,
    )
    binary_artifact = binary_provider.binary
    deps_objc_provider = binary_provider.objc
    additional_providers, legacy_providers = bundler.run(
        ctx,
        "TvosExtensionArchive",
        "tvOS extension",
        ctx.attr.bundle_id,
        binary_artifact = binary_artifact,
        deps_objc_providers = [deps_objc_provider],
    )

    return struct(
        providers = [
            TvosExtensionBundleInfo(),
            binary_provider,
        ] + additional_providers,
        **legacy_providers
    )

tvos_extension = rule_factory.make_bundling_rule(
    _tvos_extension_impl,
    archive_extension = ".zip",
    code_signing = rule_factory.code_signing(".mobileprovision"),
    device_families = rule_factory.device_families(allowed = ["tv"]),
    path_formats = rule_factory.simple_path_formats(path_in_archive_format = "%s"),
    platform_type = apple_common.platform_type.tvos,
    product_type = rule_factory.product_type(
        apple_product_type.app_extension,
        private = True,
    ),
)
