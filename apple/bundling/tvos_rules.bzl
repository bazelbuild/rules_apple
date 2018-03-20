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

"""Bazel rules for creating tvOS applications and bundles.

DO NOT load this file directly; use the macro in
@build_bazel_rules_apple//apple:tvos.bzl instead. Bazel rules receive their name at
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
     "TvosApplicationBundleInfo",
     "TvosExtensionBundleInfo")


def _tvos_application_impl(ctx):
  """Implementation of the `tvos_application` Skylark rule."""

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

  # TODO(b/32910122): Obtain framework information from extensions.
  embedded_bundles = [
      bundling_support.embedded_bundle(
          "PlugIns", extension, verify_has_child_plist=True)
      for extension in ctx.attr.extensions
  ]

  binary_artifact = binary_support.get_binary_provider(
      ctx.attr.deps, apple_common.AppleExecutableBinary).binary
  deps_objc_provider = binary_support.get_binary_provider(
      ctx.attr.deps, apple_common.AppleExecutableBinary).objc
  additional_providers, legacy_providers, additional_outputs = bundler.run(
      ctx,
      "TvosExtensionArchive", "tvOS application",
      ctx.attr.bundle_id,
      binary_artifact=binary_artifact,
      additional_resource_sets=additional_resource_sets,
      embedded_bundles=embedded_bundles,
      deps_objc_providers=[deps_objc_provider],
  )
  runfiles = run_actions.start_simulator(ctx)

  return struct(
      files=additional_outputs,
      runfiles=ctx.runfiles(files=runfiles),
      providers=[
          TvosApplicationBundleInfo(),
      ] + additional_providers,
      **legacy_providers
  )


tvos_application = rule_factory.make_bundling_rule(
    _tvos_application_impl,
    additional_attrs={
        "app_icons": attr.label_list(allow_files=True),
        "extensions": attr.label_list(
            providers=[[AppleBundleInfo, TvosExtensionBundleInfo]],
        ),
        "launch_images": attr.label_list(allow_files=True),
        "launch_storyboard": attr.label(
            allow_files=[".storyboard", ".xib"],
            single_file=True,
        ),
        "settings_bundle": attr.label(providers=[["objc"]]),
    },
    archive_extension=".ipa",
    code_signing=rule_factory.code_signing(".mobileprovision"),
    device_families=rule_factory.device_families(allowed=["tv"]),
    needs_pkginfo=True,
    executable=True,
    path_formats=rule_factory.simple_path_formats(
        path_in_archive_format="Payload/%s"
    ),
    platform_type=apple_common.platform_type.tvos,
    product_type=rule_factory.product_type(apple_product_type.application),
)


def _tvos_extension_impl(ctx):
  """Implementation of the `tvos_extension` Skylark rule."""
  binary_artifact = binary_support.get_binary_provider(
      ctx.attr.deps, apple_common.AppleExecutableBinary).binary
  deps_objc_provider = binary_support.get_binary_provider(
      ctx.attr.deps, apple_common.AppleExecutableBinary).objc
  additional_providers, legacy_providers, additional_outputs = bundler.run(
      ctx,
      "TvosExtensionArchive", "tvOS extension",
      ctx.attr.bundle_id,
      binary_artifact=binary_artifact,
      deps_objc_providers=[deps_objc_provider],
  )

  return struct(
      files=additional_outputs,
      providers=[
          TvosExtensionBundleInfo(),
      ] + additional_providers,
      **legacy_providers
  )


tvos_extension = rule_factory.make_bundling_rule(
    _tvos_extension_impl,
    archive_extension=".zip",
    code_signing=rule_factory.code_signing(".mobileprovision"),
    device_families=rule_factory.device_families(allowed=["tv"]),
    path_formats=rule_factory.simple_path_formats(path_in_archive_format="%s"),
    platform_type=apple_common.platform_type.tvos,
    product_type=rule_factory.product_type(apple_product_type.app_extension),
    propagates_frameworks=True,
)
