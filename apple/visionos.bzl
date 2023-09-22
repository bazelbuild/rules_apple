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

"""Bazel rules for creating visionOS applications and bundles."""

load(
    "@build_bazel_rules_apple//apple/internal:visionos_rules.bzl",
    _visionos_application = "visionos_application",
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
    "@build_bazel_rules_apple//apple/internal/testing:visionos_rules.bzl",
    _visionos_internal_unit_test_bundle = "visionos_internal_unit_test_bundle",
    _visionos_unit_test = "visionos_unit_test",
)

visibility("public")

visionos_application = _visionos_application

def visionos_unit_test(name, **kwargs):
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _visionos_internal_unit_test_bundle,
        test_rule = _visionos_unit_test,
        **kwargs
    )

visionos_build_test = apple_build_test_rule(
    doc = """\
Test rule to check that the given library targets (Swift, Objective-C, C++)
build for visionOS.

Typical usage:

```starlark
visionos_build_test(
    name = "my_build_test",
    minimum_os_version = "1.0",
    targets = [
        "//some/package:my_library",
    ],
)
```
""",
    platform_type = "visionos",
)
