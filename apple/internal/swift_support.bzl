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

# Define the loadable module that lists the exported symbols in this file.
swift_support = struct(
    swift_usage_info = _swift_usage_info,
    uses_swift = _uses_swift,
)
