# Copyright 2017 The Bazel Authors. All rights reserved.
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

"""Support functions for working with Swift."""

load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "SwiftUsageInfo",
    "swift_common",
    "swift_usage_aspect",
)

def _swift_usage_info(targets):
    """Returns the `SwiftUsageInfo` provider for any of the given targets.

    Since all Swift dependencies in the same target configuration should be built
    with the same toolchain, we can safely just take the first one we see in the
    given list.

    Args:
      targets: List of targets to check.

    Returns:
      The `SwiftUsageInfo` provider for any of the targets in the list, or `None`
      if none of the targets transitively used Swift.
    """
    for x in targets:
        if SwiftUsageInfo in x:
            return x[SwiftUsageInfo]
    return None

def _uses_swift(targets):
    """Returns True if any of the given targets uses Swift.

    Note that this is not propagated through extensions or child apps (such as
    Watch) -- that is, an Objective-C application that contains a Swift
    application extension does not "use Swift" in the sense denoted by this
    function.

    Args:
      targets: List of targets to check.

    Returns:
      True if any of the targets directly uses Swift; otherwise, False.
    """
    return (_swift_usage_info(targets) != None)

def _swift_runtime_linkopts_impl(ctx):
    """Implementation of the internal `swift_runtime_linkopts` rule.

    This rule is an internal implementation detail and should not be used directly
    by clients. It examines the dependencies of the target to determine if Swift
    was used and, if so, propagates additional linker options to have the runtime
    either dynamically or statically linked.

    Args:
      ctx: The rule context.

    Returns:
      A `struct` containing the `objc` provider that should be propagated to a
      binary to dynamically or statically link the Swift runtime.
    """
    linkopts = []
    swift_usage_info = _swift_usage_info(ctx.attr.deps)
    if swift_usage_info:
        linkopts.extend(swift_common.swift_runtime_linkopts(
            is_static = ctx.attr.is_static,
            is_test = ctx.attr.is_test,
            toolchain = swift_usage_info.toolchain,
        ))

    if linkopts:
        return [apple_common.new_objc_provider(linkopt = depset(linkopts, order = "topological"))]
    else:
        return [apple_common.new_objc_provider()]

swift_runtime_linkopts = rule(
    _swift_runtime_linkopts_impl,
    attrs = {
        "is_static": attr.bool(mandatory = True),
        "is_test": attr.bool(mandatory = True),
        "deps": attr.label_list(
            aspects = [swift_usage_aspect],
            mandatory = True,
        ),
    },
    fragments = ["apple", "objc"],
)

# Define the loadable module that lists the exported symbols in this file.
swift_support = struct(
    uses_swift = _uses_swift,
)
