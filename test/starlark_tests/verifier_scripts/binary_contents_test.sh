#!/bin/bash

# Copyright 2020 The Bazel Authors. All rights reserved.
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

set -eu

newline=$'\n'

# This script allows many of the functions in apple_shell_testutils.sh to be
# called through apple_verification_test_runner.sh.template by using environment
# variables.
#
# Supported operations:
#  BINARY_TEST_FILE: The file to test with `PLIST_TEST_VALUES`
#  BINARY_TEST_ARCHITECTURE: The architecture to use with
#      `BINARY_CONTAINS_SYMBOLS`.
#  BINARY_CONTAINS_SYMBOLS: Array of symbols that should be present.
#  BINARY_NOT_CONTAINS_SYMBOLS: Array of symbols that should not be present.
#  PLIST_SECTION_NAME: Name of the plist section to inspect values from. If not
#      supplied, will test the embedded Info.plist slice at __TEXT,__info_plist.
#  PLIST_TEST_VALUES: Array for keys and values in the format "KEY VALUE" where
#      the key is a string without spaces, followed by by a single space,
#      followed by the value to test. * can be used as a wildcard value.

# Test that the binary contains and does not contain the specified plist symbols.
if [[ -n "${BINARY_TEST_FILE-}" ]]; then
  path=$(eval echo "$BINARY_TEST_FILE")
  if [[ ! -e "$path" ]]; then
    fail "Could not find binary at \"$path\""
  fi
  something_tested=false

  if [[ -n "${BINARY_TEST_ARCHITECTURE-}" ]]; then
    arch=$(eval echo "$BINARY_TEST_ARCHITECTURE")
    if [[ ! -n $arch ]]; then
      fail "No architecture specified for binary file at \"$path\""
    fi

    # Filter out undefined symbols from the objdump mach-o symbol output and
    # return the rightmost value; these binary symbols will not have spaces.
    IFS=$'\n' actual_symbols=($(objdump -t -macho -arch="$arch" "$path" | grep -v "*UND*" | awk '{print substr($0,index($0,$5))}'))
    if [[ -n "${BINARY_CONTAINS_SYMBOLS-}" ]]; then
      for test_symbol in "${BINARY_CONTAINS_SYMBOLS[@]}"
      do
        something_tested=true
        symbol_found=false
        for actual_symbol in "${actual_symbols[@]}"
        do
          if [[ "$actual_symbol" == "$test_symbol" ]]; then
            symbol_found=true
            break
          fi
        done
        if [[ "$symbol_found" = false ]]; then
            fail "Expected symbol \"$test_symbol\" was not found. The " \
              "symbols in the binary were:$newline${actual_symbols[@]}"
        fi
      done
    fi

    if [[ -n "${BINARY_NOT_CONTAINS_SYMBOLS-}" ]]; then
      for test_symbol in "${BINARY_NOT_CONTAINS_SYMBOLS[@]}"
      do
        something_tested=true
        symbol_found=false
        for actual_symbol in "${actual_symbols[@]}"
        do
          if [[ "$actual_symbol" == "$test_symbol" ]]; then
            symbol_found=true
            break
          fi
        done
        if [[ "$symbol_found" = true ]]; then
            fail "Unexpected symbol \"$test_symbol\" was found. The symbols " \
              "in the binary were:$newline${actual_symbols[@]}"
        fi
      done
    fi
  else
    if [[ -n "${BINARY_CONTAINS_SYMBOLS-}" ]]; then
      fail "Rule Misconfigured: Supposed to look for symbols," \
        "but no arch was set to check: ${BINARY_CONTAINS_SYMBOLS[@]}"
    fi
    if [[ -n "${BINARY_NOT_CONTAINS_SYMBOLS-}" ]]; then
      fail "Rule Misconfigured: Supposed to look for missing symbols," \
        "but no arch was set to check: ${BINARY_NOT_CONTAINS_SYMBOLS[@]}"
    fi
  fi

  # Use `launchctl plist` to test for key/value pairs in an embedded plist file.
  if [[ -n "${PLIST_TEST_VALUES-}" ]]; then
    for test_values in "${PLIST_TEST_VALUES[@]}"
    do
      something_tested=true
      # Keys and expected-values are in the format "KEY VALUE".
      IFS=' ' read -r key expected_value <<< "$test_values"
      if [[ -z "${PLIST_SECTION_NAME-}" ]]; then
        fail "Rule Misconfigured: missing plist section," \
         "but not supposed to check for values: ${PLIST_TEST_VALUES}"
      fi
      plist_section_name="__TEXT,$PLIST_SECTION_NAME"
      # Replace wildcard "*" characters with a sed-friendly ".*" wildcard.
      expected_value=${expected_value/"*"/".*"}
      value="$(launchctl plist $plist_section_name $path | sed -nE "s/.*\"$key\" = \"($expected_value)\";.*/\1/p" || true)"
      if [[ ! -n "$value" ]]; then
        fail "Expected plist key \"$key\" to be \"$expected_value\" in plist " \
            "embedded in \"$path\" at \"$plist_section_name\". Plist " \
            "contents:$newline$(launchctl plist $plist_section_name $path)"
      fi
    done
  else
    # Don't error if PLIST_SECTION_NAME is set because the rule defaults it.
    true
  fi

  if [[ "$something_tested" = false ]]; then
    fail "Rule Misconfigured: Nothing was configured to be validated on the binary \"$path\""
  fi
else
  fail "Rule Misconfigured: No binary was set to be inspected"
fi
