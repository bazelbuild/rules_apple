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

"""Bazel rules for creating iOS applications and bundles."""

load(
    "@build_bazel_rules_apple//apple/internal/testing:ios_rules.bzl",
    _ios_ui_test = "ios_ui_test",
    _ios_unit_test = "ios_unit_test",
)
load(
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal:binary_support.bzl",
    "binary_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:ios_rules.bzl",
    _ios_application = "ios_application",
    _ios_extension = "ios_extension",
    _ios_framework = "ios_framework",
    _ios_imessage_application = "ios_imessage_application",
    _ios_imessage_extension = "ios_imessage_extension",
    _ios_static_framework = "ios_static_framework",
    _ios_sticker_pack_extension = "ios_sticker_pack_extension",
)

def ios_application(name, **kwargs):
    """Builds and bundles an iOS application."""
    bundling_args = binary_support.create_binary(
        name,
        str(apple_common.platform_type.ios),
        apple_product_type.application,
        **kwargs
    )

    _ios_application(
        name = name,
        **bundling_args
    )

def ios_extension(name, **kwargs):
    """Builds and bundles an iOS application extension."""
    bundling_args = binary_support.create_binary(
        name,
        str(apple_common.platform_type.ios),
        apple_product_type.app_extension,
        extension_safe = True,
        **kwargs
    )

    _ios_extension(
        name = name,
        **bundling_args
    )

def ios_framework(name, **kwargs):
    """Builds and bundles an iOS dynamic framework."""
    linkopts = kwargs.get("linkopts", [])

    # Can't read this from the descriptor, since it requires the bundle name as argument. Once this
    # is migrated to be a rule, we can move this to the rule implementation.
    bundle_name = kwargs.get("bundle_name", name)
    linkopts += [
        "-install_name",
        "@rpath/%s.framework/%s" % (bundle_name, bundle_name),
    ]
    kwargs["linkopts"] = linkopts

    # Link the executable from any library deps and sources provided.
    bundling_args = binary_support.create_binary(
        name,
        str(apple_common.platform_type.ios),
        apple_product_type.framework,
        binary_type = "dylib",
        suppress_entitlements = True,
        **kwargs
    )

    # Remove any kwargs that shouldn't be passed to the underlying rule.
    bundling_args.pop("entitlements", None)

    _ios_framework(
        name = name,
        extension_safe = kwargs.get("extension_safe"),
        **bundling_args
    )

def ios_static_framework(name, **kwargs):
    """Builds and bundles an iOS static framework for third-party distribution."""
    avoid_deps = kwargs.get("avoid_deps")
    deps = kwargs.get("deps")
    apple_static_library_name = "%s.apple_static_library" % name

    native.apple_static_library(
        name = apple_static_library_name,
        deps = deps,
        avoid_deps = avoid_deps,
        minimum_os_version = kwargs.get("minimum_os_version"),
        platform_type = str(apple_common.platform_type.ios),
        testonly = kwargs.get("testonly"),
        visibility = kwargs.get("visibility"),
    )

    passthrough_args = kwargs
    passthrough_args.pop("avoid_deps", None)
    passthrough_args.pop("deps", None)

    _ios_static_framework(
        name = name,
        deps = [apple_static_library_name],
        avoid_deps = [apple_static_library_name],
        **passthrough_args
    )

def ios_ui_test(name, **kwargs):
    """Builds an XCUITest test bundle and tests it using the provided runner."""
    _ios_ui_test(name = name, **kwargs)

def ios_ui_test_suite(name, runners = [], tags = [], **kwargs):
    """Builds an XCUITest test suite with the given runners.

    Args:
      name: The name of the target.
      runners: The list of runner targets that contain the logic of how the tests
          should be executed. This target needs to provide an AppleTestRunnerInfo
          provider. Required (minimum of 2 runners).
      tags: List of arbitrary text tags to be added to the test_suite. Tags may be
          any valid string. Optional. Defaults to an empty list.
      **kwargs: All arguments you would normally provide to an ios_unit_test
          target.
    """
    if len(runners) < 2:
        fail("You need to specify at least 2 runners to create a test suite.")
    tests = []
    for runner in runners:
        test_name = "_".join([name, runner.partition(":")[2]])
        tests.append(":" + test_name)
        ios_ui_test(name = test_name, runner = runner, tags = tags, **kwargs)
    native.test_suite(
        name = name,
        tests = tests,
        tags = tags,
        visibility = kwargs.get("visibility"),
    )

def ios_unit_test(name, **kwargs):
    """Builds an XCTest unit test bundle and tests it using the provided runner."""
    _ios_unit_test(name = name, **kwargs)

def ios_unit_test_suite(name, runners = [], tags = [], **kwargs):
    """Builds an XCTest unit test suite with the given runners."""
    if len(runners) < 2:
        fail("You need to specify at least 2 runners to create a test suite.")
    tests = []
    for runner in runners:
        test_name = "_".join([name, runner.partition(":")[2]])
        tests.append(":" + test_name)
        ios_unit_test(name = test_name, runner = runner, tags = tags, **kwargs)
    native.test_suite(
        name = name,
        tests = tests,
        tags = tags,
        visibility = kwargs.get("visibility"),
    )

# TODO(b/118104491): Remove this macro and move the rule definition back to this file.
def ios_imessage_application(name, **kwargs):
    """Macro to preprocess entitlements for iMessage applications."""
    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.ios),
        is_stub = True,
        **kwargs
    )

    _ios_imessage_application(
        name = name,
        **bundling_args
    )

# TODO(b/118104491): Remove this macro and move the rule definition back to this file.
def ios_sticker_pack_extension(name, **kwargs):
    """Macro to preprocess entitlements for Sticker Pack extensions."""
    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.ios),
        is_stub = True,
        **kwargs
    )

    _ios_sticker_pack_extension(
        name = name,
        **bundling_args
    )

# TODO(b/118104491): Remove this macro and move the rule definition back to this file.
def ios_imessage_extension(name, **kwargs):
    """Macro to override the linkopts and preprocess entitlements for iMessage extensions."""
    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.ios),
        **kwargs
    )

    return _ios_imessage_extension(
        name = name,
        dylibs = bundling_args.get("frameworks", []),
        **bundling_args
    )
