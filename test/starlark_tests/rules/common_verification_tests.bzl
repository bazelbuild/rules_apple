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

"""Macros for common verification test tests."""

load(
    ":rules/apple_verification_test.bzl",
    "apple_verification_test",
)

def archive_contents_test(
        name,
        build_type,
        target_under_test,
        contains = [],
        not_contains = [],
        is_binary_plist = [],
        is_not_binary_plist = [],
        plist_test_file = "",
        plist_test_values = {},
        asset_catalog_test_file = "",
        asset_catalog_test_contains = [],
        asset_catalog_test_not_contains = [],
        **kwargs):
    """Macro for calling the apple_verification_test with archive_contents_test.sh.

    List of common environmentals available to use within file paths:
        ARCHIVE_ROOT: The base of the archive that is exapanded for the test.
        BINARY: The path to the primary executable binary.
        BUNDLE_ROOT: The path to the root of the payload for the bundle.
        CONTENT_ROOT: The path for the "Contents" for the bundle.
        RESOURCE_ROOT: The path for the "Resources" for the bundle.

    Args:
        name: Name of generated test target.
        build_type: Type of build for the target. Possible values are `simulator` and `device`.
        target_under_test: The Apple bundle target whose contents are to be verified.
        contains:  Optional, List of paths to test for existance for within the bundle. The string
            will be expanded with bash and can contain environmental variables (e.g. $BUNDLE_ROOT)
        not_contains:  Optional, List of paths to test for non-existance for within the bundle.
            The string will be expanded with bash and can contain env variables (e.g. $BUNDLE_ROOT)
        is_binary_plist:  Optional, List of paths to files to test for a binary plist format. The
            paths are expanded with bash. Test will fail if file doesn't exist.
        is_not_binary_plist:  Optional, List of paths to files to test for the absense of a binary
            plist format. The paths are expanded with bash. Test will fail if file doesn't exist.
        plist_test_file: Optional, The plist file to test with `plist_test_values`(see next Arg).
        plist_test_values: Optional, The key/value pairs to test. Keys are specified in PlistBuddy
            format(e.g. "UIDeviceFamily:1"). The test will fail if the key does not exist or if
            its value doesn't match the specified value. * can be used as a wildcard value.
            See `plist_test_file`(previous Arg) to specify plist file to test.
        asset_catalog_test_file: Optional, The asset catalog file to test (see next two Args).
        asset_catalog_test_contains: Optional, A list of names of assets that should appear in the
            asset catalog specified in `asset_catalog_file`.
        asset_catalog_test_not_contains: Optional, A list of names of assets that should not appear
            in the asset catalog specified in `asset_catalog_file`.
        **kwargs: Other arguments are passed through to the apple_verification_test rule.
    """

    # Concatonate the keys and values of the test values so they can be passed as env vars.
    plist_test_values_list = []
    for key, value in plist_test_values.items():
        if " " in key:
            fail("Plist key has a space: \"{}\"".format(key))
        plist_test_values_list.append("{} {}".format(key, value))

    apple_verification_test(
        name = name,
        build_type = build_type,
        env = {
            "CONTAINS": contains,
            "NOT_CONTAINS": not_contains,
            "IS_BINARY_PLIST": is_binary_plist,
            "IS_NOT_BINARY_PLIST": is_not_binary_plist,
            "PLIST_TEST_FILE": [plist_test_file],
            "PLIST_TEST_VALUES": plist_test_values_list,
            "ASSET_CATALOG_FILE": [asset_catalog_test_file],
            "ASSET_CATALOG_CONTAINS": asset_catalog_test_contains,
            "ASSET_CATALOG_NOT_CONTAINS": asset_catalog_test_not_contains,
        },
        target_under_test = target_under_test,
        verifier_script = "verifier_scripts/archive_contents_test.sh",
        **kwargs
    )
