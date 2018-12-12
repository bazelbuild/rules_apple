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

"""Rule implementations for creating iOS applications and bundles.

DO NOT load this file directly; use the macro in
@build_bazel_rules_apple//apple:ios.bzl instead. Bazel rules receive their name at
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
    "@build_bazel_rules_apple//apple/internal/aspects:framework_import_aspect.bzl",
    "framework_import_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:resource_aspect.bzl",
    new_apple_resource_aspect = "apple_resource_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal:ios_rules.bzl",
    "ios_application_impl",
    "ios_extension_impl",
    "ios_framework_impl",
    "ios_static_framework_impl",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "AppleResourceBundleInfo",
    "IosExtensionBundleInfo",
    "IosFrameworkBundleInfo",
    "WatchosApplicationBundleInfo",
)

ios_application = rule_factory.make_bundling_rule(
    ios_application_impl,
    additional_attrs = {
        "app_icons": attr.label_list(allow_files = True),
        "dedupe_unbundled_resources": attr.bool(default = True),
        "extensions": attr.label_list(
            providers = [[AppleBundleInfo, IosExtensionBundleInfo]],
            aspects = [framework_import_aspect],
        ),
        "frameworks": attr.label_list(
            providers = [[AppleBundleInfo, IosFrameworkBundleInfo]],
            aspects = [framework_import_aspect],
        ),
        "launch_images": attr.label_list(allow_files = True),
        "launch_storyboard": attr.label(
            allow_single_file = [".storyboard", ".xib"],
        ),
        "settings_bundle": attr.label(
            aspects = [new_apple_resource_aspect],
            providers = [["objc"], [AppleResourceBundleInfo]],
        ),
        "watch_application": attr.label(
            providers = [[AppleBundleInfo, WatchosApplicationBundleInfo]],
        ),
    },
    archive_extension = ".ipa",
    bundles_frameworks = True,
    code_signing = rule_factory.code_signing(".mobileprovision"),
    device_families = rule_factory.device_families(allowed = ["iphone", "ipad"]),
    needs_pkginfo = True,
    executable = True,
    path_formats = rule_factory.simple_path_formats(
        path_in_archive_format = "Payload/%s",
    ),
    platform_type = apple_common.platform_type.ios,
    product_type = rule_factory.product_type(
        apple_product_type.application,
        values = [
            apple_product_type.application,
            apple_product_type.messages_application,
        ],
    ),
)

ios_extension = rule_factory.make_bundling_rule(
    ios_extension_impl,
    additional_attrs = {
        "app_icons": attr.label_list(allow_files = True),
        "asset_catalogs": attr.label_list(allow_files = True),
        "dedupe_unbundled_resources": attr.bool(default = True),
        "frameworks": attr.label_list(
            providers = [[AppleBundleInfo, IosFrameworkBundleInfo]],
        ),
        "_extension_safe": attr.bool(default = True),
    },
    archive_extension = ".zip",
    code_signing = rule_factory.code_signing(".mobileprovision"),
    device_families = rule_factory.device_families(allowed = ["iphone", "ipad"]),
    path_formats = rule_factory.simple_path_formats(path_in_archive_format = "%s"),
    platform_type = apple_common.platform_type.ios,
    product_type = rule_factory.product_type(
        apple_product_type.app_extension,
        values = [
            apple_product_type.app_extension,
            apple_product_type.messages_extension,
            apple_product_type.messages_sticker_pack_extension,
        ],
    ),
)

ios_framework = rule_factory.make_bundling_rule(
    ios_framework_impl,
    additional_attrs = {
        "dedupe_unbundled_resources": attr.bool(default = True),
        "extension_safe": attr.bool(default = False),
        "frameworks": attr.label_list(
            providers = [[AppleBundleInfo, IosFrameworkBundleInfo]],
        ),
        "hdrs": attr.label_list(allow_files = [".h"]),
    },
    archive_extension = ".zip",
    binary_providers = [apple_common.AppleDylibBinary],
    code_signing = rule_factory.code_signing(skip_signing = True),
    device_families = rule_factory.device_families(allowed = ["iphone", "ipad"]),
    path_formats = rule_factory.simple_path_formats(path_in_archive_format = "%s"),
    platform_type = apple_common.platform_type.ios,
    product_type = rule_factory.product_type(
        apple_product_type.framework,
        private = True,
    ),
)

ios_static_framework = rule_factory.make_bundling_rule(
    ios_static_framework_impl,
    additional_attrs = {
        "avoid_deps": attr.label_list(),
        "dedupe_unbundled_resources": attr.bool(default = True),
        "exclude_resources": attr.bool(default = False),
        "hdrs": attr.label_list(allow_files = [".h"]),
    },
    archive_extension = ".zip",
    binary_providers = [apple_common.AppleStaticLibrary],
    bundle_id_attr_mode = rule_factory.attribute_modes.UNSUPPORTED,
    code_signing = rule_factory.code_signing(skip_signing = True),
    device_families = rule_factory.device_families(
        allowed = ["iphone", "ipad"],
        mandatory = False,
    ),
    infoplists_attr_mode = rule_factory.attribute_modes.UNSUPPORTED,
    path_formats = rule_factory.simple_path_formats(path_in_archive_format = "%s"),
    platform_type = apple_common.platform_type.ios,
    product_type = rule_factory.product_type(
        apple_product_type.static_framework,
        private = True,
    ),
)
