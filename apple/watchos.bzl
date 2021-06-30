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
load(
    "@build_bazel_rules_apple//apple/internal:watchos_rules.bzl",
    _watchos_application = "watchos_application",
    _watchos_dynamic_framework = "watchos_dynamic_framework",
    _watchos_extension = "watchos_extension",
    _watchos_static_framework = "watchos_static_framework",
)

# TODO(b/118104491): Remove these re-exports and move the rule definitions into this file.
watchos_application = _watchos_application
watchos_dynamic_framework = _watchos_dynamic_framework
watchos_extension = _watchos_extension

_DEFAULT_TEST_RUNNER = "@build_bazel_rules_apple//apple/testing/default_runner:watchos_default_runner"

def watchos_unit_test(name, **kwargs):
    runner = kwargs.pop("runner", _DEFAULT_TEST_RUNNER)
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _watchos_internal_unit_test_bundle,
        test_rule = _watchos_unit_test,
        runner = runner,
        bundle_loader = kwargs.get("test_host"),
        **kwargs
    )

def watchos_ui_test(name, **kwargs):
    runner = kwargs.pop("runner", _DEFAULT_TEST_RUNNER)
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _watchos_internal_ui_test_bundle,
        test_rule = _watchos_ui_test,
        runner = runner,
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

def watchos_static_framework(name, **kwargs):
    # buildifier: disable=function-docstring-args
    """Builds and bundles a watchOS static framework for third-party distribution."""
    avoid_deps = kwargs.get("avoid_deps")
    deps = kwargs.get("deps")
    apple_static_library_name = "%s.apple_static_library" % name

    native.apple_static_library(
        name = apple_static_library_name,
        deps = deps,
        avoid_deps = avoid_deps,
        minimum_os_version = kwargs.get("minimum_os_version"),
        platform_type = str(apple_common.platform_type.watchos),
        tags = kwargs.get("tags"),
        visibility = kwargs.get("visibility"),
    )

    passthrough_args = kwargs
    passthrough_args.pop("avoid_deps", None)
    passthrough_args.pop("deps", None)

    _watchos_static_framework(
        name = name,
        deps = [apple_static_library_name],
        avoid_deps = [apple_static_library_name],
        **passthrough_args
    )
