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

"""Partial implementation for debug symbol file processing."""

load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:defines.bzl",
    "defines",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

# TODO(b/110264170): Expose this provider so that IDEs can use it to reference the dSYM bundles
# contained in the dsym_bundles field.
_AppleDebugInfo = provider(
    doc = """
Private provider to propagate transitive debug symbol information.
""",
    fields = {
        "dsym_bundles": """
Paths to dSYM bundles that this target provides. This includes the paths to dSYM bundles generated
for dependencies of this target (e.g. frameworks and extensions).
""",
        "dsyms": """
Depset of `File` references to dSYM files if requested in the build with --apple_generate_dsym.
""",
        "linkmaps": """
Depset of `File` references to linkmap files if requested in the build with --objc_generate_linkmap.
""",
        "symbols": """
Depset of `File` references to symbols files if requested in the build with
--define=apple.package_symbols=(yes|true|1).
""",
    },
)

def _collect_linkmaps(*, actions, debug_outputs_provider, bundle_name):
    """Collects the available linkmaps from the binary.

    Args:
      actions: The actions provider from `ctx.actions`.
      debug_outputs_provider: The AppleDebugOutput provider for the binary target.
      bundle_name: The name of the output bundle.

    Returns:
      A list of linkmap files, one per linked architecture.
    """
    outputs = []

    for (arch, arch_outputs) in debug_outputs_provider.outputs_map.items():
        linkmap = arch_outputs["linkmap"]
        output_linkmap = actions.declare_file(
            "%s_%s.linkmap" % (bundle_name, arch),
        )
        outputs.append(output_linkmap)
        actions.symlink(target_file = linkmap, output = output_linkmap)

    return outputs

def _bundle_dsym_files(
        *,
        actions,
        bundle_extension = "",
        bundle_name,
        debug_outputs_provider,
        dsym_info_plist_template,
        executable_name,
        platform_prerequisites):
    """Recreates the .dSYM bundle from the AppleDebugOutputs provider.

    The generated bundle will have the same name as the bundle being built (including its
    extension), but with the ".dSYM" extension appended to it.

    If the target being built does not have a binary or if the build it not generating debug
    symbols (`--apple_generate_dsym` is not provided), then this function is a no-op that returns
    an empty list.

    Args:
      actions: The actions provider from `ctx.actions`.
      bundle_extension: The extension for the bundle.
      bundle_name: The name of the output bundle.
      debug_outputs_provider: The AppleDebugOutput provider for the binary target.
      dsym_info_plist_template: File referencing a plist template for dSYM bundles.
      executable_name: The name of the output DWARF executable.
      platform_prerequisites: Struct containing information on the platform being targeted.

    Returns:
      A list of files that comprise the .dSYM bundle, which should be returned as additional
      outputs from the target.
    """
    bundle_name_with_extension = bundle_name + bundle_extension
    dsym_bundle_name = bundle_name_with_extension + ".dSYM"

    output_binary = actions.declare_file(
        "%s/Contents/Resources/DWARF/%s" % (
            dsym_bundle_name,
            executable_name,
        ),
    )
    outputs = [output_binary]

    outputs_map_items = debug_outputs_provider.outputs_map.items()

    # Copy the binary over if there's only a single arch.
    if len(outputs_map_items) == 1:
        _, arch_outputs = outputs_map_items[0]
        dsym_binary = arch_outputs["dsym_binary"]

        # cp instead of symlink here because a dSYM with a symlink to the DWARF data will not be
        # recognized by spotlight which is key for lldb on mac to find a dSYM for a binary.
        # https://lldb.llvm.org/use/symbols.html
        actions.run_shell(
            inputs = [dsym_binary],
            outputs = outputs,
            progress_message = "Copy DWARF into dSYM `%s`" % dsym_binary.short_path,
            command = "cp -p '%s' '%s'" % (dsym_binary.path, output_binary.path),
        )
    else:
        # Create a universal binary if there are more than one arch.
        args = actions.args()
        args.add("lipo")
        args.add("-create")
        args.add("-output", output_binary)

        inputs = []
        for arch, arch_outputs in outputs_map_items:
            dsym_binary = arch_outputs["dsym_binary"]
            args.add_all("-arch", [arch, dsym_binary])
            inputs.append(dsym_binary)

        apple_support.run(
            actions = actions,
            executable = "/usr/bin/xcrun",
            inputs = inputs,
            outputs = outputs,
            arguments = [args],
            mnemonic = "DsymLipo",
            apple_fragment = platform_prerequisites.apple_fragment,
            xcode_config = platform_prerequisites.xcode_version_config,
        )

    # If we found any outputs, create the Info.plist for the bundle as well; otherwise, we just
    # return the empty list. The plist generated by dsymutil only varies based on the bundle name,
    # so we regenerate it here rather than propagate the other one from the apple_binary. (See
    # https://github.com/llvm-mirror/llvm/blob/master/tools/dsymutil/dsymutil.cpp)
    if outputs:
        dsym_plist = actions.declare_file(
            "%s/Contents/Info.plist" % dsym_bundle_name,
        )
        outputs.append(dsym_plist)
        actions.expand_template(
            output = dsym_plist,
            template = dsym_info_plist_template,
            substitutions = {
                "%bundle_name_with_extension%": bundle_name_with_extension,
            },
        )

    return outputs

