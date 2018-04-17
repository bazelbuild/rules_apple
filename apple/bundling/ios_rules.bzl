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
    "@build_bazel_rules_apple//apple/bundling:file_support.bzl",
    "file_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:framework_support.bzl",
    "framework_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:product_support.bzl",
    "apple_product_type",
    "product_support",
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
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "AppleResourceSet",
    "IosApplicationBundleInfo",
    "IosExtensionBundleInfo",
    "IosFrameworkBundleInfo",
    "IosStaticFrameworkBundleInfo",
    "WatchosApplicationBundleInfo",
)
load(
    "@build_bazel_rules_apple//common:providers.bzl",
    "providers",
)


def _ios_application_impl(ctx):
  """Implementation of the ios_application Skylark rule."""

  app_icons = ctx.files.app_icons
  if app_icons:
    bundling_support.ensure_single_xcassets_type(
        "app_icons", app_icons, "appiconset")
  launch_images = ctx.files.launch_images
  if launch_images:
    bundling_support.ensure_single_xcassets_type(
        "launch_images", launch_images, "launchimage")

  # Collect asset catalogs, launch images, and the launch storyboard, if any are
  # present.
  additional_resource_sets = []
  additional_resources = depset(app_icons + launch_images)
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
          "PlugIns", extension, verify_has_child_plist=True)
      for extension in ctx.attr.extensions
  ] + [
      bundling_support.embedded_bundle(
          "Frameworks", framework, verify_has_child_plist=False)
      for framework in ctx.attr.frameworks
  ]

  watch_app = ctx.attr.watch_application
  if watch_app:
    embedded_bundles.append(bundling_support.embedded_bundle(
        "Watch", watch_app, verify_has_child_plist=True,
        parent_bundle_id_reference=["WKCompanionAppBundleIdentifier"]))

  binary_artifact = binary_support.get_binary_provider(
      ctx.attr.deps, apple_common.AppleExecutableBinary).binary
  deps_objc_provider = binary_support.get_binary_provider(
      ctx.attr.deps, apple_common.AppleExecutableBinary).objc
  additional_providers, legacy_providers, additional_outputs = bundler.run(
      ctx,
      "IosApplicationArchive", "iOS application",
      ctx.attr.bundle_id,
      binary_artifact=binary_artifact,
      additional_resource_sets=additional_resource_sets,
      embedded_bundles=embedded_bundles,
      deps_objc_providers=[deps_objc_provider],
  )

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
    bundles_frameworks=True,
    code_signing=rule_factory.code_signing(".mobileprovision"),
    device_families=rule_factory.device_families(allowed=["iphone", "ipad"]),
    needs_pkginfo=True,
    executable=True,
    path_formats=rule_factory.simple_path_formats(
        path_in_archive_format="Payload/%s"
    ),
    platform_type=apple_common.platform_type.ios,
    product_type=rule_factory.product_type(
        apple_product_type.application,
        values=[
            apple_product_type.application,
            apple_product_type.messages_application,
        ],
    ),
)


def _ios_extension_impl(ctx):
  """Implementation of the ios_extension Skylark rule."""

  app_icons = ctx.files.app_icons
  if app_icons:
    product_type = product_support.product_type(ctx)
    if product_type == apple_product_type.messages_extension:
      message = ("Message extensions must use Messages Extensions Icon Sets " +
                 "(named .stickersiconset), not traditional App Icon Sets")
      bundling_support.ensure_single_xcassets_type(
          "app_icons", app_icons, "stickersiconset", message=message)
    elif product_type == apple_product_type.messages_sticker_pack_extension:
      path_fragments = [
        # Replacement for appiconset.
        ["xcstickers", "stickersiconset" ],
        # The stickers.
        ["xcstickers", "stickerpack", "sticker"],
        ["xcstickers", "stickerpack", "stickersequence"],
      ]
      message = (
          "Message StickerPack extensions use an asset catalog named " +
          "*.xcstickers. Their main icons use *.stickersiconset; and then " +
          "under the Sticker Pack (*.stickerpack) goes the Stickers " +
          "(named *.sticker) and/or Sticker Sequences (named " +
          "*.stickersequence)")
      bundling_support.ensure_path_format(
          "app_icons", app_icons, path_fragments, message=message)
    else:
      bundling_support.ensure_single_xcassets_type(
          "app_icons", app_icons, "appiconset")

  # Collect asset catalogs and launch images if any are present.
  additional_resource_sets = []
  additional_resources = depset(app_icons + ctx.files.asset_catalogs)
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
      "IosExtensionArchive", "iOS extension",
      ctx.attr.bundle_id,
      binary_artifact=binary_artifact,
      additional_resource_sets=additional_resource_sets,
      deps_objc_providers=[deps_objc_provider],
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
        "dedupe_unbundled_resources": attr.bool(default=True),
        "frameworks": attr.label_list(
            providers=[[AppleBundleInfo, IosFrameworkBundleInfo]],
        ),
        "_extension_safe": attr.bool(default=True),
    },
    archive_extension=".zip",
    code_signing=rule_factory.code_signing(".mobileprovision"),
    device_families=rule_factory.device_families(allowed=["iphone", "ipad"]),
    path_formats=rule_factory.simple_path_formats(path_in_archive_format="%s"),
    platform_type=apple_common.platform_type.ios,
    product_type=rule_factory.product_type(
        apple_product_type.app_extension,
        values=[
            apple_product_type.app_extension,
            apple_product_type.messages_extension,
            apple_product_type.messages_sticker_pack_extension,
        ],
    ),
)


