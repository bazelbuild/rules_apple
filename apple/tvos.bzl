# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Bazel rules for creating tvOS applications and bundles."""

load(
    "@build_bazel_rules_apple//apple/internal:tvos_rules.bzl",
    _tvos_application = "tvos_application",
    _tvos_extension = "tvos_extension",
    _tvos_framework = "tvos_framework",
    _tvos_static_framework = "tvos_static_framework",
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
    "@build_bazel_rules_apple//apple/internal/testing:tvos_rules.bzl",
    _tvos_internal_ui_test_bundle = "tvos_internal_ui_test_bundle",
    _tvos_internal_unit_test_bundle = "tvos_internal_unit_test_bundle",
    _tvos_ui_test = "tvos_ui_test",
    _tvos_unit_test = "tvos_unit_test",
)

visibility("public")

tvos_application = _tvos_application
tvos_extension = _tvos_extension
tvos_framework = _tvos_framework
tvos_static_framework = _tvos_static_framework

def tvos_unit_test(name, **kwargs):
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _tvos_internal_unit_test_bundle,
        test_rule = _tvos_unit_test,
        **kwargs
    )

def tvos_ui_test(name, **kwargs):
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _tvos_internal_ui_test_bundle,
        test_rule = _tvos_ui_test,
        **kwargs
    )

tvos_build_test = apple_build_test_rule(
    doc = """\
Test rule to check that the given library targets (Swift, Objective-C, C++)
build for tvOS.

Typical usage:

```starlark
tvos_build_test(
    name = "my_build_test",
    minimum_os_version = "12.0",
    targets = [
        "//some/package:my_library",
    ],
)
```
""",
    platform_type = "tvos",
)
