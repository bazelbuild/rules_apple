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

"""Rule implementations for creating watchOS applications and bundles.

DO NOT load this file directly; use the macro in
@build_bazel_rules_apple//apple:watchos.bzl instead. Bazel rules receive their name at
*definition* time based on the name of the global to which they are assigned.
We want the user to call macros that have the same name, to get automatic
binary creation, entitlements support, and other features--which requires a
wrapping macro because rules cannot invoke other rules.
"""

load("@build_bazel_rules_apple//apple/bundling:binary_support.bzl", "binary_support")
load("@build_bazel_rules_apple//apple/bundling:bundler.bzl", "bundler")
load("@build_bazel_rules_apple//apple/bundling:bundling_support.bzl",
     "bundling_support")
load("@build_bazel_rules_apple//apple/bundling:product_support.bzl",
     "apple_product_type")
load("@build_bazel_rules_apple//apple/bundling:rule_factory.bzl",
     "rule_factory")
load("@build_bazel_rules_apple//apple/bundling:run_actions.bzl", "run_actions")
load("@build_bazel_rules_apple//apple:providers.bzl",
     "AppleBundleInfo",
     "AppleResourceSet",
     "WatchosApplicationBundleInfo",
     "WatchosExtensionBundleInfo")


def _watchos_application_impl(ctx):
  """Implementation of the watchos_application Skylark rule."""

  app_icons = ctx.files.app_icons
  if app_icons:
    bundling_support.ensure_single_asset_type(
        app_icons, ["appiconset"], "app_icons")

  # Collect asset catalogs and storyboards, if any are present.
  additional_resource_sets = []
  additional_resources = depset(app_icons + ctx.files.storyboards)
  if additional_resources:
    additional_resource_sets.append(AppleResourceSet(
        resources=additional_resources,
    ))

  embedded_bundles = []

  ext = ctx.attr.extension
  if ext:
    embedded_bundles.append(bundling_support.embedded_bundle(
        "PlugIns", ext, verify_has_child_plist=True,
        parent_bundle_id_reference=[
            "NSExtension", "NSExtensionAttributes", "WKAppBundleIdentifier"]))

  binary_artifact = binary_support.create_stub_binary(ctx)

  additional_providers, legacy_providers, additional_outputs = bundler.run(
      ctx,
      "WatchosApplicationArchive", "watchOS application",
      ctx.attr.bundle_id,
      additional_resource_sets=additional_resource_sets,
      binary_artifact=binary_artifact,
      embedded_bundles=embedded_bundles,
  )

  # TODO(b/36513412): Support 'bazel run'.
  return struct(
      files=additional_outputs,
      providers=[
          WatchosApplicationBundleInfo(),
      ] + additional_providers,
      **legacy_providers
  )


watchos_application = rule_factory.make_bundling_rule(
    _watchos_application_impl,
    additional_attrs={
        "app_icons": attr.label_list(allow_files=True),
        "extension": attr.label(
            providers=[[AppleBundleInfo, WatchosExtensionBundleInfo]],
            mandatory=True,
        ),
        "storyboards": attr.label_list(
            allow_files=[".storyboard"],
        ),
    },
    archive_extension=".zip",
    code_signing=rule_factory.code_signing(".mobileprovision"),
    device_families=rule_factory.device_families(allowed=["watch"]),
    needs_pkginfo=True,
    path_formats=rule_factory.simple_path_formats(
        path_in_archive_format="%s"
    ),
    platform_type=apple_common.platform_type.watchos,
    product_type=rule_factory.product_type(
        apple_product_type.watch2_application, private=True
    ),
    use_binary_rule=False,
)


def _watchos_extension_impl(ctx):
  """Implementation of the watchos_extension Skylark rule."""

  app_icons = ctx.files.app_icons
  if app_icons:
    bundling_support.ensure_single_asset_type(
        app_icons, ["appiconset"], "app_icons")

  # Collect asset catalogs and storyboards, if any are present.
  additional_resource_sets = []
  additional_resources = depset(app_icons)
  if additional_resources:
    additional_resource_sets.append(AppleResourceSet(
        resources=additional_resources,
    ))

  binary_artifact = binary_support.get_binary_provider(
      ctx.attr.deps, apple_common.AppleExecutableBinary).binary
  deps_objc_provider = binary_support.get_binary_provider(
      ctx.attr.deps, apple_common.AppleExecutableBinary).objc
  additional_providers, legacy_providers, additional_outputs = bundler.run(
      ctx,
      "WatchosExtensionArchive", "watchOS extension",
      ctx.attr.bundle_id,
      additional_resource_sets=additional_resource_sets,
      binary_artifact=binary_artifact,
      deps_objc_providers=[deps_objc_provider],
  )

  return struct(
      files=additional_outputs,
      providers=[
          WatchosExtensionBundleInfo(),
      ] + additional_providers,
      **legacy_providers
  )


watchos_extension = rule_factory.make_bundling_rule(
    _watchos_extension_impl,
    additional_attrs={
        "app_icons": attr.label_list(allow_files=True),
    },
    archive_extension=".zip",
    code_signing=rule_factory.code_signing(".mobileprovision"),
    device_families=rule_factory.device_families(allowed=["watch"]),
    path_formats=rule_factory.simple_path_formats(path_in_archive_format="%s"),
    platform_type=apple_common.platform_type.watchos,
    product_type=rule_factory.product_type(
        apple_product_type.watch2_extension, private=True
    ),
    propagates_frameworks=True,
)
