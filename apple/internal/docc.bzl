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

"""Defines rules for building Apple DocC targets."""

load(
    "@apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)
load(
    "//apple:providers.bzl",
    "DocCBundleInfo",
    "DocCSymbolGraphsInfo",
)
load(
    "//apple/internal:apple_toolchains.bzl",
    "apple_toolchain_utils",
)
load(
    "//apple/internal:features_support.bzl",
    "features_support",
)
load(
    "//apple/internal:platform_support.bzl",
    "platform_support",
)
load(
    "//apple/internal:providers.bzl",
    "new_applebinaryinfo",
)
load(
    "//apple/internal:swift_support.bzl",
    "swift_support",
)
load(
    "//apple/internal/aspects:docc_archive_aspect.bzl",
    "docc_bundle_info_aspect",
    "docc_symbol_graphs_aspect",
)

# The checkout path that symbol graph source locations are anchored at when
# `source_service` is set. It doesn't need to exist, since `docc` only uses it
# to compute the paths of source files relative to the repository.
_SOURCE_CHECKOUT_PATH = "/__docc_checkout__"

def _docc_archive_impl(ctx):
    """Builds a .doccarchive for the given module.
    """

    apple_fragment = ctx.fragments.apple
    apple_xplat_toolchain_info = apple_toolchain_utils.get_xplat_toolchain(ctx)
    default_code_listing_language = ctx.attr.default_code_listing_language
    diagnostic_level = ctx.attr.diagnostic_level
    enable_inherited_docs = ctx.attr.enable_inherited_docs
    execution_requirements = {}
    fallback_bundle_identifier = ctx.attr.fallback_bundle_identifier
    fallback_bundle_version = ctx.attr.fallback_bundle_version
    fallback_display_name = ctx.attr.fallback_display_name
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    hosting_base_path = ctx.attr.hosting_base_path
    source_service = ctx.attr.source_service
    source_service_base_url = ctx.attr.source_service_base_url
    kinds = ctx.attr.kinds
    transform_for_static_hosting = ctx.attr.transform_for_static_hosting
    xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]
    dep = ctx.attr.dep
    symbol_graphs_info = None
    docc_bundle_info = None
    docc_build_inputs = []

    platform_prerequisites = platform_support.platform_prerequisites(
        apple_fragment = ctx.fragments.apple,
        apple_platform_info = platform_support.apple_platform_info_from_rule_ctx(ctx),
        build_settings = apple_xplat_toolchain_info.build_settings,
        config_vars = ctx.var,
        cpp_fragment = ctx.fragments.cpp,
        device_families = None,
        explicit_minimum_deployment_os = None,
        explicit_minimum_os = None,
        features = features,
        objc_fragment = ctx.fragments.objc,
        uses_swift = swift_support.uses_swift([ctx.attr.dep]),
        xcode_version_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
    )

    platform = platform_prerequisites.platform

    if DocCSymbolGraphsInfo in dep:
        symbol_graphs_info = dep[DocCSymbolGraphsInfo]
    if DocCBundleInfo in dep:
        docc_bundle_info = dep[DocCBundleInfo]

    if not symbol_graphs_info and not docc_bundle_info:
        fail("At least one of DocCSymbolGraphsInfo or DocCBundleInfo must be provided for target %s" % ctx.attr.name)

    if bool(source_service) != bool(source_service_base_url):
        fail("`source_service` and `source_service_base_url` must be set together for target %s" % ctx.attr.name)

    symbol_graphs = symbol_graphs_info.symbol_graphs.to_list() if symbol_graphs_info else []

    if ctx.attr.name.endswith(".doccarchive"):
        doccarchive_dir = ctx.actions.declare_directory(ctx.attr.name)
    else:
        doccarchive_dir = ctx.actions.declare_directory("%s.doccarchive" % ctx.attr.name)

    # Command and required arguments
    arguments = ctx.actions.args()
    arguments.add("docc")
    arguments.add("convert")
    arguments.add("--fallback-display-name", fallback_display_name)
    arguments.add("--fallback-bundle-identifier", fallback_bundle_identifier)
    arguments.add("--fallback-bundle-version", fallback_bundle_version)
    arguments.add("--output-dir", doccarchive_dir.path)

    # Optional agruments
    if default_code_listing_language:
        arguments.add("--default-code-listing-language", default_code_listing_language)
    if diagnostic_level:
        arguments.add("--diagnostic-level", diagnostic_level)
    if enable_inherited_docs:
        arguments.add("--enable-inherited-docs")
    if kinds:
        arguments.add_all("--kind", kinds)
    if transform_for_static_hosting:
        arguments.add("--transform-for-static-hosting")
    if hosting_base_path:
        arguments.add("--hosting-base-path", hosting_base_path)
    if source_service:
        arguments.add("--source-service", source_service)
        arguments.add("--source-service-base-url", source_service_base_url)
        arguments.add("--checkout-path", _SOURCE_CHECKOUT_PATH)

    # Add symbol graphs.
    #
    # `docc convert` only honors a single `--additional-symbol-graph-dir`
    # argument, silently ignoring all but one when it is repeated. Collect
    # every module's symbol graphs into one directory and pass that single
    # directory instead; docc discovers symbol graph files in it recursively.
    combined_symbol_graphs = None
    if symbol_graphs_info:
        combined_symbol_graphs = ctx.actions.declare_directory(
            "%s_combined_symbol_graphs" % ctx.attr.name,
        )
        combine_arguments = ctx.actions.args()
        combine_arguments.add(combined_symbol_graphs.path)
        combine_arguments.add(_SOURCE_CHECKOUT_PATH if source_service else "")
        combine_arguments.add_all(symbol_graphs, expand_directories = False)
        ctx.actions.run_shell(
            inputs = symbol_graphs,
            outputs = [combined_symbol_graphs],
            mnemonic = "DocCCollectSymbolGraphs",
            progress_message = "Collecting symbol graphs for %{label}",
            command = """\
set -eu
output_dir="$1"
checkout_path="$2"
shift 2
index=0
for symbol_graph_dir in "$@"; do
    cp -RL "$symbol_graph_dir" "$output_dir/$index"
    index=$((index + 1))
done

# Symbol graphs reference source files relative to the execution root, which
# `docc` can't map to the source service. Anchor those paths (except for
# generated and external files) at a fixed checkout path instead.
if [ -n "$checkout_path" ]; then
    chmod -R u+w "$output_dir"
    find "$output_dir" -type f -name '*.json' | while read -r symbol_graph; do
        sed -E \
            -e 's#("uri" *: *"file://)(\\./)?([^/"])#\\1'"$checkout_path"'/\\3#g' \
            -e 's#file://'"$checkout_path"'/(bazel-out|external)/#file://\\1/#g' \
            "$symbol_graph" > "$symbol_graph.tmp"
        mv "$symbol_graph.tmp" "$symbol_graph"
    done
fi
""",
            arguments = [combine_arguments],
        )
        arguments.add("--additional-symbol-graph-dir", combined_symbol_graphs.path)
        docc_build_inputs.append(combined_symbol_graphs)

    # The .docc bundle (if provided, only one is allowed)
    if docc_bundle_info:
        arguments.add(docc_bundle_info.bundle)

        # TODO: no-sandbox seems to be required when running docc convert with a .docc bundle provided
        # in the sandbox the tool is unable to open the .docc bundle.
        execution_requirements["no-sandbox"] = "1"
        docc_build_inputs.extend(docc_bundle_info.bundle_files)

    apple_support.run(
        actions = ctx.actions,
        xcode_config = xcode_config,
        apple_fragment = apple_fragment,
        inputs = depset(docc_build_inputs),
        outputs = [doccarchive_dir],
        mnemonic = "DocCConvert",
        executable = "/usr/bin/xcrun",
        arguments = [arguments],
        progress_message = "Converting .doccarchive for %{label}",
        execution_requirements = execution_requirements,
    )

    # Create an executable shell script that runs `docc preview` on the .doccarchive.
    preview_script = ctx.actions.declare_file("%s_preview.sh" % ctx.attr.name)
    ctx.actions.expand_template(
        output = preview_script,
        template = ctx.file._preview_template,
        substitutions = {
            "{docc_bundle}": docc_bundle_info.bundle if docc_bundle_info else "",
            "{fallback_bundle_identifier}": fallback_bundle_identifier,
            "{fallback_bundle_version}": str(fallback_bundle_version),
            "{fallback_display_name}": fallback_display_name,
            "{platform}": platform.name_in_plist,
            "{sdk_version}": str(xcode_config.sdk_version_for_platform(platform)),
            "{symbol_graph_dirs}": combined_symbol_graphs.path if combined_symbol_graphs else "",
            "{target_name}": ctx.attr.name,
            "{xcode_version}": str(xcode_config.xcode_version()),
        },
        is_executable = True,
    )

    # Limiting the contents of AppleBinaryInfo to what is necessary for testing and validation.
    doccarchive_binary_info = new_applebinaryinfo(
        binary = doccarchive_dir,
        infoplist = None,
        product_type = None,
    )

    return [
        DefaultInfo(
            files = depset([doccarchive_dir]),
            executable = preview_script,
            runfiles = ctx.runfiles(files = [
                preview_script,
            ] + docc_build_inputs),
        ),
        doccarchive_binary_info,
    ]

