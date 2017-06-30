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

"""Support functions for working with Xcode configurations."""


def _is_xcode_at_least_version(apple_fragment, version):
  """Returns True if we are building with at least the given Xcode version.

  Args:
    apple_fragment: The Apple configuration fragment.
    version: The minimum desired Xcode version, as a dotted version string.
  Returns:
    True if the current target is being built with a version of Xcode at least
    as high as the given version.
  """
  xcode_version = apple_fragment.xcode_version()
  if not xcode_version:
    fail("Could not determine Xcode version at all. This likely means Xcode " +
         "isn't available; if you think this is a mistake, please file a " +
         "bug.")

  # TODO(b/38307306): Clean this up once DottedVersions can be created from
  # Skylark.
  current_version = str(xcode_version)
  current_components = [int(c) for c in current_version.split(".")]
  desired_components = [int(c) for c in version.split(".")]
  return current_components >= desired_components


# Define the loadable module that lists the exported symbols in this file.
xcode_support = struct(
    is_xcode_at_least_version=_is_xcode_at_least_version,
)
