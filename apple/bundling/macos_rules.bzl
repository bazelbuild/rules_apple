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
# limitations under the Lice

"""Rule implementations for creating macOS applications and bundles.

DO NOT load this file directly; use the macro in
@build_bazel_rules_apple//apple:macos.bzl instead. Bazel rules receive their name at
*definition* time based on the name of the global to which they are assigned.
We want the user to call macros that have the same name, to get automatic
binary creation, entitlements support, and other features--which requires a
wrapping macro because rules cannot invoke other rules.
"""

load("@build_bazel_rules_apple//apple/bundling:bundler.bzl",
     "bundler")
load("@build_bazel_rules_apple//apple/bundling:bundling_support.bzl",
     "bundling_support")
load("@build_bazel_rules_apple//apple/bundling:entitlements.bzl",
     "entitlements",
     "entitlements_support")
load("@build_bazel_rules_apple//apple/bundling:rule_attributes.bzl",
     "common_rule_attributes",
     "macos_path_format_attributes")
load("@build_bazel_rules_apple//apple:providers.bzl",
     "AppleBundleInfo",
     "AppleResourceSet",
     "MacosApplicationBundleInfo",
     "MacosExtensionBundleInfo")
load("@build_bazel_rules_apple//apple:utils.bzl",
     "merge_dictionaries")


def _macos_application_impl(ctx):
  """Implementation of the macos_application rule."""
  additional_resource_sets = []
  additional_resources = depset(ctx.files.app_icons)
  if additional_resources:
    additional_resource_sets.append(AppleResourceSet(
        resources=additional_resources,
    ))

  # TODO(b/36557429): Add support for macOS frameworks.
  embedded_bundles = [
      bundling_support.embedded_bundle(
          "PlugIns", extension[AppleBundleInfo], verify_bundle_id=True)
      for extension in ctx.attr.extensions
  ]

  additional_providers, legacy_providers, additional_outputs = bundler.run(
      ctx,
      "MacosApplicationArchive", "macOS application",
      ctx.attr.bundle_id,
      additional_resource_sets=additional_resource_sets,
      embedded_bundles=embedded_bundles,
  )

  # TODO(b/36556789): Add support for "bazel run".
  return struct(
      files=depset([ctx.outputs.archive]) + additional_outputs,
      providers=[
          MacosApplicationBundleInfo(),
      ] + additional_providers,
      **legacy_providers
  )


# All attributes available to the macos_application rule. (Note that this does
# not include linkopts, which is consumed entirely by the wrapping macro.)
_MACOS_APPLICATION_ATTRIBUTES = merge_dictionaries(
    common_rule_attributes(),
    macos_path_format_attributes(),
    {
        "app_icons": attr.label_list(),
        "entitlements": attr.label(
            allow_files=[".entitlements"],
            single_file=True,
        ),
        "extensions": attr.label_list(
            providers=[[AppleBundleInfo, MacosExtensionBundleInfo]],
        ),
        # Overwrite the provisioning_profile attribute to change the allowed
        # file extension.
        "provisioning_profile": attr.label(
            allow_files=[".provisionprofile"],
            single_file=True,
        ),
        "_allowed_families": attr.string_list(default=["mac"]),
        # The extension of the bundle being generated by the rule.
        "_bundle_extension": attr.string(default=".app"),
        # macOS .app bundles should include a PkgInfo file.
        "_needs_pkginfo": attr.bool(default=True),
        # A format string used to compose the path to the bundle inside the
        # packaged archive. The placeholder "%s" is replaced with the name of
        # the bundle (with its extension).
        "_path_in_archive_format": attr.string(default="%s"),
        # The platform type that should be passed to tools for targets of this
        # type.
        "_platform_type": attr.string(
            default=str(apple_common.platform_type.macos)
        ),
        "_requires_signing_for_device": attr.bool(default=False),
    }
)


macos_application = rule(
    _macos_application_impl,
    attrs = _MACOS_APPLICATION_ATTRIBUTES,
    executable = False,
    fragments = ["apple", "objc"],
    outputs = {
        "archive": "%{name}.zip",
    },
)


def _macos_extension_impl(ctx):
  """Implementation of the macos_extension rule."""
  additional_resource_sets = []
  additional_resources = depset(ctx.files.app_icons)
  if additional_resources:
    additional_resource_sets.append(AppleResourceSet(
        resources=additional_resources,
    ))

  additional_providers, legacy_providers, additional_outputs = bundler.run(
      ctx,
      "MacosExtensionArchive", "macOS extension",
      ctx.attr.bundle_id,
      additional_resource_sets=additional_resource_sets,
  )

  return struct(
      files=depset([ctx.outputs.archive]) + additional_outputs,
      providers=[
          MacosExtensionBundleInfo(),
      ] + additional_providers,
      **legacy_providers
  )


# All attributes available to the macos_extension rule. (Note that this does
# not include linkopts, which is consumed entirely by the wrapping macro.)
_MACOS_EXTENSION_ATTRIBUTES = merge_dictionaries(
    common_rule_attributes(),
    macos_path_format_attributes(),
    {
        "app_icons": attr.label_list(),
        "entitlements": attr.label(
            allow_files=[".entitlements"],
            single_file=True,
        ),
        # Overwrite the provisioning_profile attribute to change the allowed
        # file extension.
        "provisioning_profile": attr.label(
            allow_files=[".provisionprofile"],
            single_file=True,
        ),
        "_allowed_families": attr.string_list(default=["mac"]),
        # The extension of the bundle being generated by the rule.
        "_bundle_extension": attr.string(default=".appex"),
        # macOS extension bundles should not include a PkgInfo file.
        "_needs_pkginfo": attr.bool(default=False),
        # A format string used to compose the path to the bundle inside the
        # packaged archive. The placeholder "%s" is replaced with the name of
        # the bundle (with its extension).
        "_path_in_archive_format": attr.string(default="%s"),
        # The platform type that should be passed to tools for targets of this
        # type.
        "_platform_type": attr.string(
            default=str(apple_common.platform_type.macos)
        ),
        "_propagates_frameworks": attr.bool(default=True),
        "_requires_signing_for_device": attr.bool(default=False),
    }
)


macos_extension = rule(
    _macos_extension_impl,
    attrs = _MACOS_EXTENSION_ATTRIBUTES,
    fragments = ["apple", "objc"],
    outputs = {
        "archive": "%{name}.zip",
    },
)
