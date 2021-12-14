# Copyright 2022 The Bazel Authors. All rights reserved.
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

"""apple_dynamic_xcframework_import and apple_static_xcframework_import Starlark tests."""

load(
    ":rules/analysis_target_outputs_test.bzl",
    "analysis_target_outputs_test",
)
load(
    ":rules/apple_verification_test.bzl",
    "apple_verification_test",
)

def apple_xcframework_import_test_suite(name = "apple_xcframework_import"):
    """Test suite for apple_dynamic_xcframework_import and apple_static_xcframework_import.

    Args:
        name: The name prefix for all the nested tests
    """

    analysis_target_outputs_test(
        name = "{}_dynamic_xcfw_import_ipa_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_dynamic_xcfmwk",
        expected_outputs = ["app_with_imported_dynamic_xcfmwk.ipa"],
        tags = [name],
    )

    apple_verification_test(
        name = "{}_imported_dynamic_xcfmwk_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_dynamic_xcfmwk",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    # TODO: Support importing xcframeworks with static archives
    analysis_target_outputs_test(
        name = "{}_static_xcfw_import_ipa_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_static_xcfmwk",
        expected_outputs = ["app_with_imported_static_xcfmwk.ipa"],
        tags = [name],
    )

    apple_verification_test(
        name = "{}_imported_static_xcfmwk_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_static_xcfmwk",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
