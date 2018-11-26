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
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)

_AppleEmbeddableInfo = provider(
    doc = """
Private provider used to propagate the different embeddable bundles that a
top-level bundling rule will need to package.""",
    fields = {
        "frameworks": """
A depset with the zipped archives of bundles that need to be expanded into the
Frameworks section of the packaging bundle.""",
        "plugins": """
A depset with the zipped archives of bundles that need to be expanded into the
PlugIns section of the packaging bundle.""",
        "watch_bundles": """
A depset with the zipped archives of bundles that need to be expanded into the Watch section of
the packaging bundle. Only applicable for iOS applications.""",
    },
)

def _embedded_bundles_partial_impl(
        ctx,
        bundle_embedded_bundles,
        embeddable_targets,
        frameworks,
        plugins,
        watch_bundles):
    """Implementation for the embedded bundles processing partial."""
    _ignore = [ctx]

    embeddable_providers = [
        x[_AppleEmbeddableInfo]
        for x in embeddable_targets
        if _AppleEmbeddableInfo in x
    ]

    transitive_frameworks = []
    transitive_plugins = []
    transitive_watch_bundles = []
    for provider in embeddable_providers:
        transitive_frameworks.append(provider.frameworks)
        transitive_plugins.append(provider.plugins)
        transitive_watch_bundles.append(provider.watch_bundles)

    bundle_zips = []
    if bundle_embedded_bundles:
        bundle_zips.extend([
            (processor.location.framework, None, depset(transitive = transitive_frameworks)),
            (processor.location.plugin, None, depset(transitive = transitive_plugins)),
            (processor.location.watch, None, depset(transitive = transitive_watch_bundles)),
        ])

        # Clear the transitive lists to avoid propagating them, since they will be packaged in the
        # bundle processing this partial and do not need to be propagated.
        transitive_frameworks = []
        transitive_plugins = []
        transitive_watch_bundles = []

    return struct(
        bundle_zips = bundle_zips,
        providers = [
            _AppleEmbeddableInfo(
                frameworks = depset(frameworks, transitive = transitive_frameworks),
                plugins = depset(plugins, transitive = transitive_plugins),
                watch_bundles = depset(watch_bundles, transitive = transitive_watch_bundles),
            ),
        ],
    )

def embedded_bundles_partial(
        bundle_embedded_bundles = False,
        embeddable_targets = [],
        frameworks = [],
        plugins = [],
        watch_bundles = []):
    """Constructor for the embedded bundles processing partial.

    This partial is used to propagate and package embedded bundles into their respective locations
    inside top level bundling targets. Embeddable bundles are considered to be
    frameworks, plugins (i.e. extensions) and watchOS applications in the case of
    ios_application.

    Args:
        bundle_embedded_bundles: If True, this target will embed all transitive embeddable_bundles
            _only_ propagated through the targets given in embeddable_targets. If False, the
            embeddable bundles will be propagated downstream for a top level target to bundle them.
        embeddable_targets: The list of targets that propagate embeddable bundles to bundle or
            propagate.
        frameworks: List of framework bundles that should be propagated downstream for a top level
            target to bundle inside `Frameworks`.
        plugins: List of plugin bundles that should be propagated downstream for a top level
            target to bundle inside `PlugIns`.
        watch_bundles: List of watchOS application bundles that should be propagated downstream for
            a top level target to bundle inside `Watch`.

    Returns:
          A partial that propagates and/or packages embeddable bundles.
    """
    return partial.make(
        _embedded_bundles_partial_impl,
        bundle_embedded_bundles = bundle_embedded_bundles,
        embeddable_targets = embeddable_targets,
        frameworks = frameworks,
        plugins = plugins,
        watch_bundles = watch_bundles,
    )
