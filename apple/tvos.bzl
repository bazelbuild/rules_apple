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
    "@build_bazel_rules_apple//apple/internal/testing:tvos_rules.bzl",
    _tvos_ui_test = "tvos_ui_test",
    _tvos_unit_test = "tvos_unit_test",
)
load(
    "@build_bazel_rules_apple//apple/internal:binary_support.bzl",
    "binary_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:tvos_rules.bzl",
    _tvos_application = "tvos_application",
    _tvos_extension = "tvos_extension",
    _tvos_framework = "tvos_framework",
)

def tvos_application(name, **kwargs):
    """Builds and bundles a tvOS application."""
    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.tvos),
        **kwargs
    )

    _tvos_application(
        name = name,
        dylibs = kwargs.get("frameworks", []),
        **bundling_args
    )

def tvos_extension(name, **kwargs):
    """Builds and bundles a tvOS extension."""
    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.tvos),
        **kwargs
    )

    _tvos_extension(
        name = name,
        dylibs = kwargs.get("frameworks", []),
        **bundling_args
    )

def tvos_framework(name, **kwargs):
    """Builds and bundles a tvOS dynamic framework."""

    # TODO(b/120861201): The linkopts macro additions here only exist because the Starlark linking
    # API does not accept extra linkopts and link inputs. With those, it will be possible to merge
    # these workarounds into the rule implementations.
    linkopts = kwargs.pop("linkopts", [])
    bundle_name = kwargs.get("bundle_name", name)
    linkopts += ["-install_name", "@rpath/%s.framework/%s" % (bundle_name, bundle_name)]
    kwargs["linkopts"] = linkopts

    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.tvos),
        **kwargs
    )

    # Remove any kwargs that shouldn't be passed to the underlying rule.
    bundling_args.pop("entitlements", None)

    _tvos_framework(
        name = name,
        dylibs = kwargs.get("frameworks", []),
        **bundling_args
    )

def tvos_unit_test(
        name,
        test_host = None,
        **kwargs):
    """Builds an tvOS XCTest test target."""

    # Discard binary_tags for now, as there is no apple_binary target any more to apply them to.
    # TODO(kaipi): Cleanup binary_tags for tests and remove this.
    kwargs.pop("binary_tags", None)

    # Discard any testonly attributes that may have been passed in kwargs. Since this is a test
    # rule, testonly should be a noop. Instead, force the add_entitlements_and_swift_linkopts method
    # to have testonly to True since it's always going to be a dependency of a test target. This can
    # be removed when we migrate the swift linkopts targets into the rule implementations.
    testonly = kwargs.pop("testonly", None)

    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.tvos),
        include_entitlements = False,
        testonly = True,
        **kwargs
    )

    bundle_loader = None
    if test_host:
        bundle_loader = test_host
    _tvos_unit_test(
        name = name,
        bundle_loader = bundle_loader,
        test_host = test_host,
        **bundling_args
    )

def tvos_ui_test(
        name,
        **kwargs):
    """Builds an tvOS XCUITest test target."""

    # Discard binary_tags for now, as there is no apple_binary target any more to apply them to.
    # TODO(kaipi): Cleanup binary_tags for tests and remove this.
    kwargs.pop("binary_tags", None)

    # Discard any testonly attributes that may have been passed in kwargs. Since this is a test
    # rule, testonly should be a noop. Instead, force the add_entitlements_and_swift_linkopts method
    # to have testonly to True since it's always going to be a dependency of a test target. This can
    # be removed when we migrate the swift linkopts targets into the rule implementations.
    testonly = kwargs.pop("testonly", None)

    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.tvos),
        include_entitlements = False,
        testonly = True,
        **kwargs
    )

    _tvos_ui_test(name = name, **bundling_args)
