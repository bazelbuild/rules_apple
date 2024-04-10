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
    "@build_bazel_rules_apple//apple/internal:ios_rules.bzl",
    _ios_app_clip = "ios_app_clip",
    _ios_application = "ios_application",
    _ios_extension = "ios_extension",
    _ios_framework = "ios_framework",
    _ios_imessage_application = "ios_imessage_application",
    _ios_imessage_extension = "ios_imessage_extension",
    _ios_static_framework = "ios_static_framework",
)
load(
    "@build_bazel_rules_apple//apple/internal/testing:apple_test_assembler.bzl",
    "apple_test_assembler",
)
load(
    "@build_bazel_rules_apple//apple/internal/testing:build_test_rules.bzl",
    "apple_build_test_rule",
)
load(
    "@build_bazel_rules_apple//apple/internal/testing:ios_rules.bzl",
    _ios_internal_ui_test_bundle = "ios_internal_ui_test_bundle",
    _ios_internal_unit_test_bundle = "ios_internal_unit_test_bundle",
    _ios_ui_test = "ios_ui_test",
    _ios_unit_test = "ios_unit_test",
)

visibility("public")

ios_application = _ios_application
ios_app_clip = _ios_app_clip
ios_extension = _ios_extension
ios_framework = _ios_framework
ios_imessage_application = _ios_imessage_application
ios_imessage_extension = _ios_imessage_extension
ios_static_framework = _ios_static_framework

def ios_unit_test(name, **kwargs):
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _ios_internal_unit_test_bundle,
        test_rule = _ios_unit_test,
        **kwargs
    )

def ios_ui_test(name, **kwargs):
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _ios_internal_ui_test_bundle,
        test_rule = _ios_ui_test,
        **kwargs
    )

def ios_unit_test_suite(name, **kwargs):
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _ios_internal_unit_test_bundle,
        test_rule = _ios_unit_test,
        **kwargs
    )

def ios_ui_test_suite(name, **kwargs):
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _ios_internal_ui_test_bundle,
        test_rule = _ios_ui_test,
        **kwargs
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
