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
    "@build_bazel_rules_apple//apple/internal/aspects:swift_usage_aspect.bzl",
    "SwiftUsageInfo",
)
load("@build_bazel_rules_swift//swift:providers.bzl", "SwiftInfo")

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

def _has_only_one_non_system_swift_module(*, target):
    """Indicates if the given target references any non-system Swift modules.

    Args:
        target: A Target representing a dep for a given split from `deps` on the XCFramework rule.

    Returns:
        `True` if a non-system module was found from the target's SwiftInfo provider, `False`
        otherwise.
    """
    if SwiftInfo not in target:
        return False

    module_names = []

    # Covers both direct and transitive modules, from how the SwiftInfo provider is constructed.
    for module in target[SwiftInfo].transitive_modules.to_list():
        if module.swift and not module.is_system:
            module_names.append(module.name)

    # If there is more than one non-system Swift module in the transitive modules, then there is an
    # invalid Swift module dependency present within deps.
    if len(module_names) > 1:
        fail("""
Error: Found more than one Swift module dependency in this XCFramework's deps: \
{module_names}

Check that you are only referencing ONE Swift module, such as from a a swift_library rule, and \
that there are no additional Swift modules referenced outside of its private_deps, such as from an \
additional swift_library dependency.
        """.format(module_names = ", ".join(module_names)))

    return bool(module_names)

def _target_supporting_swift_xcframework_interfaces(targets):
    """Returns a target with SwiftInfo capable of supporting Swift XCFramework interfaces.

    If there are issues with the dependencies found, they will be raised as failures during the
    build's analysis phase.

    Args:
        targets: A List of Targets representing `deps` for a given split on the XCFramework rule.

    Returns:
        A target referencing a `SwiftInfo` provider if a module capable of supporting Swift
        XCFramework interfaces was found, `None` if not.
    """

    direct_swift_module = None

    for target in targets:
        if _has_only_one_non_system_swift_module(target = target):
            # Check that there's only one direct Swift module in an XCFramework rule's deps.
            if not direct_swift_module:
                direct_swift_module = target
            else:
                fail("""
Error: Found more than one non-system Swift module in the deps of this XCFramework rule. Check \
that you are not directly referencing more than one swift_library rule in the deps of the rule.
                """)

    return direct_swift_module

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
    for target in targets:
        if SwiftUsageInfo in target:
            return True
    return False

swift_support = struct(
    target_supporting_swift_xcframework_interfaces = _target_supporting_swift_xcframework_interfaces,
    uses_swift = _uses_swift,
)
