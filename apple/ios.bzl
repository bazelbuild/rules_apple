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

"""
# Bazel rules for creating iOS applications and bundles.
"""

load(
    "//apple/internal:ios_rules.bzl",
    _ios_app_clip = "ios_app_clip",
    _ios_application = "ios_application",
    _ios_dynamic_framework = "ios_dynamic_framework",
    _ios_extension = "ios_extension",
    _ios_framework = "ios_framework",
    _ios_imessage_application = "ios_imessage_application",
    _ios_imessage_extension = "ios_imessage_extension",
    _ios_kernel_extension = "ios_kernel_extension",
    _ios_static_framework = "ios_static_framework",
    _ios_sticker_pack_extension = "ios_sticker_pack_extension",
)
load(
    "//apple/internal:macro_factory.bzl",
    "macro_factory",
)
load(
    "//apple/internal/testing:apple_test_assembler.bzl",
    "apple_test_assembler",
)
load(
    "//apple/internal/testing:build_test_rules.bzl",
    "apple_build_test_rule",
)
load(
    "//apple/internal/testing:ios_rules.bzl",
    _ios_internal_ui_test_bundle = "ios_internal_ui_test_bundle",
    _ios_internal_unit_test_bundle = "ios_internal_unit_test_bundle",
    _ios_ui_test = "ios_ui_test",
    _ios_unit_test = "ios_unit_test",
)
load(
    "//apple/testing/default_runner:ios_test_runner.bzl",
    _ios_test_runner = "ios_test_runner",
)
load(
    "//apple/testing/default_runner:ios_xctestrun_runner.bzl",
    _ios_xctestrun_runner = "ios_xctestrun_runner",
)

# TODO(b/118104491): Remove these re-exports and move the rule definitions into this file.
ios_application = _ios_application
ios_app_clip = _ios_app_clip
ios_dynamic_framework = _ios_dynamic_framework
ios_extension = _ios_extension
ios_framework = _ios_framework
ios_imessage_application = _ios_imessage_application
ios_sticker_pack_extension = _ios_sticker_pack_extension
ios_imessage_extension = _ios_imessage_extension
ios_kernel_extension = _ios_kernel_extension
ios_static_framework = _ios_static_framework

ios_test_runner = _ios_test_runner
ios_xctestrun_runner = _ios_xctestrun_runner

_DEFAULT_TEST_RUNNER = Label("//apple/testing/default_runner:ios_default_runner")

def _ios_unit_test_impl(name, visibility, runner, **kwargs):
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _ios_internal_unit_test_bundle,
        test_rule = _ios_unit_test,
        runner = runner,
        visibility = visibility,
        **kwargs
    )

ios_unit_test = macro_factory.create_apple_test_macro(
    implementation = _ios_unit_test_impl,
    inherit_attrs = _ios_unit_test,
    default_runner = _DEFAULT_TEST_RUNNER,
    platform_attrs = "ios",
    doc = """
Builds and bundles an iOS Unit `.xctest` test bundle. Runs the tests using the
provided test runner when invoked with `bazel test`.

`ios_unit_test` targets can work in two modes: as app or library
tests. If the `test_host` attribute is set to an `ios_application` target, the
tests will run within that application's context. If no `test_host` is provided,
the tests will run outside the context of an iOS application. Because of this,
certain functionalities might not be present (e.g. UI layout, NSUserDefaults).
You can find more information about app and library testing for Apple platforms
[here](https://developer.apple.com/library/content/documentation/DeveloperTools/Conceptual/testing_with_xcode/chapters/03-testing_basics.html).

The `provisioning_profile` attribute needs to be set to run the test on a real device.

To run the same test on multiple simulators/devices see
[ios_unit_test_suite](#ios_unit_test_suite).

The following is a list of the `ios_unit_test` specific attributes; for a list
of the attributes inherited by all test rules, please check the
[Bazel documentation](https://bazel.build/reference/be/common-definitions#common-attributes-tests).
""",
)

def _ios_ui_test_impl(name, visibility, runner, **kwargs):
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _ios_internal_ui_test_bundle,
        test_rule = _ios_ui_test,
        runner = runner,
        visibility = visibility,
        **kwargs
    )

ios_ui_test = macro_factory.create_apple_test_macro(
    implementation = _ios_ui_test_impl,
    inherit_attrs = _ios_ui_test,
    default_runner = _DEFAULT_TEST_RUNNER,
    platform_attrs = "ios",
    doc = """
iOS UI Test rule.

Builds and bundles an iOS UI `.xctest` test bundle. Runs the tests using the
provided test runner when invoked with `bazel test`.

The `provisioning_profile` attribute needs to be set to run the test on a real device.

To run the same test on multiple simulators/devices see
[ios_ui_test_suite](#ios_ui_test_suite).

The following is a list of the `ios_ui_test` specific attributes; for a list
of the attributes inherited by all test rules, please check the
[Bazel documentation](https://bazel.build/reference/be/common-definitions#common-attributes-tests).
""",
)

def _ios_unit_test_suite_impl(name, visibility, runners, **kwargs):
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _ios_internal_unit_test_bundle,
        test_rule = _ios_unit_test,
        runners = runners,
        visibility = visibility,
        **kwargs
    )

ios_unit_test_suite = macro_factory.create_apple_test_suite_macro(
    implementation = _ios_unit_test_suite_impl,
    inherit_attrs = _ios_unit_test,
    platform_attrs = "ios",
    doc = """
Generates a [test_suite] containing an [ios_unit_test] for each of the given `runners`.

`ios_unit_test_suite` takes the same parameters as [ios_unit_test], except `runner` is replaced by `runners`.

[test_suite]: https://docs.bazel.build/versions/master/be/general.html#test_suite
[ios_unit_test]: #ios_unit_test
""",
)

def _ios_ui_test_suite_impl(name, visibility, runners, **kwargs):
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _ios_internal_ui_test_bundle,
        test_rule = _ios_ui_test,
        runners = runners,
        visibility = visibility,
        **kwargs
    )

ios_ui_test_suite = macro_factory.create_apple_test_suite_macro(
    implementation = _ios_ui_test_suite_impl,
    inherit_attrs = _ios_ui_test,
    platform_attrs = "ios",
    doc = """
Generates a [test_suite] containing an [ios_ui_test] for each of the given `runners`.

`ios_ui_test_suite` takes the same parameters as [ios_ui_test], except `runner` is replaced by `runners`.

[test_suite]: https://docs.bazel.build/versions/master/be/general.html#test_suite
[ios_ui_test]: #ios_ui_test
""",
)

ios_build_test = apple_build_test_rule(
    doc = """\
Test rule to check that the given library targets (Swift, Objective-C, C++)
build for iOS.

Typical usage:

```starlark
ios_build_test(
    name = "my_build_test",
    minimum_os_version = "12.0",
    targets = [
        "//some/package:my_library",
    ],
)
```
""",
    platform_type = "ios",
)
