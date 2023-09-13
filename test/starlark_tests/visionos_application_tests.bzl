# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""visionos_application Starlark tests."""

load(
    "//apple/build_settings:build_settings.bzl",
    "build_settings_labels",
)
load(
    "//test/starlark_tests/rules:analysis_target_outputs_test.bzl",
    "make_analysis_target_outputs_test",
)
load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
)

visibility("private")

analysis_target_wip_feature_outputs_test = make_analysis_target_outputs_test(
    config_settings = {
        build_settings_labels.enable_wip_features: True,
    },
)

def visionos_application_test_suite(name):
    """Test suite for visionos_application.

    Args:
      name: the base name to be used in things created by this macro
    """

    analysis_target_wip_feature_outputs_test(
        name = "{}_default_app_bundle_outputs_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/visionos:app",
        expected_outputs = ["app.app"],
        tags = [
            name,
            "needs-xcode-latest-beta",
        ],
    )

    archive_contents_test(
        name = "{}_bundle_contents_test".format(name),
        build_settings = {
            build_settings_labels.enable_wip_features: "True",
        },
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/app",
            "$BUNDLE_ROOT/Assets.car",
            "$BUNDLE_ROOT/Info.plist",
        ],
        binary_test_file = "$BUNDLE_ROOT/app",
        target_under_test = "//test/starlark_tests/targets_under_test/visionos:app",
        tags = [
            name,
            "needs-xcode-latest-beta",
        ],
    )

    archive_contents_test(
        name = "{}_contains_solidstack_images_test".format(name),
        build_settings = {
            build_settings_labels.enable_wip_features: "True",
        },
        build_type = "simulator",
        contains = ["$BUNDLE_ROOT/Assets.car"],
        text_test_file = "$BUNDLE_ROOT/Assets.car",
        text_test_values = ["Bazel_logo.png"],
        target_under_test = "//test/starlark_tests/targets_under_test/visionos:app",
        tags = [
            name,
            "needs-xcode-latest-beta",
        ],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
