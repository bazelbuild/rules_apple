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

"""Partial implementation for processing embeddadable bundles."""

load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:processor.bzl",
    "processor",
)

_AppleEmbeddableInfo = provider(
    doc="""
Private provider used to propagate the different embeddable bundles that a
top-level bundling rule will need to package.""",
    fields={
        "frameworks": """
A depset with the zipped archives of bundles that need to be expanded into the
Frameworks section of the packaging bundle.""",
        "plugins": """
A depset with the zipped archives of bundles that need to be expanded into the
PlugIns section of the packaging bundle.""",
    },
)

def collect_embedded_bundle_provider(frameworks=[], plugins=[], targets=[]):
  """Collects embeddable bundles into a single AppleEmbeddableInfo provider."""
  embeddable_providers = [
      x[_AppleEmbeddableInfo] for x in targets
      if _AppleEmbeddableInfo in x
  ]

  framework_bundles = depset(frameworks)
  plugin_bundles = depset(plugins)
  for provider in embeddable_providers:
    framework_bundles = depset(
        transitive=[framework_bundles, provider.frameworks],
    )
    plugin_bundles = depset(transitive=[plugin_bundles, provider.plugins])

  return _AppleEmbeddableInfo(
      frameworks=framework_bundles,
      plugins=plugin_bundles,
  )

def _embedded_bundles_partial_impl(ctx, targets=[]):
  """Implementation for the embedded bundles processing partial."""
  _ignore = [ctx]

  embeddable_provider = collect_embedded_bundle_provider(targets=targets)

  bundle_files = [
      (processor.location.framework, None, embeddable_provider.frameworks),
      (processor.location.plugin, None, embeddable_provider.plugins),
  ]

  return struct(
      bundle_files=bundle_files,
      providers=[embeddable_provider],
  )

def embedded_bundles_partial(targets):
  """Constructor for the embedded bundles processing partial.

  This partial collects AppleEmbeddableInfo from the given targets and packages
  them into their respective locations. Embeddable bundles are considered to be
  frameworks, plugins (i.e. extensions) and watchOS applications in the case of
  ios_application.

  Args:
    targets: The list of targets containing transitive embeddable bundles that
      need to be packaged into the target using this partial.

  Returns:
    A partial that returns the bundle location of the embeddable bundles and
    the AppleEmbeddableInfo provider containing the bundles embedded by this
    target.
  """
  return partial.make(
      _embedded_bundles_partial_impl,
      targets=targets
  )
