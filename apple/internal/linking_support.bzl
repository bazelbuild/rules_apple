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

def _register_linking_action(ctx, *, stamp, avoid_deps = [], extra_linkopts = []):
    """Registers linking actions using the Starlark Linking API for Apple binaries.

    This method will add the linkopts as added on the rule descriptor, in addition to any extra
    linkopts given when invoking this method.

    Args:
        ctx: The rule context.
        stamp: Whether to include build information in the linked binary. If 1, build
            information is always included. If 0, the default build information is always
            excluded. If -1, the default behavior is used, which may be overridden by the
            `--[no]stamp` flag. This should be set to 0 when generating the executable output
            for test rules.
        extra_linkopts: Extra linkopts to add to the linking action.

    Returns:
        The `struct` returned by `apple_common.link_multi_arch_binary`, which contains the
        following fields:

        *   `binary_provider`: A provider describing the binary that was linked. This is an
            instance of either `AppleExecutableBinaryInfo`, `AppleDylibBinaryInfo`, or
            `AppleLoadableBundleBinaryInfo`; all three have a `binary` field that is the linked
            binary `File`.
        *   `debug_outputs_provider`: An `AppleDebugOutputsInfo` provider that contains debug
            outputs, such as linkmaps and dSYM binaries.
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

    return apple_common.link_multi_arch_binary(
        ctx = ctx,
        avoid_deps = avoid_deps,
        extra_linkopts = linkopts,
        extra_link_inputs = link_inputs,
        stamp = stamp,
    )

linking_support = struct(
    register_linking_action = _register_linking_action,
    sectcreate_objc_provider = _sectcreate_objc_provider,
)
