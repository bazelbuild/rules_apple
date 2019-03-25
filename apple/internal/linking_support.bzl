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
load(
    "@bazel_skylib//lib:collections.bzl",
    "collections",
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

def _register_linking_action(ctx, extra_linkopts = []):
    """Registers linking actions using the Starlark Linking API for Apple binaries.

    This method will add the linkopts as added on the rule descriptor, in addition to any extra
    linkopts given when invoking this method.

    Args:
        ctx: The rule context.
        extra_linkopts: Extra linkopts to add to the linking action.

    Returns:
        A descriptor `struct` with the following fields:
            * `provider`: The binary provider that represents the linked binary.
            * `debug_outputs_provider`: The provider containing the debug symbols, if any were
              requested.
            * `artifact`: The final linked binary `File`.
    """
    rule_descriptor = rule_support.rule_descriptor(ctx)

    rpaths = rule_descriptor.rpaths
    linkopts = []
    if rpaths:
        linkopts.extend(collections.before_each("-rpath", rpaths))

    linkopts.extend(rule_descriptor.extra_linkopts + extra_linkopts)

    binary_provider_struct = apple_common.link_multi_arch_binary(
        ctx = ctx,
        extra_linkopts = linkopts,
    )
    binary_provider = binary_provider_struct.binary_provider
    debug_outputs_provider = binary_provider_struct.debug_outputs_provider
    binary_artifact = binary_provider.binary

    return struct(
        provider = binary_provider,
        debug_outputs_provider = debug_outputs_provider,
        artifact = binary_artifact,
    )

linking_support = struct(
    register_linking_action = _register_linking_action,
    sectcreate_objc_provider = _sectcreate_objc_provider,
)