def _ios_framework_impl(ctx):
  """Implementation of the ios_framework Skylark rule."""
  binary_artifact = binary_support.get_binary_provider(
      ctx.attr.deps, apple_common.AppleDylibBinary).binary
  bundlable_binary = bundling_support.bundlable_file(
      binary_artifact, bundling_support.bundle_name(ctx))
  prefixed_hdr_files = []
  for hdr_provider in ctx.attr.hdrs:
    for hdr_file in hdr_provider.files:
      prefixed_hdr_files.append(bundling_support.header_prefix(hdr_file))

  binary_artifact = binary_support.get_binary_provider(
      ctx.attr.deps, apple_common.AppleDylibBinary).binary
  deps_objc_provider = binary_support.get_binary_provider(
      ctx.attr.deps, apple_common.AppleDylibBinary).objc
  additional_providers, legacy_providers, additional_outputs = bundler.run(
      ctx,
      "IosFrameworkArchive", "iOS framework",
      ctx.attr.bundle_id,
      binary_artifact=binary_artifact,
      additional_bundlable_files=prefixed_hdr_files,
      framework_files=prefixed_hdr_files + [bundlable_binary],
      is_dynamic_framework=True,
      deps_objc_providers=[deps_objc_provider],
      version_keys_required=False,
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
    path_formats=rule_factory.simple_path_formats(path_in_archive_format="%s"),
    platform_type=apple_common.platform_type.ios,
    product_type=rule_factory.product_type(
        apple_product_type.framework, private=True,
    ),
)


def _ios_static_framework_impl(ctx):
  """Implementation of the _ios_static_framework Skylark rule."""
  bundle_name = bundling_support.bundle_name(ctx)
  hdr_files = ctx.files.hdrs
  framework_files = [bundling_support.header_prefix(f) for f in hdr_files]

  sdk_dylibs = depset()
  sdk_frameworks = depset()
  for objc in providers.find_all(ctx.attr.deps, "objc"):
    sdk_dylibs += objc.sdk_dylib
    sdk_frameworks += objc.sdk_framework

  # Create an umbrella header if the framework has any header files.
  umbrella_header_name = None
  if hdr_files:
    umbrella_header_file = file_support.intermediate(ctx, "%{name}.umbrella.h")
    framework_support.create_umbrella_header(
        ctx.actions, umbrella_header_file, sorted(hdr_files))
    umbrella_header_name = bundle_name + ".h"
    framework_files.append(bundling_support.contents_file(
        ctx, umbrella_header_file, "Headers/" + umbrella_header_name))
  else:
    umbrella_header_name = None

  # Create a module map if there is a need for one (that is, if there are
  # headers or if there are dylibs/frameworks that we depend on).
  if any([sdk_dylibs, sdk_frameworks, umbrella_header_name]):
    modulemap_file = file_support.intermediate(
        ctx, "%s.modulemap" % bundle_name)
    framework_support.create_modulemap(
        ctx.actions, modulemap_file, bundle_name, umbrella_header_name,
        sorted(sdk_dylibs.to_list()), sorted(sdk_frameworks.to_list()))
    framework_files.append(bundling_support.contents_file(
        ctx, modulemap_file, "Modules/module.modulemap"))

  binary_artifact = binary_support.get_binary_provider(
      ctx.attr.deps, apple_common.AppleStaticLibrary).archive
  deps_objc_provider = binary_support.get_binary_provider(
      ctx.attr.deps, apple_common.AppleStaticLibrary).objc
  additional_providers, legacy_providers, additional_outputs = bundler.run(
      ctx,
      "IosStaticFrameworkArchive", "iOS static framework",
      None,  # static frameworks have no bundle id (nor final Info.plist).
      binary_artifact=binary_artifact,
      additional_bundlable_files=framework_files,
      framework_files=framework_files,
      deps_objc_providers=[deps_objc_provider],
      suppress_bundle_infoplist=True,
      version_keys_required=False,
  )

  return struct(
      files=additional_outputs,
      providers=[
          IosStaticFrameworkBundleInfo(),
      ] + additional_providers,
      **legacy_providers
  )


ios_static_framework = rule_factory.make_bundling_rule(
    _ios_static_framework_impl,
    additional_attrs={
        "avoid_deps": attr.label_list(),
        "dedupe_unbundled_resources": attr.bool(default=True),
        "exclude_resources": attr.bool(default=False),
        "hdrs": attr.label_list(allow_files=[".h"]),
    },
    archive_extension=".zip",
    binary_providers=[apple_common.AppleStaticLibrary],
    bundle_id_attr_mode=rule_factory.attribute_modes.UNSUPPORTED,
    code_signing=rule_factory.code_signing(skip_signing=True),
    device_families=rule_factory.device_families(
        allowed=["iphone", "ipad"],
        mandatory=False,
    ),
    infoplists_attr_mode=rule_factory.attribute_modes.UNSUPPORTED,
    path_formats=rule_factory.simple_path_formats(path_in_archive_format="%s"),
    platform_type=apple_common.platform_type.ios,
    product_type=rule_factory.product_type(
        apple_product_type.static_framework, private=True,
    ),
)