docc_archive = rule(
    implementation = _docc_archive_impl,
    exec_groups = apple_toolchain_utils.use_apple_exec_group_toolchain(),
    fragments = [
        "apple",
        "cpp",
        "objc",
    ],
    doc = """
Builds a .doccarchive for the given dependency.
The target created by this rule can also be `run` to preview the generated documentation in Xcode.

Both Swift and Objective-C are supported. Symbol graphs for Swift targets are extracted with
`swift-symbolgraph-extract`, and symbol graphs for `objc_library` targets are extracted from their
public headers (`hdrs`) with `clang -extract-api`.

The symbol graphs of transitive Swift dependencies are included. Because a DocC archive documents a
single module, the symbol graphs of Objective-C dependencies are not included, unless the `dep`
doesn't define a module itself: bundling rules (e.g. `ios_framework`) and `objc_library` targets
without public headers use the Objective-C symbol graphs of their direct `deps`. The latter can be
used to attach a `.docc` bundle (in its `data`) to an existing library.

Example:

```starlark
load("@rules_apple//apple:docc.bzl", "docc_archive")

docc_archive(
    name = "Lib.doccarchive",
    dep = ":Lib",
    fallback_bundle_identifier = "com.example.lib",
    fallback_bundle_version = "1.0.0",
    fallback_display_name = "Lib",
)
```""",
    attrs = dicts.add(
        apple_support.action_required_attrs(),
        apple_support.platform_constraint_attrs(),
        {
            "dep": attr.label(
                aspects = [
                    docc_bundle_info_aspect,
                    docc_symbol_graphs_aspect,
                ],
                providers = [[DocCBundleInfo], [DocCSymbolGraphsInfo]],
            ),
            "default_code_listing_language": attr.string(
                doc = "A fallback default language for code listings if no value is provided in the documentation bundle's Info.plist file.",
            ),
            "diagnostic_level": attr.string(
                doc = """
Filters diagnostics above this level from output
This filter level is inclusive. If a level of `information` is specified, diagnostics with a severity up to and including `information` will be printed.
Must be one of "error", "warning", "information", or "hint"
                """,
                values = ["error", "warning", "information", "hint"],
            ),
            # TODO: use `attr.bool` once https://github.com/bazelbuild/bazel/issues/22809 is resolved.
            "emit_extension_block_symbols": attr.string(
                default = "0",
                doc = """
Defines if the symbol graph information for `extension` blocks should be
emitted in addition to the default symbol graph information.

This value must be either `"0"` or `"1"`.When the value is `"1"`, the symbol
graph information for `extension` blocks will be emitted in addition to
the default symbol graph information. The default value is `"0"`.

For Objective-C targets, a value of `"1"` includes the members of categories
on types from other modules (e.g. a category on `NSString`).
                """,
                values = ["0", "1"],
            ),
            "enable_inherited_docs": attr.bool(
                default = False,
                doc = "Inherit documentation for inherited symbols.",
            ),
            "fallback_bundle_identifier": attr.string(
                doc = "A fallback bundle identifier if no value is provided in the documentation bundle's Info.plist file.",
                mandatory = True,
            ),
            "fallback_bundle_version": attr.string(
                doc = "A fallback bundle version if no value is provided in the documentation bundle's Info.plist file.",
                mandatory = True,
            ),
            "fallback_display_name": attr.string(
                doc = "A fallback display name if no value is provided in the documentation bundle's Info.plist file.",
                mandatory = True,
            ),
            "hosting_base_path": attr.string(
                doc = "The base path your documentation website will be hosted at. For example, to deploy your site to 'example.com/my_name/my_project/documentation' instead of 'example.com/documentation', pass '/my_name/my_project' as the base path.",
                mandatory = False,
            ),
            "kinds": attr.string_list(
                doc = "The kinds of entities to filter generated documentation for.",
            ),
            "minimum_access_level": attr.string(
                default = "public",
                doc = """"
The minimum access level of the declarations that should be emitted in the symbol graphs.
This value must be either `fileprivate`, `internal`, `private`, or `public`. The default value is `public`.
This only applies to Swift targets; Objective-C symbol graphs always contain the declarations of the public headers.
                """,
                values = [
                    "fileprivate",
                    "internal",
                    "private",
                    "public",
                ],
            ),
            "source_service": attr.string(
                doc = """
The source code service used to link the documentation of symbols to their source files.
Must be one of "github", "gitlab", or "bitbucket". Requires `source_service_base_url` to be set.
Only source files in the main repository are linked, generated and external files are not.
                """,
                values = ["", "github", "gitlab", "bitbucket"],
            ),
            "source_service_base_url": attr.string(
                doc = """
The base URL where the source files of the main repository are browsable, for example
`https://github.com/<org>/<repo>/blob/main`. Requires `source_service` to be set.
                """,
            ),
            "transform_for_static_hosting": attr.bool(
                default = True,
            ),
            "_preview_template": attr.label(
                allow_single_file = True,
                default = "//apple/internal/templates:docc_preview_template",
            ),
        },
    ),
    executable = True,
)
