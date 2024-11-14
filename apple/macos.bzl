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

"""Bazel rules for creating macOS applications and bundles."""

load(
    "@build_bazel_rules_apple//apple/internal:macos_rules.bzl",
    _macos_application = "macos_application",
    _macos_bundle = "macos_bundle",
    _macos_command_line_application = "macos_command_line_application",
    _macos_dylib = "macos_dylib",
    _macos_extension = "macos_extension",
    _macos_kernel_extension = "macos_kernel_extension",
    _macos_quick_look_plugin = "macos_quick_look_plugin",
    _macos_spotlight_importer = "macos_spotlight_importer",
    _macos_xpc_service = "macos_xpc_service",
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
    "@build_bazel_rules_apple//apple/internal/testing:macos_rules.bzl",
    _macos_internal_ui_test_bundle = "macos_internal_ui_test_bundle",
    _macos_internal_unit_test_bundle = "macos_internal_unit_test_bundle",
    _macos_ui_test = "macos_ui_test",
    _macos_unit_test = "macos_unit_test",
)

visibility("public")

macos_quick_look_plugin = _macos_quick_look_plugin
macos_spotlight_importer = _macos_spotlight_importer
macos_xpc_service = _macos_xpc_service

def macos_application(name, **kwargs):
    # buildifier: disable=function-docstring-args
    """Packages a macOS application."""
    bundling_args = dict(kwargs)
    features = bundling_args.pop("features", [])
    features.append("link_cocoa")

    _macos_application(
        name = name,
        features = features,
        **bundling_args
    )

def macos_bundle(name, **kwargs):
    # buildifier: disable=function-docstring-args
    """Packages a macOS loadable bundle."""
    bundling_args = dict(kwargs)
    features = bundling_args.pop("features", [])
    features.append("link_cocoa")

    _macos_bundle(
        name = name,
        features = features,
        **bundling_args
    )

def macos_kernel_extension(name, **kwargs):
    # buildifier: disable=function-docstring-args
    """Packages a macOS Kernel Extension."""
    bundling_args = dict(kwargs)
    features = bundling_args.pop("features", [])
    features.extend(["kernel_extension", "-lld_compatible"])

    _macos_kernel_extension(
        name = name,
        features = features,
        **bundling_args
    )

def macos_command_line_application(name, **kwargs):
    # buildifier: disable=function-docstring-args
    """Builds a macOS command line application."""

    binary_args = dict(kwargs)

    _macos_command_line_application(
        name = name,
        **binary_args
    )

def macos_dylib(name, **kwargs):
    # buildifier: disable=function-docstring-args
    """Builds a macOS dylib."""

    binary_args = dict(kwargs)

    _macos_dylib(
        name = name,
        **binary_args
    )

def macos_extension(name, **kwargs):
    # buildifier: disable=function-docstring-args
    """Packages a macOS Extension Bundle."""
    bundling_args = dict(kwargs)

    features = bundling_args.pop("features", [])
    features.append("link_cocoa")

    _macos_extension(
        name = name,
        features = features,
        **bundling_args
    )

def macos_unit_test(name, **kwargs):
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _macos_internal_unit_test_bundle,
        test_rule = _macos_unit_test,
        **kwargs
    )

def macos_ui_test(name, **kwargs):
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _macos_internal_ui_test_bundle,
        test_rule = _macos_ui_test,
        **kwargs
    )

macos_build_test = apple_build_test_rule(
    doc = """\
Test rule to check that the given library targets (Swift, Objective-C, C++)
build for macOS.

Typical usage:

```starlark
macos_build_test(
    name = "my_build_test",
    minimum_os_version = "10.14",
    targets = [
        "//some/package:my_library",
    ],
)
```
""",
    platform_type = "macos",
)
