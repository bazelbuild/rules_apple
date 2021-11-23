# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Support for linking related actions."""

load("@build_bazel_apple_support//lib:lipo.bzl", "lipo")
load(
    "@build_bazel_rules_apple//apple/internal:rule_support.bzl",
    "rule_support",
)

def _sectcreate_objc_provider(segname, sectname, file):
    """Returns an objc provider that propagates a section in a linked binary.

    This function creates a new objc provider that contains the necessary linkopts
    to create a new section in the binary to which the provider is propagated; it
    is equivalent to the `ld` flag `-sectcreate segname sectname file`. This can
    be used, for example, to embed entitlements in a simulator executable (since
    they are not applied during code signing).

    Args:
      segname: The name of the segment in which the section will be created.
      sectname: The name of the section to create.
      file: The file whose contents will be used as the content of the section.

    Returns:
      An objc provider that propagates the section linkopts.
    """

    # linkopts get deduped, so use a single option to pass then through as a
    # set.
    linkopts = ["-Wl,-sectcreate,%s,%s,%s" % (segname, sectname, file.path)]
    return apple_common.new_objc_provider(
        linkopt = depset(linkopts, order = "topological"),
        link_inputs = depset([file]),
    )

def _parse_platform_key(key):
    """Parses a string key from a `link_multi_arch_binary` result dictionary.

    Args:
        key: A string key from the `outputs_by_platform` dictionary of the
            struct returned by `apple_common.link_multi_arch_binary`.

    Returns:
        A `struct` containing three fields:

        *   `platform`: A string denoting the platform: `ios`, `macos`, `tvos`,
            or `watchos`.
        *   `arch`: The CPU architecture (e.g., `x86_64` or `arm64`).
        *   `environment`: The target environment: `device` or `simulator`.
    """
    platform, _, rest = key.partition("_")
    if platform == "darwin":
        platform = "macos"

    arch, _, environment = rest.rpartition("_")
    return struct(platform = platform, arch = arch, environment = environment)

def _register_linking_action(
        ctx,
        *,
        avoid_deps = [],
        bundle_loader = None,
        extra_linkopts = [],
        extra_link_inputs = [],
        stamp):
    """Registers linking actions using the Starlark Linking API for Apple binaries.

    This method will add the linkopts as added on the rule descriptor, in addition to any extra
    linkopts given when invoking this method.

    Args:
        ctx: The rule context.
        avoid_deps: A list of `Target`s representing dependencies of the binary but whose
            symbols should not be linked into it.
        bundle_loader: For Mach-O bundles, the `Target` whose binary will load this bundle.
            This target must propagate the `apple_common.AppleExecutableBinary` provider.
            This simplifies the process of passing the bundle loader to all the arguments
            that need it: the binary will automatically be added to the linker inputs, its
            path will be added to linkopts via `-bundle_loader`, and the `apple_common.Objc`
            provider of its dependencies (obtained from the `AppleExecutableBinary` provider)
            will be passed as an additional `avoid_dep` to ensure that those dependencies are
            subtracted when linking the bundle's binary.
        extra_linkopts: Extra linkopts to add to the linking action.
        extra_link_inputs: Extra input files to the linking action.
        stamp: Whether to include build information in the linked binary. If 1, build
            information is always included. If 0, the default build information is always
            excluded. If -1, the default behavior is used, which may be overridden by the
            `--[no]stamp` flag. This should be set to 0 when generating the executable output
            for test rules.

    Returns:
        A `struct` which contains the following fields, which are a superset of the fields
        returned by `apple_common.link_multi_arch_binary`:

        *   `binary`: The final binary `File` that was linked. If only one architecture was
            requested, then it is a symlink to that single architecture binary. Otherwise, it
            is a new universal (fat) binary obtained by invoking `lipo`.
        *   `objc`: The `apple_common.Objc` provider containing information about the targets
            that were linked.
        *   `outputs`: A `list` of `struct`s containing the single-architecture binaries and
            debug outputs, with identifying information about the target platform, architecture,
            and environment that each was built for.
        *   `output_groups`: A `dict` containing output groups that should be returned in the
            `OutputGroupInfo` provider of the calling rule.
    """
    linkopts = []
    link_inputs = []

    # Add linkopts/linker inputs that are common to all the rules.
    for exported_symbols_list in ctx.files.exported_symbols_lists:
        linkopts.append(
            "-Wl,-exported_symbols_list,{}".format(exported_symbols_list.path),
        )
        link_inputs.append(exported_symbols_list)

    # Compatibility path for `apple_binary`, which does not have a product type.
    if hasattr(ctx.attr, "_product_type"):
        rule_descriptor = rule_support.rule_descriptor(ctx)
        linkopts.extend(["-Wl,-rpath,{}".format(rpath) for rpath in rule_descriptor.rpaths])
        linkopts.extend(rule_descriptor.extra_linkopts)

    linkopts.extend(extra_linkopts)

    all_avoid_deps = list(avoid_deps)
    if bundle_loader:
        bundle_loader_file = bundle_loader[apple_common.AppleExecutableBinary].binary
        all_avoid_deps.append(bundle_loader)
        linkopts.extend(["-bundle_loader", bundle_loader_file.path])
        link_inputs.append(bundle_loader_file)

    linking_outputs = apple_common.link_multi_arch_binary(
        ctx = ctx,
        avoid_deps = all_avoid_deps,
        extra_linkopts = linkopts,
        extra_link_inputs = link_inputs,
        stamp = stamp,
        should_lipo = False,
    )

    fat_binary = ctx.actions.declare_file("{}_lipobin".format(ctx.label.name))

    if len(linking_outputs.outputs) > 1:
        lipo.create(
            actions = ctx.actions,
            inputs = [output.binary for output in linking_outputs.outputs],
            output = fat_binary,
            apple_fragment = ctx.fragments.apple,
            xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
        )
    else:
        # Symlink if there was only a single architecture created; it's faster.
        output = linking_outputs.outputs[0]
        ctx.actions.symlink(target_file = output.binary, output = fat_binary)

    return struct(
        binary = fat_binary,
        debug_outputs_provider = linking_outputs.debug_outputs_provider,
        objc = linking_outputs.objc,
        outputs = linking_outputs.outputs,
        output_groups = linking_outputs.output_groups,
    )

linking_support = struct(
    parse_platform_key = _parse_platform_key,
    register_linking_action = _register_linking_action,
    sectcreate_objc_provider = _sectcreate_objc_provider,
)
