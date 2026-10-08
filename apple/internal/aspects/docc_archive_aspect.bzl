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
    "@apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)
load(
    "@rules_cc//cc:find_cc_toolchain.bzl",
    "find_cc_toolchain",
    "use_cc_toolchain",
)
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load(
    "@rules_swift//swift:providers.bzl",
    "SwiftSymbolGraphInfo",
)
load(
    "@rules_swift//swift:swift_symbol_graph_aspect.bzl",
    "swift_symbol_graph_aspect",
)
load(
    "//apple:providers.bzl",
    "DocCBundleInfo",
    "DocCSymbolGraphsInfo",
)

def _objc_symbol_graph(*, target, ctx):
    """Extracts a symbol graph from the public headers of an `objc_library` target.

    Returns:
        A directory containing the extracted symbol graph, or `None` if the target has no public
        headers to extract a symbol graph from.
    """
    compilation_context = target[CcInfo].compilation_context
    headers = [
        header
        for header in compilation_context.direct_public_headers
        if header.extension == "h"
    ]
    if not headers:
        return None

    module_name = getattr(ctx.rule.attr, "module_name", None) or target.label.name
    cc_toolchain = find_cc_toolchain(ctx)
    symbol_graph_dir = ctx.actions.declare_directory(
        "%s.docc_symbolgraphs" % target.label.name,
    )

    # Public headers have to be parseable with only the compilation context that is propagated to
    # dependents, so private copts and local defines of the target are intentionally not used.
    arguments = ctx.actions.args()
    arguments.add("clang")
    arguments.add("-extract-api")
    arguments.add("--product-name=%s" % module_name)
    arguments.add("-x", "objective-c-header")
    arguments.add("-target", cc_toolchain.target_gnu_system_name)
    arguments.add("-fobjc-arc")
    if ctx.rule.attr.enable_modules or "-fmodules" in ctx.rule.attr.copts:
        arguments.add("-fmodules")
        arguments.add("-fmodules-cache-path=%s/_objc_module_cache" % ctx.genfiles_dir.path)
    if ctx.attr.emit_extension_block_symbols == "1":
        arguments.add("--emit-extension-symbol-graphs")
    arguments.add_all(compilation_context.defines, format_each = "-D%s")
    arguments.add_all(compilation_context.includes, format_each = "-I%s")
    arguments.add_all(compilation_context.quote_includes, before_each = "-iquote")
    arguments.add_all(compilation_context.system_includes, before_each = "-isystem")
    arguments.add_all(compilation_context.framework_includes, format_each = "-F%s")
    arguments.add("--symbol-graph-dir=%s" % symbol_graph_dir.path)
    arguments.add_all(headers)

    apple_support.run(
        actions = ctx.actions,
        xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
        apple_platform_info = apple_support.platform_info_from_rule_ctx(ctx),
        inputs = compilation_context.headers,
        outputs = [symbol_graph_dir],
        mnemonic = "DocCExtractObjcSymbolGraph",
        executable = "/usr/bin/xcrun",
        arguments = [arguments],
        progress_message = "Extracting Objective-C symbol graph for %{label}",
    )

    return symbol_graph_dir

def _first_docc_bundle(*, target, ctx):
    """Returns the first .docc bundle for the target or its deps by looking in it's data."""
    docc_bundle_paths = {}

    # Find the path to the .docc directory if it exists.
    for data_target in ctx.rule.attr.data:
        for file in data_target.files.to_list():
            components = file.short_path.split("/")
            for index, component in enumerate(components):
                if component.endswith(".docc"):
                    docc_bundle_path = "/".join(components[0:index + 1])
                    docc_bundle_files = docc_bundle_paths[docc_bundle_path] if docc_bundle_path in docc_bundle_paths else []
                    docc_bundle_files.append(file)
                    docc_bundle_paths[docc_bundle_path] = docc_bundle_files
                    break

    # Validate the docc bundle, if any.
    if len(docc_bundle_paths) > 1:
        fail("Expected target %s to have at most one .docc bundle in its data" % target.label)
    if len(docc_bundle_paths) == 0:
        return None, []

    # Return the docc bundle path and files:
    return docc_bundle_paths.items()[0]

def _docc_symbol_graphs_aspect_impl(target, ctx):
    """Creates a DocCSymbolGraphsInfo provider for Swift and Objective-C targets (or targets which bundle them)."""

    direct_symbol_graphs = []

    if SwiftSymbolGraphInfo in target:
        direct_symbol_graphs.extend([
            symbol_graph.symbol_graph_dir
            for symbol_graph in target[SwiftSymbolGraphInfo].direct_symbol_graphs
        ])
    if ctx.rule.kind == "objc_library" and CcInfo in target:
        objc_symbol_graph = _objc_symbol_graph(target = target, ctx = ctx)
        if objc_symbol_graph:
            direct_symbol_graphs.append(objc_symbol_graph)

    transitive_symbol_graphs = [
        dep[DocCSymbolGraphsInfo].symbol_graphs
        for dep in getattr(ctx.rule.attr, "deps", [])
        if DocCSymbolGraphsInfo in dep
    ]

    if not direct_symbol_graphs and not transitive_symbol_graphs:
        return []

    return [
        DocCSymbolGraphsInfo(
            symbol_graphs = depset(
                direct_symbol_graphs,
                transitive = transitive_symbol_graphs,
            ),
        ),
    ]

def _docc_bundle_info_aspect_impl(target, ctx):
    """Creates a DocCBundleInfo provider for targets which have a .docc bundle (or which bundle a target that does)"""

    if hasattr(ctx.rule.attr, "data"):
        docc_bundle, docc_bundle_files = _first_docc_bundle(
            target = target,
            ctx = ctx,
        )
        if docc_bundle:
            return [
                DocCBundleInfo(
                    bundle = docc_bundle,
                    bundle_files = docc_bundle_files,
                ),
            ]
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

    This aspect works with targets that have a `SwiftSymbolGraphInfo` provider, `objc_library` targets (whose symbol
    graphs are extracted from their public headers with `clang -extract-api`), or targets which bundle either of them.
    """,
    attr_aspects = ["deps"],
    attrs = dicts.add(
        apple_support.action_required_attrs(),
        apple_support.platform_constraint_attrs(),
        {
            # Matches the `emit_extension_block_symbols` attribute of `docc_archive` (and the
            # `swift_symbol_graph_aspect` parameter of the same name).
            "emit_extension_block_symbols": attr.string(
                values = ["0", "1"],
            ),
        },
    ),
    toolchains = use_cc_toolchain(),
)
