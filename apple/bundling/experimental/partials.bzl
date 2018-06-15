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

"""Partial implementations for common aspects of bundling.

These partials conform to the processor.bzl interface for partials. For more
information on this, check processor.bzl.
"""

load(
    "@build_bazel_rules_apple//apple/bundling/experimental:processor.bzl",
    "processor",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:resources.bzl",
    "NewAppleResourceInfo",
    "resources",
)
load(
    "@build_bazel_rules_apple//apple/bundling:file_actions.bzl",
    "file_actions",
)
load(
    "@build_bazel_rules_apple//apple/bundling:bundling_support.bzl",
    "bundling_support",
)

def _binary_partial_impl(ctx, provider_key):
  """Implementation for the binary processing partial."""
  provider = ctx.attr.deps[0][provider_key]
  binary_file = provider.binary

  # TODO(kaipi): Use a proper intermediate location proxy.
  intermediate_file = ctx.actions.declare_file(
      "%s-intermediates/%s" % (
          ctx.label.name,bundling_support.bundle_name(ctx)
      )
  )
  file_actions.symlink(ctx, binary_file, intermediate_file)
  return struct(
      files=[(processor.location.binary, None, depset([intermediate_file]))],
      providers=[provider],
  )

def _resources_partial_impl(ctx, targets_to_avoid=[], top_level_attrs=[]):
  """Implementation for the resource processing partial."""
  # TODO(kaipi): Implement resource deduplication.
  _ = targets_to_avoid
  providers = [
      x[NewAppleResourceInfo]
      for x in ctx.attr.deps
      if NewAppleResourceInfo in x
  ]

  # TODO(kaipi): Bucket top_level_attrs directly instead of collecting and
  # splitting.
  files = resources.collect(ctx.attr, res_attrs=top_level_attrs)
  if files:
    providers.append(resources.bucketize(files))

  complete_provider = resources.merge_providers(providers)

  # TODO(kaipi): Process files before collecting them to be packaged.
  files = []
  fields = [f for f in dir(complete_provider) if f not in ["to_json", "to_proto"]]
  for field in fields:
    if field in ["xcassets"]:
      continue
    file_group = [
        (processor.location.resource, p, f)
        for p, _, f in getattr(complete_provider, field)
    ]
    files.extend(file_group)

  return struct(
      files=files,
      providers=[complete_provider],
  )

def _binary_partial(provider_key):
  """Constructor for the binary processing partial.

  This partial propagates the binary file to be bundled, as well as the binary
  provider coming from the underlying apple_binary target. Because apple_binary
  provides a different provider depending on the type of binary being created,
  this partial requires the provider key under which to find the provider to
  propagate as well as the binary artifact to bundle.

  Args:
    provider_key: The provider key under which to find the binary provider
      containing the binary artifact.

  Returns:
    A partial that returns the bundle location of the binary and the binary
    provider.
  """
  return partial.make(
      _binary_partial_impl,
      provider_key=provider_key,
  )

def _resources_partial(targets_to_avoid=[], top_level_attrs=[]):
  """Constructor for the resources processing partial.

  This partial collects and propagates all resources that should be bundled in
  the target being processed.

  Args:
    targets_to_avoid: List of targets containing resources that should be
      deduplicated from the target being processed.
    top_level_attrs: List of attributes containing resources that need to
      be processed from the target being processed.

  Returns:
    A partial that returns the bundle location of the resources and the
      resources provider.
  """
  return partial.make(
      _resources_partial_impl,
      targets_to_avoid=targets_to_avoid,
      top_level_attrs=top_level_attrs,
  )

partials = struct(
    binary_partial=_binary_partial,
    resources_partial=_resources_partial,
)