def _debug_symbols_partial_impl(
        *,
        actions,
        bin_root_path,
        bundle_extension,
        bundle_name,
        debug_dependencies = [],
        debug_outputs_provider = None,
        dsym_info_plist_template,
        executable_name,
        package_symbols = False,
        platform_prerequisites,
        rule_label):
    """Implementation for the debug symbols processing partial."""
    deps_providers = [
        x[_AppleDebugInfo]
        for x in debug_dependencies
        if _AppleDebugInfo in x
    ]

    dsym_bundles = depset(transitive = [x.dsym_bundles for x in deps_providers])

    direct_dsyms = []
    transitive_dsyms = [x.dsyms for x in deps_providers]

    direct_linkmaps = []
    transitive_linkmaps = [x.linkmaps for x in deps_providers]

    direct_symbols = []
    transitive_symbols = [x.symbols for x in deps_providers]

    output_providers = []

    if debug_outputs_provider:
        output_providers.append(debug_outputs_provider)

        # TODO: Remove old API and getattr once bazel is released with this change
        if getattr(platform_prerequisites.objc_fragment, "generate_dsym", False) or getattr(platform_prerequisites.cpp_fragment, "apple_generate_dsym", False):
            dsym_files = _bundle_dsym_files(
                actions = actions,
                bundle_name = bundle_name,
                bundle_extension = bundle_extension,
                debug_outputs_provider = debug_outputs_provider,
                dsym_info_plist_template = dsym_info_plist_template,
                executable_name = executable_name,
                platform_prerequisites = platform_prerequisites,
            )
            direct_dsyms.extend(dsym_files)

            absolute_dsym_bundle_path = paths.join(
                bin_root_path,
                rule_label.package,
                bundle_name + bundle_extension + ".dSYM",
            )
            dsym_bundles = depset(
                [absolute_dsym_bundle_path],
                transitive = [dsym_bundles],
            )

            include_symbols = defines.bool_value(
                config_vars = platform_prerequisites.config_vars,
                define_name = "apple.package_symbols",
                default = False,
            )

            if include_symbols:
                symbols = _generate_symbols(
                    actions = actions,
                    label_name = rule_label.name,
                    debug_provider = debug_outputs_provider,
                    platform_prerequisites = platform_prerequisites,
                )
                direct_symbols.extend(symbols)

        if platform_prerequisites.objc_fragment.generate_linkmap:
            linkmaps = _collect_linkmaps(
                actions = actions,
                debug_outputs_provider = debug_outputs_provider,
                bundle_name = bundle_name,
            )
            direct_linkmaps.extend(linkmaps)

    # Only output dependency debug files if requested.
    # TODO(b/131699846): Remove this.
    propagate_embedded_extra_outputs = defines.bool_value(
        config_vars = platform_prerequisites.config_vars,
        define_name = "apple.propagate_embedded_extra_outputs",
        default = False,
    )

    dsyms_group = depset(direct_dsyms, transitive = transitive_dsyms)
    linkmaps_group = depset(direct_linkmaps, transitive = transitive_linkmaps)
    symbols_group = depset(direct_symbols, transitive = transitive_symbols)

    if propagate_embedded_extra_outputs:
        output_files = depset(transitive = [dsyms_group, linkmaps_group])
    else:
        output_files = depset(direct_dsyms + direct_linkmaps)

    if package_symbols and symbols_group:
        bundle_files = [(
            processor.location.archive,
            "Symbols",
            symbols_group,
        )]
    else:
        bundle_files = []

    output_providers.append(
        _AppleDebugInfo(
            dsym_bundles = dsym_bundles,
            dsyms = dsyms_group,
            linkmaps = linkmaps_group,
            symbols = symbols_group,
        ),
    )

    return struct(
        bundle_files = bundle_files,
        output_files = output_files,
        providers = output_providers,
        output_groups = {
            "dsyms": dsyms_group,
            "linkmaps": linkmaps_group,
        },
    )

