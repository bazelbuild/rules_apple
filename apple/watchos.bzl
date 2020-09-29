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
    "@build_bazel_rules_apple//apple/internal/testing:build_test_rules.bzl",
    "apple_build_test_rule",
)
load(
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
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
    _watchos_extension = "watchos_extension",
    _watchos_dynamic_framework = "watchos_dynamic_framework",
)

def watchos_application(name, **kwargs):
    """Builds and bundles a watchOS application."""

    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
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
    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
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
    """Builds and bundles a watchOS dynamic framework."""
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
        str(apple_common.platform_type.watchos),
        apple_product_type.framework,
        binary_type = "dylib",
        suppress_entitlements = True,
        **kwargs
    )

    # Remove any kwargs that shouldn't be passed to the underlying rule.
    bundling_args.pop("entitlements", None)

    _watchos_dynamic_framework(
        name = name,
        extension_safe = kwargs.get("extension_safe"),
        **bundling_args
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
