# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""Defines aspects for collecting information required to build .docc and .doccarchive files."""

load(
    "@build_bazel_rules_swift//swift:providers.bzl",
    "SwiftSymbolGraphInfo",
)
load(
    "@build_bazel_rules_swift//swift:swift_symbol_graph_aspect.bzl",
    "swift_symbol_graph_aspect",
)
load(
    "//apple:providers.bzl",
    "DocCBundleInfo",
    "DocCSymbolGraphsInfo",
)

def _swift_symbol_graphs(*, swift_symbol_graph_info):
    """Returns a `List` of symbol graph directories from a `SwiftSymbolGraphInfo` provider or fails if it doesn't exist."""
    direct_symbol_graphs = swift_symbol_graph_info.direct_symbol_graphs
    transitive_symbol_graphs = swift_symbol_graph_info.transitive_symbol_graphs

    return [
        symbol_graph.symbol_graph_dir
        for symbol_graph in (direct_symbol_graphs + transitive_symbol_graphs.to_list())
    ]

def _first_docc_bundle(*, target, ctx):
    """Returns the first .docc bundle for the target or its deps by looking in it's data."""
    docc_bundles = []

    # Find the path to the .docc directory if it exists.
    for data_target in ctx.rule.attr.data:
        for file in data_target.files.to_list():
            if file.extension == "docc":
                docc_bundles.append(file)

    if len(docc_bundles) > 1:
        fail("Expected target %s to have at most one .docc bundle in its data" % target.label)

    return docc_bundles[0] if docc_bundles else None

def _docc_symbol_graphs_aspect_impl(target, ctx):
    """Creates a DocCSymbolGraphsInfo provider for targets which have a SwiftInfo provider (or which bundle a target that does)."""

    symbol_graphs = []

    if SwiftSymbolGraphInfo in target:
        symbol_graphs.extend(
            _swift_symbol_graphs(
                swift_symbol_graph_info = target[SwiftSymbolGraphInfo],
            ),
        )
    elif hasattr(ctx.rule.attr, "deps"):
        for dep in ctx.rule.attr.deps:
            if SwiftSymbolGraphInfo in dep:
                symbol_graphs.extend(
                    _swift_symbol_graphs(
                        swift_symbol_graph_info = dep[SwiftSymbolGraphInfo],
                    ),
                )

    if not symbol_graphs:
        return []

    return [DocCSymbolGraphsInfo(symbol_graphs = symbol_graphs)]

def _docc_bundle_info_aspect_impl(target, ctx):
    """Creates a DocCBundleInfo provider for targets which have a .docc bundle (or which bundle a target that does)"""

    if hasattr(ctx.rule.attr, "data"):
        first_docc_bundle = _first_docc_bundle(
            target = target,
            ctx = ctx,
        )
        if first_docc_bundle:
            return [DocCBundleInfo(bundle = first_docc_bundle)]
    if hasattr(ctx.rule.attr, "deps"):
        # If this target has "deps", try to find a DocCBundleInfo provider in its deps.
        for dep in ctx.rule.attr.deps:
            if DocCBundleInfo in dep:
                return dep[DocCBundleInfo]

    return []

docc_bundle_info_aspect = aspect(
    implementation = _docc_bundle_info_aspect_impl,
    doc = """
    Creates or collects the `DocCBundleInfo` provider for a target or its deps.

    This aspect works with targets that have a `.docc` bundle in their data, or which bundle a target that does.
    """,
    attr_aspects = ["data", "deps"],
)

docc_symbol_graphs_aspect = aspect(
    implementation = _docc_symbol_graphs_aspect_impl,
    required_aspect_providers = [SwiftSymbolGraphInfo],
    requires = [swift_symbol_graph_aspect],
    doc = """
    Creates or collects the `DocCSymbolGraphsInfo` provider for a target or its deps.

    This aspect works with targets that have a `SwiftSymbolGraphInfo` provider, or which bundle a target that does.
    """,
    attr_aspects = ["deps"],
)
