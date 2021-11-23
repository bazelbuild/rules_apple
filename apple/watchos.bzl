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
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal/testing:watchos_rules.bzl",
    _watchos_internal_ui_test_bundle = "watchos_internal_ui_test_bundle",
    _watchos_internal_unit_test_bundle = "watchos_internal_unit_test_bundle",
    _watchos_ui_test = "watchos_ui_test",
    _watchos_unit_test = "watchos_unit_test",
)
load(
    "@build_bazel_rules_apple//apple/internal:binary_support.bzl",
    "binary_support",
)

# Alias the internal rules when we load them. This lets the rules keep their
# original name in queries and logs since they collide with the wrapper macros.
load(
    "@build_bazel_rules_apple//apple/internal:watchos_rules.bzl",
    _watchos_application = "watchos_application",
    _watchos_dynamic_framework = "watchos_dynamic_framework",
    _watchos_extension = "watchos_extension",
    _watchos_static_framework = "watchos_static_framework",
)

def watchos_application(name, **kwargs):
    """Builds and bundles a watchOS application."""

    bundling_args = binary_support.add_entitlements(
        name,
        platform_type = str(apple_common.platform_type.watchos),
        product_type = apple_product_type.application,
        is_stub = True,
        **kwargs
    )

    _watchos_application(
        name = name,
        **bundling_args
    )

def watchos_extension(name, **kwargs):
    """Builds and bundles a watchOS extension."""
    bundling_args = binary_support.add_entitlements(
        name,
        platform_type = str(apple_common.platform_type.watchos),
        product_type = apple_product_type.app_extension,
        **kwargs
    )

    _watchos_extension(
        name = name,
        **bundling_args
    )

def watchos_dynamic_framework(name, **kwargs):
    # buildifier: disable=function-docstring-args
    """Builds and bundles a watchOS dynamic framework that is consumable by Xcode."""
    bundling_args = binary_support.add_entitlements(
        name,
        include_entitlements = False,
        platform_type = str(apple_common.platform_type.watchos),
        product_type = apple_product_type.framework,
        exported_symbols_lists = kwargs.pop("exported_symbols_lists", None),
        **kwargs
    )

    # Remove any kwargs that shouldn't be passed to the underlying rule.
    bundling_args.pop("entitlements", None)

    _watchos_dynamic_framework(
        name = name,
        extension_safe = kwargs.get("extension_safe"),
        **bundling_args
    )

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
