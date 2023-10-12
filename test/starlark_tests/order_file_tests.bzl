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

"""order_file Starlark tests."""

load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//apple:linker.bzl", "apple_order_file")
load(
    "//test/starlark_tests/rules:apple_verification_test.bzl",
    "apple_verification_test",
)
load(
    "//test/starlark_tests/rules:order_files_tests_setup.bzl",
    "file_contents_test",
    "provider_contents_test",
)

visibility("private")

def _test_provider_contents(*, name, tags):
    provider_contents_subject = "{}_provider_contents_subject".format(name)

    order_file_a = "{}_a".format(name)
    write_file(
        name = order_file_a,
        out = "{}.order".format(order_file_a),
        content = ["content_a"],
    )
    order_file_b = "{}_b".format(name)
    write_file(
        name = order_file_b,
        out = "{}.order".format(order_file_b),
        content = ["content_b"],
    )

    apple_order_file(
        name = provider_contents_subject,
        deps = [
            ":{}".format(order_file_a),
            ":{}".format(order_file_b),
        ],
        tags = ["manual"],
    )

    provider_contents_test(
        name = "provider_contents_test",
        target_under_test = ":{}".format(provider_contents_subject),
        tags = tags,
        size = "small",
    )

def _test_file_contents(*, name, tags):
    file_contents_subject = "{}_file_contents_subject".format(name)

    order_file_a = "{}_a".format(name)
    write_file(
        name = order_file_a,
        out = "{}.order".format(order_file_a),
        content = [
            "content_a",
            "content_b",
        ],
    )
    order_file_b = "{}_b".format(name)
    write_file(
        name = order_file_b,
        out = "{}.order".format(order_file_b),
        content = [
            "content_b",
            "content_c",
        ],
    )

    apple_order_file(
        name = file_contents_subject,
        deps = [
            ":{}".format(order_file_a),
            ":{}".format(order_file_b),
        ],
        tags = ["manual"],
    )

    expected_order_file = "{}_expected".format(name)
    write_file(
        name = expected_order_file,
        out = "{}.order".format(expected_order_file),
        content = [
            "content_a",
            "content_b",
            "content_c",
            "",
        ],
    )

    file_contents_test(
        name = "file_contents_test",
        target_under_test = ":{}".format(file_contents_subject),
        expected = ":{}".format(expected_order_file),
        tags = tags,
        size = "small",
    )

def order_file_test_suite(*, name):
    """Test suite for order_file.

    Args:
      name: the base name to be used in things created by this macro
    """

    apple_verification_test(
        name = "{}_not_applied_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_minimal",
        verifier_script = "verifier_scripts/order_file_verifier.sh",
        env = {
            # No apple_order_file in ios_application deps, so order file shouldn't be applied.
            "FIRST_SYMBOL": ["dyld_stub_binder"],
            "ORDERED_SYMBOLS": ["dyld_stub_binder", "__mh_execute_header", "_dontCallMeMain", "_anotherFunctionMain", "_main"],
        },
        tags = [name],
        timeout = "short",
    )

    apple_verification_test(
        name = "{}_not_opt_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_order_file",
        verifier_script = "verifier_scripts/order_file_verifier.sh",
        env = {
            # Not "opt" build, so order file shouldn't be applied.
            "FIRST_SYMBOL": ["dyld_stub_binder"],
            "ORDERED_SYMBOLS": ["dyld_stub_binder", "__mh_execute_header", "_dontCallMeMain", "_anotherFunctionMain", "_main"],
        },
        tags = [name],
        timeout = "short",
    )

    apple_verification_test(
        name = "{}_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_order_file",
        verifier_script = "verifier_scripts/order_file_verifier.sh",
        env = {
            # Order file should be applied.
            "FIRST_SYMBOL": ["dyld_stub_binder"],
            "ORDERED_SYMBOLS": ["dyld_stub_binder", "__mh_execute_header", "_main", "_dontCallMeMain", "_anotherFunctionMain"],
        },
        tags = [name],
        timeout = "short",
        compilation_mode = "opt",
    )

    _test_provider_contents(
        name = "{}_provider_test".format(name),
        tags = [name],
    )

    _test_file_contents(
        name = "{}_contents_test".format(name),
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
