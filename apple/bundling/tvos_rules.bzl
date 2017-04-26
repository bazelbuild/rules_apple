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
load("@build_bazel_rules_apple//apple/bundling:rule_attributes.bzl",
     "common_rule_attributes")
load("@build_bazel_rules_apple//apple/bundling:run_actions.bzl", "run_actions")
load("@build_bazel_rules_apple//apple:providers.bzl", "AppleResourceSet")
load("@build_bazel_rules_apple//apple:utils.bzl", "merge_dictionaries")


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
          "PlugIns", extension.apple_bundle, verify_bundle_id=True)
      for extension in ctx.attr.extensions
  ]

  providers, additional_outputs = bundler.run(
      ctx,
      "TvosExtensionArchive", "tvOS application",
      ctx.attr.bundle_id,
      additional_resource_sets=additional_resource_sets,
      embedded_bundles=embedded_bundles,
  )
  runfiles = run_actions.start_simulator(ctx)

  # The empty tvos_application provider acts as a tag to let depending
  # attributes restrict the targets that can be used to just tvOS applications.
  return struct(
      files=depset([ctx.outputs.archive]) + additional_outputs,
      runfiles=ctx.runfiles(files=runfiles),
      tvos_application=struct(),
      **providers
  )


tvos_application = rule(
    _tvos_application_impl,
    attrs = merge_dictionaries(common_rule_attributes(), {
        "app_icons": attr.label_list(allow_files=True),
        "entitlements": attr.label(
            allow_files=[".entitlements"],
            single_file=True,
        ),
        "extensions": attr.label_list(
            providers=[["apple_bundle", "tvos_extension"]],
        ),
        "launch_images": attr.label_list(allow_files=True),
        "launch_storyboard": attr.label(
            allow_files=[".storyboard", ".xib"],
            single_file=True,
        ),
        "settings_bundle": attr.label(providers=[["objc"]]),
        "_allowed_families": attr.string_list(default=["tv"]),
        # The extension of the bundle being generated by the rule.
        "_bundle_extension": attr.string(default=".app"),
        # iOS .app bundles should include a PkgInfo file.
        "_needs_pkginfo": attr.bool(default=True),
        # A format string used to compose the path to the bundle inside the
        # packaged archive. The placeholder "%s" is replaced with the name of
        # the bundle (with its extension).
        "_path_in_archive_format": attr.string(default="Payload/%s"),
        # The platform type that should be passed to tools for targets of this
        # type.
        "_platform_type": attr.string(
            default=str(apple_common.platform_type.tvos)
        ),
    }),
    executable = True,
    fragments = ["apple", "objc"],
    outputs = {
        "archive": "%{name}.ipa",
    },
)


def _tvos_extension_impl(ctx):
  """Implementation of the `tvos_extension` Skylark rule."""
  providers, additional_outputs = bundler.run(
      ctx,
      "TvosExtensionArchive", "tvOS extension",
      ctx.attr.bundle_id)

  # The empty tvos_extension provider acts as a tag to let depending attributes
  # restrict the targets that can be used to just tvOS extensions.
  return struct(
      files=depset([ctx.outputs.archive]) + additional_outputs,
      tvos_extension=struct(),
      **providers
  )


tvos_extension = rule(
    _tvos_extension_impl,
    attrs = merge_dictionaries(common_rule_attributes(), {
        "entitlements": attr.label(
            allow_files=[".entitlements"],
            single_file=True,
        ),
        "_allowed_families": attr.string_list(default=["tv"]),
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
        "_platform_type": attr.string(
            default=str(apple_common.platform_type.tvos)
        ),
        "_propagates_frameworks": attr.bool(default=True),
    }),
    fragments = ["apple", "objc"],
    outputs = {
        "archive": "%{name}.zip",
    },
)
