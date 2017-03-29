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

load("//apple/bundling:provider_support.bzl",
     "provider_support")


def _uses_swift(ctx):
  """Returns True if the current target uses Swift.

  Note that this is not propagated through extensions or child apps (such as
  Watch) -- that is, an Objective-C application that contains a Swift
  application extension does not "use Swift" in the sense denoted by this
  function.

  Args:
    ctx: The Skylark context.
  Returns:
    True if the current target directly uses Swift; otherwise, False.
  """
  swift_providers = provider_support.binary_or_deps_providers(
      ctx, "AppleBundlingSwift")
  return any([p.uses_swift for p in swift_providers])


# Define the loadable module that lists the exported symbols in this file.
swift_support = struct(
    uses_swift=_uses_swift,
)
