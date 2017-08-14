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

"""Rule implementations for creating iOS applications and bundles.

DO NOT load this file directly; use the macro in
@build_bazel_rules_apple//apple:ios.bzl instead. Bazel rules receive their name at
*definition* time based on the name of the global to which they are assigned.
We want the user to call macros that have the same name, to get automatic
binary creation, entitlements support, and other features--which requires a
wrapping macro because rules cannot invoke other rules.
"""

load(
    "@build_bazel_rules_apple//apple/bundling:apple_bundling_aspect.bzl",
    "apple_bundling_aspect",
)
load(
    "@build_bazel_rules_apple//apple/bundling:binary_support.bzl",
    "binary_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:bundler.bzl",
    "bundler",
)
load(
    "@build_bazel_rules_apple//apple/bundling:bundling_support.bzl",
    "bundling_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:product_support.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/bundling:rule_factory.bzl",
    "rule_factory",
)
load(
    "@build_bazel_rules_apple//apple/bundling:run_actions.bzl",
    "run_actions",
)
load(
    "@build_bazel_rules_apple//apple/bundling:test_support.bzl",
    "test_support",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "AppleResourceSet",
    "IosApplicationBundleInfo",
    "IosExtensionBundleInfo",
    "IosFrameworkBundleInfo",
    "WatchosApplicationBundleInfo",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "merge_dictionaries",
)


def _ios_application_impl(ctx):
  """Implementation of the ios_application Skylark rule."""

  # Collect asset catalogs, launch images, and the launch storyboard, if any are
  # present.
  additional_resource_sets = []
  additional_resources = depset(ctx.files.app_icons + ctx.files.launch_images)
  launch_storyboard = ctx.file.launch_storyboard
  if launch_storyboard:
    additional_resources += [launch_storyboard]
  if additional_resources:
    additional_resource_sets.append(AppleResourceSet(
        resources=additional_resources,
    ))

  # If a settings bundle was provided, pass in its files as if they were
  # objc_bundle imports, but forcing the "Settings.bundle" name.
  settings_bundle = ctx.attr.settings_bundle
  if settings_bundle:
    additional_resource_sets.append(AppleResourceSet(
        bundle_dir="Settings.bundle",
        objc_bundle_imports=[
            bf.file for bf in settings_bundle.objc.bundle_file
        ]
    ))

  embedded_bundles = [
      bundling_support.embedded_bundle(
          "PlugIns", extension[AppleBundleInfo], verify_bundle_id=True)
      for extension in ctx.attr.extensions
  ] + [
      bundling_support.embedded_bundle(
          "Frameworks", framework[AppleBundleInfo], verify_bundle_id=False)
      for framework in ctx.attr.frameworks
  ]

  watch_app = ctx.attr.watch_application
  if watch_app:
    embedded_bundles.append(bundling_support.embedded_bundle(
        "Watch", watch_app[AppleBundleInfo], verify_bundle_id=True))

  binary_artifact = binary_support.get_binary_provider(
      ctx, apple_common.AppleExecutableBinary).binary
  additional_providers, legacy_providers, additional_outputs = bundler.run(
      ctx,
      "IosApplicationArchive", "iOS application",
      ctx.attr.bundle_id,
      binary_artifact=binary_artifact,
      additional_resource_sets=additional_resource_sets,
      embedded_bundles=embedded_bundles,
  )

  if ctx.attr.deps:
    legacy_providers["xctest_app"] = test_support.new_xctest_app_provider(ctx)

  runfiles = run_actions.start_simulator(ctx)

  return struct(
      files=additional_outputs,
      instrumented_files=struct(dependency_attributes=["binary"]),
      runfiles=ctx.runfiles(files=runfiles),
      providers=[
          IosApplicationBundleInfo(),
      ] + additional_providers,
      **legacy_providers
  )


ios_application = rule_factory.make_bundling_rule(
    _ios_application_impl,
    additional_attrs={
        "app_icons": attr.label_list(allow_files=True),
        "dedupe_unbundled_resources": attr.bool(default=True),
        "extensions": attr.label_list(
            providers=[[AppleBundleInfo, IosExtensionBundleInfo]],
        ),
        "frameworks": attr.label_list(
            providers=[[AppleBundleInfo, IosFrameworkBundleInfo]],
        ),
        "launch_images": attr.label_list(allow_files=True),
        "launch_storyboard": attr.label(
            allow_files=[".storyboard", ".xib"],
            single_file=True,
        ),
        "settings_bundle": attr.label(providers=[["objc"]]),
        "watch_application": attr.label(
            providers=[[AppleBundleInfo, WatchosApplicationBundleInfo]],
        ),
    },
    archive_extension=".ipa",
    code_signing=rule_factory.code_signing(".mobileprovision"),
    device_families=rule_factory.device_families(allowed=["iphone", "ipad"]),
    executable=True,
    path_formats=rule_factory.simple_path_formats(
        path_in_archive_format="Payload/%s"
    ),
    platform_type=apple_common.platform_type.ios,
    product_type=rule_factory.product_type(apple_product_type.application),
)


