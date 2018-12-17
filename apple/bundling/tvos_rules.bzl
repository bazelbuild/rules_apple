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

load(
    "@build_bazel_rules_apple//apple/bundling:product_support.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/bundling:rule_factory.bzl",
    "rule_factory",
)
load(
    "@build_bazel_rules_apple//apple/internal:tvos_rules.bzl",
    "tvos_application_impl",
    "tvos_extension_impl",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "TvosExtensionBundleInfo",
)

tvos_application = rule_factory.make_bundling_rule(
    tvos_application_impl,
    additional_attrs = {
        "app_icons": attr.label_list(allow_files = True),
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
        "extensions": attr.label_list(
            providers = [[
                AppleBundleInfo,
                TvosExtensionBundleInfo,
            ]],
        ),
        "launch_images": attr.label_list(allow_files = True),
        "linkopts": attr.string_list(),
        "platform_type": attr.string(
            default = "tvos",
            doc = """
This attribute is public as an implementation detail while we migrate the
architecture of the rules. Do not change its value.
""",
        ),
        "settings_bundle": attr.label(providers = [["objc"]]),
        "_cc_toolchain": attr.label(
            default = configuration_field(
                name = "cc_toolchain",
                fragment = "cpp",
            ),
        ),
        "_child_configuration_dummy": attr.label(
            cfg = apple_common.multi_arch_split,
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

tvos_extension = rule_factory.make_bundling_rule(
    tvos_extension_impl,
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
