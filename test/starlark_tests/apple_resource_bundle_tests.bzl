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

load(
    "//test/starlark_tests/rules:output_group_test.bzl",
    "output_group_test",
)

"""apple_resource_bundle Starlark tests."""

def apple_resource_bundle_test_suite(name):
    """Test suite for apple_resource_bundle.

    Args:
      name: the base name to be used in things created by this macro
    """

    output_group_test(
        name = "{}_output_group".format(name),
        target_under_test = "//test/starlark_tests/resources:resource_bundle",
        expected_output_groups = ["bundle"],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