def _ios_extension_impl(ctx):
  """Implementation of the ios_extension Skylark rule."""

  # Collect asset catalogs and launch images if any are present.
  additional_resource_sets = []
  additional_resources = depset(ctx.files.app_icons + ctx.files.asset_catalogs)
  if additional_resources:
    additional_resource_sets.append(AppleResourceSet(
        resources=additional_resources,
    ))

  binary_artifact = binary_support.get_binary_provider(
      ctx, apple_common.AppleExecutableBinary).binary
  additional_providers, legacy_providers, additional_outputs = bundler.run(
      ctx,
      "IosExtensionArchive", "iOS extension",
      ctx.attr.bundle_id,
      binary_artifact=binary_artifact,
      additional_resource_sets=additional_resource_sets,
  )

  return struct(
      files=additional_outputs,
      providers=[
          IosExtensionBundleInfo(),
      ] + additional_providers,
      **legacy_providers
  )


ios_extension = rule_factory.make_bundling_rule(
    _ios_extension_impl,
    additional_attrs={
        "app_icons": attr.label_list(allow_files=True),
        "asset_catalogs": attr.label_list(allow_files=True),
        "frameworks": attr.label_list(
            providers=[[AppleBundleInfo, IosFrameworkBundleInfo]],
        ),
        "_extension_safe": attr.bool(default=True),
    },
    archive_extension=".zip",
    code_signing=rule_factory.code_signing(".mobileprovision"),
    device_families=rule_factory.device_families(allowed=["iphone", "ipad"]),
    needs_pkginfo=False,
    path_formats=rule_factory.simple_path_formats(path_in_archive_format="%s"),
    platform_type=apple_common.platform_type.ios,
    product_type=rule_factory.product_type(apple_product_type.app_extension),
    propagates_frameworks=True,
)


def _ios_framework_impl(ctx):
  """Implementation of the ios_framework Skylark rule."""
  binary_artifact = binary_support.get_binary_provider(ctx, apple_common.AppleDylibBinary).binary
  bundlable_binary = struct(file=binary_artifact,
                            bundle_path=bundling_support.bundle_name(ctx))
  prefixed_hdr_files = []
  for hdr_provider in ctx.attr.hdrs:
    for hdr_file in hdr_provider.files:
      prefixed_hdr_files.append(bundling_support.header_prefix(hdr_file))

  binary_artifact = binary_support.get_binary_provider(
      ctx, apple_common.AppleDylibBinary).binary
  additional_providers, legacy_providers, additional_outputs = bundler.run(
      ctx,
      "IosFrameworkArchive", "iOS framework",
      ctx.attr.bundle_id,
      binary_artifact=binary_artifact,
      additional_bundlable_files=prefixed_hdr_files,
      framework_files=prefixed_hdr_files + [bundlable_binary],
      is_dynamic_framework=True,
  )

  return struct(
      files=additional_outputs,
      providers=[
          IosFrameworkBundleInfo(),
      ] + additional_providers,
      **legacy_providers
  )


ios_framework = rule_factory.make_bundling_rule(
    _ios_framework_impl,
    additional_attrs={
        "dedupe_unbundled_resources": attr.bool(default=True),
        "extension_safe": attr.bool(default=False),
        "frameworks": attr.label_list(
            providers=[[AppleBundleInfo, IosFrameworkBundleInfo]],
        ),
        "hdrs": attr.label_list(allow_files=[".h"]),
    },
    archive_extension=".zip",
    binary_providers=[apple_common.AppleDylibBinary],
    code_signing=rule_factory.code_signing(skip_signing=True),
    device_families=rule_factory.device_families(allowed=["iphone", "ipad"]),
    needs_pkginfo=False,
    path_formats=rule_factory.simple_path_formats(path_in_archive_format="%s"),
    platform_type=apple_common.platform_type.ios,
    product_type=rule_factory.product_type(apple_product_type.framework),
    propagates_frameworks=True,
)
