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

"""Experimental implementation of watchOS rules."""

load(
    "@build_bazel_rules_apple//apple/bundling:binary_support.bzl",
    "binary_support",
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
    "WatchosApplicationBundleInfo",
    "WatchosExtensionBundleInfo",
)


def watchos_application_impl(ctx):
  """Experimental implementation of ios_application."""
  top_level_attrs = [
      "app_icons",
      "storyboards",
      "strings",
  ]
  binary_artifact = binary_support.create_stub_binary(ctx)
  processor_result = processor.process(ctx, [
      partials.binary_partial(binary_artifact=binary_artifact),
      partials.clang_rt_dylibs_partial(binary_artifact=binary_artifact),
      partials.debug_symbols_partial(debug_dependencies = [ctx.attr.extension]),
      partials.embedded_bundles_partial(targets=[ctx.attr.extension]),
      partials.resources_partial(
          plist_attrs=["infoplists"],
          top_level_attrs=top_level_attrs,
      ),
      partials.swift_dylibs_partial(
          binary_artifact=binary_artifact,
          dependency_targets=[ctx.attr.extension],
          package_dylibs=True,
      ),
      partials.watchos_stub_partial(binary_artifact=binary_artifact),
  ])

  embedded_bundles_provider = collect_embedded_bundle_provider(
      watches=[ctx.outputs.archive],
  )

  return [
      # TODO(kaipi): Fill in the fields of AppleBundleInfo.
      AppleBundleInfo(),
      DefaultInfo(
          files=processor_result.output_files,
      ),
      embedded_bundles_provider,
      WatchosApplicationBundleInfo(),
  ] + processor_result.providers

def watchos_extension_impl(ctx):
  """Experimental implementation of ios_extension."""
  top_level_attrs = [
      "app_icons",
      "strings",
  ]
  binary_target = ctx.attr.deps[0]
  binary_artifact = binary_target[apple_common.AppleExecutableBinary].binary
  processor_result = processor.process(ctx, [
      partials.binary_partial(binary_artifact=binary_artifact),
      partials.bitcode_symbols_partial(
          binary_artifact=binary_artifact,
          debug_outputs_provider = binary_target[apple_common.AppleDebugOutputs],
      ),
      partials.clang_rt_dylibs_partial(binary_artifact=binary_artifact),
      partials.debug_symbols_partial(
          debug_outputs_provider = binary_target[apple_common.AppleDebugOutputs],
      ),
      partials.resources_partial(
          plist_attrs=["infoplists"],
          top_level_attrs=top_level_attrs,
      ),
      partials.swift_dylibs_partial(binary_artifact=binary_artifact),
  ])

  # This can't be made into a partial as it needs the output archive
  # reference.
  # TODO(kaipi): Remove direct reference to ctx.outputs.archive.
  embedded_bundles_provider = collect_embedded_bundle_provider(
      plugins=[ctx.outputs.archive],
  )

  return [
      # TODO(kaipi): Fill in the fields of AppleBundleInfo.
      AppleBundleInfo(),
      DefaultInfo(
          files=processor_result.output_files,
      ),
      embedded_bundles_provider,
      WatchosExtensionBundleInfo()
  ] + processor_result.providers