def _generate_symbols(
        *,
        actions,
        label_name,
        debug_provider,
        platform_prerequisites):
    dsym_binaries = []

    symbols_dir = intermediates.directory(
        actions,
        label_name,
        "symbols_files",
    )
    outputs = [symbols_dir]

    commands = ["mkdir -p \"${OUTPUT_DIR}\""]

    for (arch, arch_outputs) in debug_provider.outputs_map.items():
        dsym_binary = arch_outputs["dsym_binary"]
        dsym_binaries.append(dsym_binary)
        commands.append(
            ("/usr/bin/xcrun symbols -noTextInSOD -noDaemon -arch {arch} " +
             "-symbolsPackageDir \"${{OUTPUT_DIR}}\" \"{dsym_binary}\"").format(
                arch = arch,
                dsym_binary = dsym_binary.path,
            ),
        )

    apple_support.run_shell(
        actions = actions,
        inputs = dsym_binaries,
        outputs = outputs,
        command = "\n".join(commands),
        env = {"OUTPUT_DIR": symbols_dir.path},
        mnemonic = "GenerateSymbolsFiles",
        apple_fragment = platform_prerequisites.apple_fragment,
        xcode_config = platform_prerequisites.xcode_version_config,
    )

    return outputs

def debug_symbols_partial(
        *,
        actions,
        bin_root_path,
        bundle_extension,
        bundle_name,
        debug_dependencies = [],
        debug_outputs_provider = None,
        dsym_info_plist_template,
        executable_name,
        package_symbols = False,
        platform_prerequisites,
        rule_label):
    """Constructor for the debug symbols processing partial.

    This partial collects all of the transitive debug files information. The output of this partial
    are the debug output files for the target being processed _plus_ all of the dependencies debug
    symbol files. This includes dSYM bundles and linkmaps. With this, for example, by building an
    ios_application target with --apple_generate_dsym, this partial will return the dSYM bundle of
    the ios_application itself plus the dSYM bundles of any ios_framework and ios_extension
    dependencies there may be, which will force bazel to present these files in the output files
    section of a successful build.

    Args:
      actions: The actions provider from `ctx.actions`.
      bin_root_path: The path to the root `-bin` directory.
      bundle_extension: The extension for the bundle.
      bundle_name: The name of the output bundle.
      debug_dependencies: List of targets from which to collect the transitive dependency debug
        information to propagate them upstream.
      debug_outputs_provider: The AppleDebugOutputs provider containing the references to the debug
        outputs of this target's binary.
      dsym_info_plist_template: File referencing a plist template for dSYM bundles.
      executable_name: The name of the output DWARF executable.
      package_symbols: Whether the partial should package the symbols files for all binaries.
      platform_prerequisites: Struct containing information on the platform being targeted.
      rule_label: The label of the target being analyzed.

    Returns:
      A partial that returns the debug output files, if any were requested.
    """
    return partial.make(
        _debug_symbols_partial_impl,
        actions = actions,
        bin_root_path = bin_root_path,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        debug_dependencies = debug_dependencies,
        debug_outputs_provider = debug_outputs_provider,
        dsym_info_plist_template = dsym_info_plist_template,
        executable_name = executable_name,
        package_symbols = package_symbols,
        platform_prerequisites = platform_prerequisites,
        rule_label = rule_label,
    )
