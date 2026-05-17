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

"""apple_archive Starlark tests."""

load(
    "@bazel_skylib//lib:unittest.bzl",
    "analysistest",
    "asserts",
)
load(
    "//apple:providers.bzl",
    "AppleBundleInfo",
)
load(
    "//test/starlark_tests/rules:analysis_failure_message_test.bzl",
    "analysis_failure_message_test",
)
load(
    "//test/starlark_tests/rules:analysis_output_group_info_files_exact_test.bzl",
    "analysis_output_group_info_files_exact_test",
)
load(
    "//test/starlark_tests/rules:output_group_zip_contents_test.bzl",
    "output_group_zip_contents_test",
)

def _apple_archive_preserves_bundle_archive_root_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    archive_bundle_info = target_under_test[AppleBundleInfo]
    wrapped_bundle_info = ctx.attr.bundle[AppleBundleInfo]

    asserts.equals(
        env,
        wrapped_bundle_info.archive_root,
        archive_bundle_info.archive_root,
        "apple_archive should preserve the wrapped bundle AppleBundleInfo.archive_root",
    )
    asserts.equals(
        env,
        ctx.attr.expected_archive_basename,
        archive_bundle_info.archive.basename,
    )

    return analysistest.end(env)

apple_archive_preserves_bundle_archive_root_test = analysistest.make(
    _apple_archive_preserves_bundle_archive_root_test_impl,
    attrs = {
        "bundle": attr.label(
            mandatory = True,
            providers = [AppleBundleInfo],
        ),
        "expected_archive_basename": attr.string(
            mandatory = True,
        ),
    },
)

def apple_archive_test_suite(name):
    """Test suite for apple_archive.

    Args:
      name: the base name to be used in things created by this macro
    """
    analysis_failure_message_test(
        name = "{}_rejects_unsupported_bundle_product_type_fail_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:ipa_with_extension",
        expected_error = (
            "apple_archive only supports application bundles for iOS, macOS, " +
            "tvOS, visionOS, and watchOS, but found platform type \"ios\" and product type " +
            "\"com.apple.product-type.app-extension\""
        ),
        tags = [name],
    )

    analysis_output_group_info_files_exact_test(
        name = "{}_has_combined_dossier_zip_output_group_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:ipa_with_app",
        output_group_name = "combined_dossier_zip",
        expected_outputs = [
            "ipa_with_app_dossier_with_bundle.zip",
        ],
        tags = [name],
    )

    apple_archive_preserves_bundle_archive_root_test(
        name = "{}_preserves_bundle_archive_root_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:ipa_with_app",
        bundle = "//test/starlark_tests/targets_under_test/ios:app",
        expected_archive_basename = "ipa_with_app.ipa",
        tags = [name],
    )

    output_group_zip_contents_test(
        name = "{}_combined_dossier_zip_contains_archive_and_dossier_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:ipa_with_app",
        output_group_name = "combined_dossier_zip",
        output_group_file_shortpath = "test/starlark_tests/targets_under_test/ios/ipa_with_app_dossier_with_bundle.zip",
        contains = [
            "bundle/Payload/app.app/Info.plist",
            "bundle/Payload/app.app/app",
            "dossier/manifest.json",
        ],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
