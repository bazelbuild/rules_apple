# Copyright 2018 The Bazel Authors. All rights reserved.
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

"""Proxy file for referencing Apple bundler bundling tasks."""

load(
    "@build_bazel_rules_apple//apple/internal/bundling_tasks:app_assets_validation.bzl",
    _app_assets_validation_bundling_task = "app_assets_validation_bundling_task",
)
load(
    "@build_bazel_rules_apple//apple/internal/bundling_tasks:app_intents_metadata_bundle.bzl",
    _app_intents_metadata_bundle_bundling_task = "app_intents_metadata_bundle_bundling_task",
)
load(
    "@build_bazel_rules_apple//apple/internal/bundling_tasks:apple_bundle_info.bzl",
    _apple_bundle_info_bundling_task = "apple_bundle_info_bundling_task",
)
load(
    "@build_bazel_rules_apple//apple/internal/bundling_tasks:binary.bzl",
    _binary_bundling_task = "binary_bundling_task",
)
load(
    "@build_bazel_rules_apple//apple/internal/bundling_tasks:child_bundle_info_validation.bzl",
    _child_bundle_info_validation_bundling_task = "child_bundle_info_validation_bundling_task",
)
load(
    "@build_bazel_rules_apple//apple/internal/bundling_tasks:clang_rt_dylibs.bzl",
    _clang_rt_dylibs_bundling_task = "clang_rt_dylibs_bundling_task",
)
load(
    "@build_bazel_rules_apple//apple/internal/bundling_tasks:codesigning_dossier.bzl",
    _codesigning_dossier_bundling_task = "codesigning_dossier_bundling_task",
)
load(
    "@build_bazel_rules_apple//apple/internal/bundling_tasks:debug_symbols.bzl",
    _debug_symbols_bundling_task = "debug_symbols_bundling_task",
)
load(
    "@build_bazel_rules_apple//apple/internal/bundling_tasks:embedded_bundles.bzl",
    _embedded_bundles_bundling_task = "embedded_bundles_bundling_task",
)
load(
    "@build_bazel_rules_apple//apple/internal/bundling_tasks:extension_safe_validation.bzl",
    _extension_safe_validation_bundling_task = "extension_safe_validation_bundling_task",
)
load(
    "@build_bazel_rules_apple//apple/internal/bundling_tasks:framework_header_modulemap.bzl",
    _framework_header_modulemap_bundling_task = "framework_header_modulemap_bundling_task",
)
load(
    "@build_bazel_rules_apple//apple/internal/bundling_tasks:framework_headers.bzl",
    _framework_headers_bundling_task = "framework_headers_bundling_task",
)
load(
    "@build_bazel_rules_apple//apple/internal/bundling_tasks:framework_import.bzl",
    _framework_import_bundling_task = "framework_import_bundling_task",
)
load(
    "@build_bazel_rules_apple//apple/internal/bundling_tasks:framework_provider.bzl",
    _framework_provider_bundling_task = "framework_provider_bundling_task",
)
load(
    "@build_bazel_rules_apple//apple/internal/bundling_tasks:macos_additional_contents.bzl",
    _macos_additional_contents_bundling_task = "macos_additional_contents_bundling_task",
)
load(
    "@build_bazel_rules_apple//apple/internal/bundling_tasks:provisioning_profile.bzl",
    _provisioning_profile_bundling_task = "provisioning_profile_bundling_task",
)
load(
    "@build_bazel_rules_apple//apple/internal/bundling_tasks:resources.bzl",
    _resources_bundling_task = "resources_bundling_task",
)
load(
    "@build_bazel_rules_apple//apple/internal/bundling_tasks:settings_bundle.bzl",
    _settings_bundle_bundling_task = "settings_bundle_bundling_task",
)
load(
    "@build_bazel_rules_apple//apple/internal/bundling_tasks:swift_dylibs.bzl",
    _swift_dylibs_bundling_task = "swift_dylibs_bundling_task",
)
load(
    "@build_bazel_rules_apple//apple/internal/bundling_tasks:swift_framework.bzl",
    _swift_framework_bundling_task = "swift_framework_bundling_task",
)
load(
    "@build_bazel_rules_apple//apple/internal/bundling_tasks:watchos_stub.bzl",
    _watchos_stub_bundling_task = "watchos_stub_bundling_task",
)

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

bundling_tasks = struct(
    app_assets_validation = _app_assets_validation_bundling_task,
    app_intents_metadata_bundle = _app_intents_metadata_bundle_bundling_task,
    apple_bundle_info = _apple_bundle_info_bundling_task,
    binary = _binary_bundling_task,
    child_bundle_info_validation = _child_bundle_info_validation_bundling_task,
    clang_rt_dylibs = _clang_rt_dylibs_bundling_task,
    codesigning_dossier = _codesigning_dossier_bundling_task,
    debug_symbols = _debug_symbols_bundling_task,
    embedded_bundles = _embedded_bundles_bundling_task,
    extension_safe_validation = _extension_safe_validation_bundling_task,
    framework_import = _framework_import_bundling_task,
    framework_header_modulemap = _framework_header_modulemap_bundling_task,
    framework_headers = _framework_headers_bundling_task,
    framework_provider = _framework_provider_bundling_task,
    macos_additional_contents = _macos_additional_contents_bundling_task,
    provisioning_profile = _provisioning_profile_bundling_task,
    resources = _resources_bundling_task,
    settings_bundle = _settings_bundle_bundling_task,
    swift_dylibs = _swift_dylibs_bundling_task,
    swift_framework = _swift_framework_bundling_task,
    watchos_stub = _watchos_stub_bundling_task,
)
