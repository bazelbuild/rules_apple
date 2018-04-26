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

"""Support functions to detect mocking during integration tests."""


def _is_provisioning_mocked(ctx):
  """Returns a value indicating if provisioning operations should be mocked.

  Provisioning operations will be mocked if the flag
  `--define=bazel_apple_rules.mock_provisioning=true` is passed during the
  build.

  If provisioning is mocked, then provisioning profile extractions (team prefix
  ID and entitlements) are not preceded by a call to the `security cms -D`
  command; instead, the provisioning profile is used as-is. This allows a plain
  (unsigned) XML plist with the expected contents be used during integration
  test builds, rather than requiring a proper one obtained from Apple (which
  would have to be associated with a real developer account).

  Args:
    ctx: The Skylark context.

  Returns:
    True/False on if the provisioning should be mocked out.
  """
  return ctx.var.get(
      "bazel_rules_apple.mock_provisioning", "").lower() == "true"


# Define the loadable module that lists the exported symbols in this file.
mock_support = struct(
    is_provisioning_mocked=_is_provisioning_mocked,
)
