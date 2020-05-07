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
    "@build_bazel_rules_apple//apple/internal:binary_support.bzl",
    "binary_support",
)

# Alias the internal rules when we load them. This lets the rules keep their
# original name in queries and logs since they collide with the wrapper macros.
load(
    "@build_bazel_rules_apple//apple/internal:watchos_rules.bzl",
    _watchos_application = "watchos_application",
    _watchos_extension = "watchos_extension",
    _watchos_framework = "watchos_framework",
    _watchos_static_framework = "watchos_static_framework",
)

def watchos_application(name, **kwargs):
    """Builds and bundles a watchOS application."""

    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.watchos),
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
        **kwargs
    )

    _watchos_extension(
        name = name,
        **bundling_args
    )

def watchos_framework(name, **kwargs):
    # buildifier: disable=function-docstring-args
    """Builds and bundles a watchOS dynamic framework."""

    # TODO(b/120861201): The linkopts macro additions here only exist because the Starlark linking
    # API does not accept extra linkopts and link inputs. With those, it will be possible to merge
    # these workarounds into the rule implementations.
    linkopts = kwargs.pop("linkopts", [])
    bundle_name = kwargs.get("bundle_name", name)
    linkopts += ["-install_name", "@rpath/%s.framework/%s" % (bundle_name, bundle_name)]
    kwargs["linkopts"] = linkopts

    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.watchos),
        **kwargs
    )

    # Remove any kwargs that shouldn't be passed to the underlying rule.
    bundling_args.pop("entitlements", None)

    _watchos_framework(
        name = name,
        dylibs = kwargs.get("frameworks", []),
        **bundling_args
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
