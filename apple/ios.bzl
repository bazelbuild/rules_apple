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
    "@build_bazel_rules_apple//apple/internal/testing:apple_test_assembler.bzl",
    "apple_test_assembler",
)
load(
    "@build_bazel_rules_apple//apple/internal/testing:ios_rules.bzl",
    _ios_ui_test = "ios_ui_test",
    _ios_ui_test_bundle = "ios_ui_test_bundle",
    _ios_unit_test = "ios_unit_test",
    _ios_unit_test_bundle = "ios_unit_test_bundle",
)
load(
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal:binary_support.bzl",
    "binary_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:ios_rules.bzl",
    _ios_application = "ios_application",
    _ios_extension = "ios_extension",
    _ios_framework = "ios_framework",
    _ios_imessage_application = "ios_imessage_application",
    _ios_imessage_extension = "ios_imessage_extension",
    _ios_static_framework = "ios_static_framework",
    _ios_sticker_pack_extension = "ios_sticker_pack_extension",
)

def ios_application(name, **kwargs):
    """Builds and bundles an iOS application."""
    bundling_args = binary_support.create_binary(
        name,
        str(apple_common.platform_type.ios),
        apple_product_type.application,
        **kwargs
    )

    _ios_application(
        name = name,
        **bundling_args
    )

def ios_extension(name, **kwargs):
    """Builds and bundles an iOS application extension."""
    bundling_args = binary_support.create_binary(
        name,
        str(apple_common.platform_type.ios),
        apple_product_type.app_extension,
        extension_safe = True,
        **kwargs
    )

    _ios_extension(
        name = name,
        **bundling_args
    )

def ios_framework(name, **kwargs):
    """Builds and bundles an iOS dynamic framework."""
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
        str(apple_common.platform_type.ios),
        apple_product_type.framework,
        binary_type = "dylib",
        suppress_entitlements = True,
        **kwargs
    )

    # Remove any kwargs that shouldn't be passed to the underlying rule.
    bundling_args.pop("entitlements", None)

    _ios_framework(
        name = name,
        extension_safe = kwargs.get("extension_safe"),
        **bundling_args
    )

def ios_static_framework(name, **kwargs):
    """Builds and bundles an iOS static framework for third-party distribution."""
    avoid_deps = kwargs.get("avoid_deps")
    deps = kwargs.get("deps")
    apple_static_library_name = "%s.apple_static_library" % name

    native.apple_static_library(
        name = apple_static_library_name,
        deps = deps,
        avoid_deps = avoid_deps,
        minimum_os_version = kwargs.get("minimum_os_version"),
        platform_type = str(apple_common.platform_type.ios),
        testonly = kwargs.get("testonly"),
        visibility = kwargs.get("visibility"),
    )

    passthrough_args = kwargs
    passthrough_args.pop("avoid_deps", None)
    passthrough_args.pop("deps", None)

    _ios_static_framework(
        name = name,
        deps = [apple_static_library_name],
        avoid_deps = [apple_static_library_name],
        **passthrough_args
    )

# TODO(b/118104491): Remove this macro and move the rule definition back to this file.
def ios_imessage_application(name, **kwargs):
    """Macro to preprocess entitlements for iMessage applications."""
    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.ios),
        is_stub = True,
        **kwargs
    )

    _ios_imessage_application(
        name = name,
        **bundling_args
    )

# TODO(b/118104491): Remove this macro and move the rule definition back to this file.
def ios_sticker_pack_extension(name, **kwargs):
    """Macro to preprocess entitlements for Sticker Pack extensions."""
    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.ios),
        is_stub = True,
        **kwargs
    )

    _ios_sticker_pack_extension(
        name = name,
        **bundling_args
    )

# TODO(b/118104491): Remove this macro and move the rule definition back to this file.
def ios_imessage_extension(name, **kwargs):
    """Macro to override the linkopts and preprocess entitlements for iMessage extensions."""
    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.ios),
        **kwargs
    )

    return _ios_imessage_extension(
        name = name,
        dylibs = bundling_args.get("frameworks", []),
        **bundling_args
    )

_DEFAULT_TEST_RUNNER = "@build_bazel_rules_apple//apple/testing/default_runner:ios_default_runner"

def ios_unit_test(name, **kwargs):
    runner = kwargs.pop("runner", _DEFAULT_TEST_RUNNER)
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _ios_unit_test_bundle,
        test_rule = _ios_unit_test,
        runner = runner,
        bundle_loader = kwargs.get("test_host"),
        dylibs = kwargs.get("frameworks"),
        **kwargs
    )

def ios_ui_test(name, **kwargs):
    runner = kwargs.pop("runner", _DEFAULT_TEST_RUNNER)
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _ios_ui_test_bundle,
        test_rule = _ios_ui_test,
        runner = runner,
        dylibs = kwargs.get("frameworks"),
        **kwargs
    )

def ios_unit_test_suite(name, **kwargs):
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _ios_unit_test_bundle,
        test_rule = _ios_unit_test,
        bundle_loader = kwargs.get("test_host"),
        dylibs = kwargs.get("frameworks"),
        **kwargs
    )

def ios_ui_test_suite(name, **kwargs):
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _ios_ui_test_bundle,
        test_rule = _ios_ui_test,
        dylibs = kwargs.get("frameworks"),
        **kwargs
    )
