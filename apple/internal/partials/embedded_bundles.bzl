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
    "@build_bazel_rules_apple//apple/internal:experimental.bzl",
    "is_experimental_tree_artifact_enabled",
)
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
        "xpc_services": """
A depset with the zipped archives of bundles that need to be expanded into the XPCServices section
of the packaging bundle. Only applicable for macOS applications.""",
    },
)

def _embedded_bundles_partial_impl(
        ctx,
        bundle_embedded_bundles,
        embeddable_targets,
        **input_bundles_by_type):
    """Implementation for the embedded bundles processing partial."""
    _ignore = [ctx]

    # Collect all _AppleEmbeddableInfo providers from the embeddable targets.
    embeddable_providers = [
        x[_AppleEmbeddableInfo]
        for x in embeddable_targets
        if _AppleEmbeddableInfo in x
    ]

    # Map of embedded bundle type to their final location in the top-level bundle.
    bundle_type_to_location = {
        "frameworks": processor.location.framework,
        "plugins": processor.location.plugin,
        "watch_bundles": processor.location.watch,
        "xpc_services": processor.location.xpc_service,
    }

    transitive_bundles = dict()
    bundles_to_embed = []
    embeddedable_info_fields = {}

    for bundle_type, bundle_location in bundle_type_to_location.items():
        for provider in embeddable_providers:
            if hasattr(provider, bundle_type):
                transitive_bundles.setdefault(
                    bundle_type,
                    default = [],
                ).append(getattr(provider, bundle_type))

        if bundle_embedded_bundles:
            # If this partial is configured to embed the transitive embeddable partials, collect
            # them into a list to be returned by this partial.
            if bundle_type in transitive_bundles:
                transitive_depset = depset(transitive = transitive_bundles.get(bundle_type, []))

                # With tree artifacts, we need to set the parent_dir of the file to be the basename
                # of the file. Expanding these depsets shouldn't be too much work as there shouldn't
                # be too many embedded targets per top-level bundle.
                if is_experimental_tree_artifact_enabled(ctx):
                    for bundle in transitive_depset.to_list():
                        bundles_to_embed.append(
                            (bundle_location, bundle.basename, depset([bundle])),
                        )
                else:
                    bundles_to_embed.append((bundle_location, None, transitive_depset))

            # Clear the transitive list of bundles for this bundle type since they will be packaged
            # in the bundle processing this partial and do not need to be propagated.
            transitive_bundles[bundle_type] = []

        # Construct the _AppleEmbeddableInfo provider field for the bundle type being processed.
        # At this step, we inject the bundles that are inputs to this partial, since that propagates
        # the info for a higher level bundle to embed this bundle.
        if input_bundles_by_type.get(bundle_type) or transitive_bundles.get(bundle_type):
            embeddedable_info_fields[bundle_type] = depset(
                input_bundles_by_type.get(bundle_type, []),
                transitive = transitive_bundles.get(bundle_type, []),
            )

    # Construct the output files fields. If tree artifacts is enabled, propagate the bundles to
    # package into bundle_files. Otherwise, propagate through bundle_zips so that they can be
    # extracted.
    partial_output_fields = {}
    if is_experimental_tree_artifact_enabled(ctx):
        partial_output_fields["bundle_files"] = bundles_to_embed
    else:
        partial_output_fields["bundle_zips"] = bundles_to_embed

    return struct(
        providers = [_AppleEmbeddableInfo(**embeddedable_info_fields)],
        **partial_output_fields
    )

def embedded_bundles_partial(
        bundle_embedded_bundles = False,
        embeddable_targets = [],
        frameworks = [],
        plugins = [],
        watch_bundles = [],
        xpc_services = []):
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
        xpc_services: List of macOS XPC Service bundles that should be propagated downstream for
            a top level target to bundle inside `XPCServices`.

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
        xpc_services = xpc_services,
    )
