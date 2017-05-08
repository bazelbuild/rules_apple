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

load("@build_bazel_rules_apple//apple/bundling:apple_bundling_aspect.bzl",
     "apple_bundling_aspect")
load("@build_bazel_rules_apple//apple/bundling:bundler.bzl", "bundler")
load("@build_bazel_rules_apple//apple/bundling:bundling_support.bzl",
     "bundling_support")
load("@build_bazel_rules_apple//apple/bundling:entitlements.bzl",
     "entitlements",
     "entitlements_support")
load("@build_bazel_rules_apple//apple/bundling:rule_attributes.bzl",
     "common_rule_attributes")
load("@build_bazel_rules_apple//apple/bundling:run_actions.bzl", "run_actions")
load("@build_bazel_rules_apple//apple/bundling:test_support.bzl", "test_support")
load("@build_bazel_rules_apple//apple:providers.bzl",
     "AppleBundleInfo",
     "AppleResourceSet",
     "IosApplicationBundleInfo",
     "IosExtensionBundleInfo",
     "IosFrameworkBundleInfo",
     "WatchosApplicationBundleInfo")
load("@build_bazel_rules_apple//apple:utils.bzl", "merge_dictionaries")


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

  # TODO(b/32910122): Obtain framework information from extensions.
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

  additional_providers, legacy_providers, additional_outputs = bundler.run(
      ctx,
      "IosApplicationArchive", "iOS application",
      ctx.attr.bundle_id,
      additional_resource_sets=additional_resource_sets,
      embedded_bundles=embedded_bundles,
  )

  if ctx.attr.binary:
    legacy_providers["xctest_app"] = test_support.new_xctest_app_provider(ctx)

  runfiles = run_actions.start_simulator(ctx)

  return struct(
      files=depset([ctx.outputs.archive]) + additional_outputs,
      runfiles=ctx.runfiles(files=runfiles),
      providers=[
          IosApplicationBundleInfo(),
      ] + additional_providers,
      **legacy_providers
  )


# All attributes available to the _ios_application rule. (Note that this does
# not include linkopts, which is consumed entirely by the wrapping macro.)
_IOS_APPLICATION_ATTRIBUTES = merge_dictionaries(common_rule_attributes(), {
    "app_icons": attr.label_list(allow_files=True),
    "entitlements": attr.label(
        allow_files=[".entitlements"],
        single_file=True,
    ),
    "extensions": attr.label_list(
        providers=[[AppleBundleInfo, IosExtensionBundleInfo]],
    ),
    "families": attr.string_list(
        mandatory=True,
        allow_empty=False,
    ),
    "frameworks": attr.label_list(
        allow_rules=["ios_framework"],
    ),
    "launch_images": attr.label_list(allow_files=True),
    "launch_storyboard": attr.label(
        allow_files=[".storyboard", ".xib"],
        single_file=True,
    ),
    "product_type": attr.string(),
    "settings_bundle": attr.label(providers=[["objc"]]),
    "watch_application": attr.label(
        providers=[[AppleBundleInfo, WatchosApplicationBundleInfo]],
    ),
    "_allowed_families": attr.string_list(default=["iphone", "ipad"]),
    # The extension of the bundle being generated by the rule.
    "_bundle_extension": attr.string(default=".app"),
    # iOS .app bundles should include a PkgInfo file.
    "_needs_pkginfo": attr.bool(default=True),
    # A format string used to compose the path to the bundle inside the
    # packaged archive. The placeholder "%s" is replaced with the name of the
    # bundle (with its extension).
    "_path_in_archive_format": attr.string(default="Payload/%s"),
    # The platform type that should be passed to tools for targets of this
    # type.
    "_platform_type": attr.string(default=str(apple_common.platform_type.ios)),
})


