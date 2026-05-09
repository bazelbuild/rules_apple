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

"""smart resource deduplication Starlark tests."""

load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
)

def smart_resource_deduplication_test_suite(name):
    """Test suite for smart resource deduplication.

    Args:
      name: the base name to be used in things created by this macro
    """

    archive_contents_test(
        name = "{}_resources_in_app_and_framework".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_smart_resource_dedupe",
        contains = [
            "$BUNDLE_ROOT/Frameworks/smart_resource_dedupe_fmwk.framework/Assets.car",
            "$BUNDLE_ROOT/Frameworks/smart_resource_dedupe_fmwk.framework/basic.bundle/basic_bundle.txt",
            "$BUNDLE_ROOT/Frameworks/smart_resource_dedupe_fmwk.framework/nonlocalized.plist",
            "$BUNDLE_ROOT/Frameworks/smart_resource_dedupe_fmwk.framework/nonlocalized.strings",
            "$BUNDLE_ROOT/Frameworks/smart_resource_dedupe_fmwk.framework/sample.png",
            "$BUNDLE_ROOT/Frameworks/smart_resource_dedupe_fmwk.framework/smart_resource_dedupe_gen_file.txt",
            "$BUNDLE_ROOT/Frameworks/smart_resource_dedupe_fmwk.framework/smart_resource_dedupe_resource_only.txt",
            "$BUNDLE_ROOT/Assets.car",
            "$BUNDLE_ROOT/basic.bundle/basic_bundle.txt",
            "$BUNDLE_ROOT/sample.png",
            "$BUNDLE_ROOT/smart_resource_dedupe_app.strings",
            "$BUNDLE_ROOT/smart_resource_dedupe_resource_only.txt",
        ],
        not_contains = [
            "$BUNDLE_ROOT/nonlocalized.plist",
            "$BUNDLE_ROOT/nonlocalized.strings",
            "$BUNDLE_ROOT/smart_resource_dedupe_gen_file.txt",
        ],
        asset_catalog_test_file = "$BUNDLE_ROOT/Frameworks/smart_resource_dedupe_fmwk.framework/Assets.car",
        asset_catalog_test_contains = ["star"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_resources_in_app_and_framework_app_assets".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_smart_resource_dedupe",
        contains = [
            "$BUNDLE_ROOT/Assets.car",
        ],
        asset_catalog_test_file = "$BUNDLE_ROOT/Assets.car",
        asset_catalog_test_contains = ["star"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_shared_resource_deduplicated_when_not_referenced_by_app_only_lib".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_smart_resource_dedupe_no_direct_resources",
        not_contains = [
            "$BUNDLE_ROOT/smart_resource_dedupe_resource_only.txt",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_resources_added_directly_into_apps".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_smart_resource_dedupe_direct_resources",
        contains = [
            "$BUNDLE_ROOT/Frameworks/smart_resource_dedupe_fmwk.framework/smart_resource_dedupe_resource_only.txt",
            "$BUNDLE_ROOT/smart_resource_dedupe_resource_only.txt",
        ],
        tags = [name],
    )
