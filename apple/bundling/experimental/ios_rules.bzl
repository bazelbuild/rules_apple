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

"""Experimental implementation of iOS rules."""

load(
    "@build_bazel_rules_apple//apple/bundling:file_actions.bzl",
    "file_actions",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:partials.bzl",
    "partials",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:processor.bzl",
    "processor",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental/partials:embedded_bundles.bzl",
    "collect_embedded_bundle_provider",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "IosApplicationBundleInfo",
    "IosFrameworkBundleInfo",
    "IosExtensionBundleInfo",
)


def ios_application_impl(ctx):
  """Experimental implementation of ios_application."""
  # TODO(kaipi): Handle other things related to iOS apps, like frameworks,
  # extensions and SwiftSupport.
  top_level_attrs = [
      "app_icons",
      "launch_images",
      "launch_storyboard",
      "settings_bundle",
      "strings",
  ]
  output_archive, providers = processor.process(ctx, [
      partials.binary_partial(
          provider_key=apple_common.AppleExecutableBinary,
      ),
      partials.embedded_bundles_partial(
          # TODO(kaipi): Handle watchOS apps as well.
          targets=ctx.attr.frameworks + ctx.attr.extensions,
      ),
      partials.resources_partial(
          plist_attrs=["infoplists"],
          targets_to_avoid=ctx.attr.frameworks,
          top_level_attrs=top_level_attrs,
      ),
      partials.swift_dylibs_partial(
          dependency_targets=ctx.attr.frameworks + ctx.attr.extensions,
          package_dylibs=True,
          provider_key=apple_common.AppleExecutableBinary,
      )
  ])

  return [
      # TODO(kaipi): Fill in the fields of AppleBundleInfo.
      AppleBundleInfo(),
      DefaultInfo(
          executable=output_archive,
      ),
      IosApplicationBundleInfo(),
  ] + providers

def ios_framework_impl(ctx):
  """Experimental implementation of ios_framework."""
  # TODO(kaipi): Add support for packaging headers.
  output_archive, providers = processor.process(ctx, [
      partials.binary_partial(
          provider_key=apple_common.AppleDylibBinary,
      ),
      partials.framework_provider_partial(),
      partials.resources_partial(
          plist_attrs=["infoplists"],
          targets_to_avoid=ctx.attr.frameworks,
      ),
      partials.swift_dylibs_partial(
          dependency_targets=ctx.attr.frameworks,
          provider_key=apple_common.AppleDylibBinary,
      )
  ])

  # This can't be made into a partial as it needs the output archive
  # reference.
  embedded_bundles_provider = collect_embedded_bundle_provider(
      frameworks=[output_archive], targets=ctx.attr.frameworks,
  )

  return [
      # TODO(kaipi): Fill in the fields of AppleBundleInfo.
      AppleBundleInfo(),
      DefaultInfo(
          executable=output_archive,
      ),
      embedded_bundles_provider,
      IosFrameworkBundleInfo(),
  ] + providers


def ios_extension_impl(ctx):
  """Experimental implementation of ios_extension."""
  top_level_attrs = [
      "app_icons",
      "strings",
  ]
  output_archive, providers = processor.process(ctx, [
      partials.binary_partial(
          provider_key=apple_common.AppleExecutableBinary,
      ),
      partials.resources_partial(
          plist_attrs=["infoplists"],
          targets_to_avoid=ctx.attr.frameworks,
          top_level_attrs=top_level_attrs,
      ),
      partials.swift_dylibs_partial(
          dependency_targets=ctx.attr.frameworks,
          provider_key=apple_common.AppleExecutableBinary,
      )
  ])

  # This can't be made into a partial as it needs the output archive
  # reference.
  embedded_bundles_provider = collect_embedded_bundle_provider(
      plugins=[output_archive], targets=ctx.attr.frameworks,
  )

  return [
      # TODO(kaipi): Fill in the fields of AppleBundleInfo.
      AppleBundleInfo(),
      DefaultInfo(
          executable=output_archive,
      ),
      embedded_bundles_provider,
      IosExtensionBundleInfo()
  ] + providers