ios_application = rule(
    _ios_application_impl,
    attrs = _IOS_APPLICATION_ATTRIBUTES,
    executable = True,
    fragments = ["apple", "objc"],
    outputs = {
        "archive": "%{name}.ipa",
    },
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

  additional_providers, legacy_providers, additional_outputs = bundler.run(
      ctx,
      "IosExtensionArchive", "iOS extension",
      ctx.attr.bundle_id,
      additional_resource_sets=additional_resource_sets,
  )

  return struct(
      files=depset([ctx.outputs.archive]) + additional_outputs,
      providers=[
          IosExtensionBundleInfo(),
      ] + additional_providers,
      **legacy_providers
  )


# All attributes available to the _ios_extension rule. (Note that this does
# not include linkopts, which is consumed entirely by the wrapping macro.)
_IOS_EXTENSION_ATTRIBUTES = merge_dictionaries(common_rule_attributes(), {
    "app_icons": attr.label_list(allow_files=True),
    "asset_catalogs": attr.label_list(
        allow_files=True,
    ),
    "entitlements": attr.label(
        allow_files=[".entitlements"],
        single_file=True,
    ),
    "families": attr.string_list(
        mandatory=True,
    ),
    "frameworks": attr.label_list(
        allow_rules=["ios_framework"],
    ),
    "product_type": attr.string(),
    "_allowed_families": attr.string_list(default=["iphone", "ipad"]),
    # The extension of the bundle being generated by the rule.
    "_bundle_extension": attr.string(default=".appex"),
    # iOS extension bundles should not include a PkgInfo file.
    "_needs_pkginfo": attr.bool(default=False),
    # A format string used to compose the path to the bundle inside the
    # packaged archive. The placeholder "%s" is replaced with the name of the
    # bundle (with its extension).
    "_path_in_archive_format": attr.string(default="%s"),
    # The platform type that should be passed to tools for targets of this
    # type.
    "_platform_type": attr.string(default=str(apple_common.platform_type.ios)),
    "_propagates_frameworks": attr.bool(default=True),
})


ios_extension = rule(
    _ios_extension_impl,
    attrs = _IOS_EXTENSION_ATTRIBUTES,
    fragments = ["apple", "objc"],
    outputs = {
        "archive": "%{name}.zip",
    },
)


def _ios_framework_impl(ctx):
  """Implementation of the ios_framework Skylark rule."""
  bundlable_binary = struct(file=ctx.file.binary,
                            bundle_path=bundling_support.bundle_name(ctx))
  prefixed_hdr_files = []
  for hdr_provider in ctx.attr.hdrs:
    for hdr_file in hdr_provider.files:
      prefixed_hdr_files.append(bundling_support.header_prefix(hdr_file))

  additional_providers, legacy_providers, additional_outputs = bundler.run(
      ctx,
      "IosFrameworkArchive", "iOS framework",
      ctx.attr.bundle_id,
      additional_bundlable_files=prefixed_hdr_files,
      framework_files=prefixed_hdr_files + [bundlable_binary],
      is_dynamic_framework=True,
  )

  return struct(
      files=depset([ctx.outputs.archive]) + additional_outputs,
      providers=[
          IosFrameworkBundleInfo(),
      ] + additional_providers,
      **legacy_providers
  )


# All attributes available to the _ios_framework rule.
_IOS_FRAMEWORK_ATTRIBUTES = merge_dictionaries(common_rule_attributes(), {
    "binary": attr.label(
        aspects=[apple_bundling_aspect],
        mandatory=True,
        providers=[apple_common.AppleDylibBinary],
        single_file=True,
    ),
    "hdrs": attr.label_list(
        allow_files=[".h"],
    ),
    "families": attr.string_list(
        mandatory=True,
    ),
    "linkopts": attr.string_list(),
    "_allowed_families": attr.string_list(default=["iphone", "ipad"]),
    # The extension of the bundle being generated by the rule.
    "_bundle_extension": attr.string(default=".framework"),
    # iOS extension bundles should not include a PkgInfo file.
    "_needs_pkginfo": attr.bool(default=False),
    # A format string used to compose the path to the bundle inside the
    # packaged archive. The placeholder "%s" is replaced with the name of the
    # bundle (with its extension).
    "_path_in_archive_format": attr.string(default="%s"),
    # The platform type that should be passed to tools for targets of this
    # type.
    "_platform_type": attr.string(default=str(apple_common.platform_type.ios)),
    # Frameworks don't nest other frameworks; such dependencies should be
    # propagated to the same place as the parent target's frameworks.
    "_propagates_frameworks": attr.bool(default=True),
    # Frameworks do not require code signing by themselves, and are signed only
    # when the containing app or extension is signed.
    "_skip_signing": attr.bool(default=True),
})


ios_framework = rule(
    _ios_framework_impl,
    attrs = _IOS_FRAMEWORK_ATTRIBUTES,
    fragments = ["apple", "objc"],
    outputs = {
        "archive": "%{name}.zip",
    },
)
