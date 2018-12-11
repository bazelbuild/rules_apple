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

"""Rule implementations for creating watchOS applications and bundles.

DO NOT load this file directly; use the macro in
@build_bazel_rules_apple//apple:watchos.bzl instead. Bazel rules receive their name at
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
    "@build_bazel_rules_apple//apple/internal:watchos_rules.bzl",
    "watchos_application_impl",
    "watchos_extension_impl",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "WatchosExtensionBundleInfo",
)

watchos_application = rule_factory.make_bundling_rule(
    watchos_application_impl,
    additional_attrs = {
        "app_icons": attr.label_list(allow_files = True),
        "extension": attr.label(
            providers = [[AppleBundleInfo, WatchosExtensionBundleInfo]],
            mandatory = True,
        ),
        "storyboards": attr.label_list(
            allow_files = [".storyboard"],
        ),
    },
    archive_extension = ".zip",
    bundles_frameworks = True,
    code_signing = rule_factory.code_signing(".mobileprovision"),
    device_families = rule_factory.device_families(allowed = ["watch"]),
    needs_pkginfo = True,
    path_formats = rule_factory.simple_path_formats(
        path_in_archive_format = "%s",
    ),
    platform_type = apple_common.platform_type.watchos,
    product_type = rule_factory.product_type(
        apple_product_type.watch2_application,
        private = True,
    ),
    use_binary_rule = False,
)

watchos_extension = rule_factory.make_bundling_rule(
    watchos_extension_impl,
    additional_attrs = {
        "app_icons": attr.label_list(allow_files = True),
    },
    archive_extension = ".zip",
    code_signing = rule_factory.code_signing(".mobileprovision"),
    device_families = rule_factory.device_families(allowed = ["watch"]),
    path_formats = rule_factory.simple_path_formats(path_in_archive_format = "%s"),
    platform_type = apple_common.platform_type.watchos,
    product_type = rule_factory.product_type(
        apple_product_type.watch2_extension,
        private = True,
    ),
)
