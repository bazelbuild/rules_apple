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

"""Bazel rules for creating watchOS applications and bundles."""

load(
    "@build_bazel_rules_apple//apple/internal:watchos_rules.bzl",
    _watchos_application = "watchos_application",
    _watchos_extension = "watchos_extension",
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
    "@build_bazel_rules_apple//apple/internal/testing:watchos_rules.bzl",
    _watchos_internal_ui_test_bundle = "watchos_internal_ui_test_bundle",
    _watchos_internal_unit_test_bundle = "watchos_internal_unit_test_bundle",
    _watchos_ui_test = "watchos_ui_test",
    _watchos_unit_test = "watchos_unit_test",
)

visibility("public")

watchos_application = _watchos_application
watchos_extension = _watchos_extension

def watchos_unit_test(name, **kwargs):
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _watchos_internal_unit_test_bundle,
        test_rule = _watchos_unit_test,
        **kwargs
    )

def watchos_ui_test(name, **kwargs):
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _watchos_internal_ui_test_bundle,
        test_rule = _watchos_ui_test,
        **kwargs
    )

watchos_build_test = apple_build_test_rule(
    doc = """\
Test rule to check that the given library targets (Swift, Objective-C, C++)
build for watchOS.

Typical usage:

```starlark
watchos_build_test(
    name = "my_build_test",
    minimum_os_version = "6.0",
    targets = [
        "//some/package:my_library",
    ],
)
```
""",
    platform_type = "watchos",
)
