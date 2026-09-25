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

"""xcode_developer_framework_import Starlark tests."""

load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
)

def xcode_developer_framework_import_test_suite(name):
    """Test suite for xcode_developer_framework_import.

    Args:
      name: the base name to be used in things created by this macro
    """

    archive_contents_test(
        name = "{}_macos_application_bundles_developer_framework".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_developer_framework_in_frameworks",
        contains = [
            "$CONTENT_ROOT/Frameworks/generated_macos_developer_fmwk.framework/generated_macos_developer_fmwk",
            "$CONTENT_ROOT/Frameworks/generated_macos_developer_fmwk.framework/Resources/Info.plist",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_macos_extension_bundles_developer_framework".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:extension_with_developer_framework_in_frameworks",
        contains = [
            "$CONTENT_ROOT/Frameworks/generated_macos_developer_fmwk.framework/generated_macos_developer_fmwk",
            "$CONTENT_ROOT/Frameworks/generated_macos_developer_fmwk.framework/Resources/Info.plist",
        ],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
