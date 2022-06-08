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
        text_test_file = "",
        text_test_values = [],
        binary_test_file = "",
        binary_test_architecture = "",
        binary_contains_symbols = [],
        binary_not_contains_symbols = [],
        codesign_info_contains = [],
        codesign_info_not_contains = [],
        macho_load_commands_contain = [],
        macho_load_commands_not_contain = [],
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
        text_test_file: Optional, The text file to test (see the next Arg).
        text_test_values: Optional, A list of regular expressions that should be tested against
            the contents of `text_test_file`.
        binary_test_file: Optional, The binary file to test (see next three Args).
        binary_test_architecture: Optional, The architecture to use from `binary_test_file` for
            symbol tests (see next two Args).
        binary_contains_symbols: Optional, A list of symbols that should appear in the binary file
            specified in `binary_test_file`.
        binary_not_contains_symbols: Optional, A list of symbols that should not appear in the
            binary file specified in `binary_test_file`.
        codesign_info_contains: Optional, A list of codesign info that should appear in the binary
            file specified in `binary_test_file`.
        codesign_info_not_contains: Optional, A list of codesign info that should not appear in the
            binary file specified in `binary_test_file`.
        macho_load_commands_contain: Optional, A list of Mach-O load commands that should appear in
            the binary file specified in `binary_test_file`.
        macho_load_commands_not_contain: Optional, A list of Mach-O load commands that should not
            appear in the binary file specified in `binary_test_file`.
        **kwargs: Other arguments are passed through to the apple_verification_test rule.
    """
    if any([plist_test_file, plist_test_values]) and not all([plist_test_file, plist_test_values]):
        fail("Need both plist_test_file and plist_test_values")

    got_asset_catalog_tests = any([asset_catalog_test_contains, asset_catalog_test_not_contains])
    if any([asset_catalog_test_file, got_asset_catalog_tests]) and not all([
        asset_catalog_test_file,
        got_asset_catalog_tests,
    ]):
        fail("Need asset_catalog_test_file along with " +
             "asset_catalog_test_contains and/or asset_catalog_test_not_contains")

    if any([text_test_file, text_test_values]) and not all([text_test_file, text_test_values]):
        fail("Need both text_test_file and text_test_values")

    if binary_test_file:
        if any([binary_contains_symbols, binary_not_contains_symbols]) and (
            not binary_test_architecture
        ):
            fail("Need binary_test_architecture when checking symbols")
        elif binary_test_architecture and not any([
            binary_contains_symbols,
            binary_not_contains_symbols,
            macho_load_commands_contain,
            macho_load_commands_not_contain,
        ]):
            fail("Need at least one of (binary_contains_symbols, binary_not_contains_symbols, " +
                 "macho_load_commands_contain, macho_load_commands_not_contain) when specifying " +
                 "binary_test_architecture")
    else:
        if any([binary_contains_symbols, binary_not_contains_symbols, binary_test_architecture]):
            fail("Need binary_test_file to check the binary for symbols")
        if any([macho_load_commands_contain, macho_load_commands_not_contain]):
            fail("Need binary_test_file to check macho load commands")
        if any([codesign_info_contains, codesign_info_not_contains]):
            fail("Need binary_test_file to check codesign info")

    if not any([
        contains,
        not_contains,
        is_binary_plist,
        is_not_binary_plist,
        plist_test_file,
        asset_catalog_test_file,
        text_test_file,
        binary_test_file,
    ]):
        fail("There are no tests for the archive")

    # Concatenate the keys and values of the test values so they can be passed as env vars.
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
            "TEXT_TEST_FILE": [text_test_file],
            "TEXT_TEST_VALUES": text_test_values,
            "BINARY_TEST_FILE": [binary_test_file],
            "BINARY_TEST_ARCHITECTURE": [binary_test_architecture],
            "BINARY_CONTAINS_SYMBOLS": binary_contains_symbols,
            "BINARY_NOT_CONTAINS_SYMBOLS": binary_not_contains_symbols,
            "CODESIGN_INFO_CONTAINS": codesign_info_contains,
            "CODESIGN_INFO_NOT_CONTAINS": codesign_info_not_contains,
            "MACHO_LOAD_COMMANDS_CONTAIN": macho_load_commands_contain,
            "MACHO_LOAD_COMMANDS_NOT_CONTAIN": macho_load_commands_not_contain,
        },
        target_under_test = target_under_test,
        verifier_script = "@build_bazel_rules_apple//test/starlark_tests:verifier_scripts/archive_contents_test.sh",
        **kwargs
    )

# TODO(nglevin): Extend for usages required of macos_command_line_application tests.
def binary_contents_test(
        name,
        build_type,
        target_under_test,
        binary_test_file,
        binary_test_architecture = "",
        binary_contains_symbols = [],
        binary_not_contains_symbols = [],
        embedded_plist_test_values = {},
        plist_section_name = "__info_plist",
        **kwargs):
    """Macro for calling the apple_verification_test with binary_contents_test.sh.

    Args:
        name: Name of generated test target.
        build_type: Type of build for the target. Possible values are `simulator` and `device`.
        target_under_test: The Apple binary target whose contents are to be verified.
        binary_test_file: The binary file to test.
        binary_test_architecture: Optional, The architecture to use from `binary_test_file` for
            symbol tests (see next two Args).
        binary_contains_symbols: Optional, A list of symbols that should appear in the binary file
            specified in `binary_test_file`.
        binary_not_contains_symbols: Optional, A list of symbols that should not appear in the
            binary file specified in `binary_test_file`.
        embedded_plist_test_values: Optional, The key/value pairs to test. The test will fail
            if the key does not exist or if its value doesn't match the specified value. * can
            be used as a wildcard value. An embedded plist will be extracted from the
            `binary_test_file` based on the `plist_slice` for this test.
        plist_section_name: Optional, The name of the plist section to test. Will be the
            identifier for the section in the `__TEXT` segment, for instance `__launchd_plist`.
            Defaults to `__info_plist`.
        **kwargs: Other arguments are passed through to the apple_verification_test rule.
    """
    if any([binary_contains_symbols, binary_not_contains_symbols]) and not binary_test_architecture:
        fail("Need binary_test_architecture when checking symbols")
    elif binary_test_architecture and not any([binary_contains_symbols, binary_not_contains_symbols]):
        fail("Need binary_contains_symbols and/or binary_not_contains_symbols when checking an " +
             "architecture")

    if not any([binary_test_file, embedded_plist_test_values]):
        fail("There are no tests for the binary")

    # Concatenate the keys and values of the test values so they can be passed as env vars.
    plist_test_values_list = []
    for key, value in embedded_plist_test_values.items():
        if " " in key:
            fail("Plist key has a space: \"{}\"".format(key))
        plist_test_values_list.append("{} {}".format(key, value))

    apple_verification_test(
        name = name,
        build_type = build_type,
        env = {
            "BINARY_TEST_FILE": [binary_test_file],
            "BINARY_TEST_ARCHITECTURE": [binary_test_architecture],
            "BINARY_CONTAINS_SYMBOLS": binary_contains_symbols,
            "BINARY_NOT_CONTAINS_SYMBOLS": binary_not_contains_symbols,
            "PLIST_SECTION_NAME": [plist_section_name],
            "PLIST_TEST_VALUES": plist_test_values_list,
        },
        target_under_test = target_under_test,
        verifier_script = "@build_bazel_rules_apple//test/starlark_tests:verifier_scripts/binary_contents_test.sh",
        **kwargs
    )

def bitcode_symbol_map_test(
        *,
        name,
        bc_symbol_maps_root = "",
        binary_paths,
        tags,
        target_under_test,
        **kwargs):
    """Macro to call `apple_verification_test` with `bitcode_verifier.sh`.

    This simplifies Bitcode verification tests by forcing
    `apple_bitcode = "embedded"`, `build_type = "device"`, and also currently
    disables the test in OSS until Bitcode is properly supported in Bazel's
    crosstool.

    Args:
        name: Name of the generated test target.
        bc_symbol_maps_root: A relative path to the root of the BCSymbolsMaps subdirectory, if it is
            not at the root of the expanded archive. Assumed to be the root of the expanded archive
            if this is not provided.
        binary_paths: The list of archive-relative paths of binaries whose
            DWARF info should have UDIDs extracted and checked against
            Bitcode symbol maps in the archive root.
        tags: Tags to be applied to the test target.
        target_under_test: The archive target whose contents are to be verified.
        **kwargs: Other arguments passed directly to `apple_verification_test`.
    """
    apple_verification_test(
        name = name,
        apple_bitcode = "embedded",
        build_type = "device",
        env = {
            "BITCODE_BINARIES": binary_paths,
            "BC_SYMBOL_MAPS_ROOT": [bc_symbol_maps_root],
            "PLATFORM": ["unused"],
        },
        target_under_test = target_under_test,
        verifier_script = "@build_bazel_rules_apple//test/starlark_tests:verifier_scripts/bitcode_verifier.sh",
        tags = tags,
        **kwargs
    )

def apple_symbols_file_test(
        name,
        binary_paths,
        build_type,
        tags,
        target_under_test,
        **kwargs):
    """Macro to call `apple_verification_test` with `apple-symbols_file_verifier.sh`.

    This simplifies .symbols file verification tests by forcing
    `apple_generate_dsym=true`.

    Args:
        name: Name of the generated test target.
        binary_paths: The list of archive-relative paths of binaries whose
            DWARF info should have UUIDs extracted and checked against
            `$UUID.symbols` files in the archive's Symbols/ directory.
        build_type: Type of build for the target. Possible values are
            `simulator` and `device`.
        tags: Tags to be applied to the test target.
        target_under_test: The archive target whose contents are to be verified.
        **kwargs: Other arguments passed directly to `apple_verification_test`.

    """
    apple_verification_test(
        name = name,
        build_type = build_type,
        env = {
            "BINARY_PATHS": binary_paths,
        },
        target_under_test = target_under_test,
        apple_generate_dsym = True,
        verifier_script = "@build_bazel_rules_apple//test/starlark_tests:verifier_scripts/apple_symbols_file_verifier.sh",
        tags = tags,
        **kwargs
    )

def entry_point_test(
        name,
        build_type,
        entry_point,
        tags,
        target_under_test,
        **kwargs):
    """Macro to call `apple_verification_test` with `entry_point_verifier.sh`.

    Args:
        name: Name of the generated test target.
        build_type: Type of build for the target. Possible values are
            `simulator` and `device`.
        entry_point: The name of the symbol that is expected to be the entry
            point of the binary.
        tags: Tags to be applied to the test target.
        target_under_test: The archive target whose contents are to be verified.
        **kwargs: Other arguments passed directly to `apple_verification_test`.
    """
    apple_verification_test(
        name = name,
        build_type = build_type,
        env = {
            "ENTRY_POINT": [entry_point],
        },
        target_under_test = target_under_test,
        verifier_script = "@build_bazel_rules_apple//test/starlark_tests:verifier_scripts/entry_point_verifier.sh",
        tags = tags,
        **kwargs
    )
