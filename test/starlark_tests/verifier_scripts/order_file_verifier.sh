#!/bin/bash

# Copyright 2023 The Bazel Authors. All rights reserved.
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

set -euo pipefail

# This script allows for verifying functionality surrounding order files and
# How they manipulate the underlying symbols of the compiled binary.
#
# Expectation is for this to be called from an apple_verification_test, eg:
#    apple_verification_test(
#        name = "{}_test".format(name),
#        build_type = "simulator",
#        target_under_test = ":app_with_order_file",
#        verifier_script = "verifier_scripts/order_file_verifier.sh",
#        env = {
#            "FIRST_SYMBOL": ["_main"],
#        },
#        tags = [name],
#    )
#
# Supported operations:
#
#  FIRST_SYMBOL: Will be compared against the first symbol found in the binary.
#    This is a trivial way to test that the order file has been applied to the
#    binary and that the symbols inside have been re-ordered as a result.
#
#  ORDERED_SYMBOLS: Will be compared against all symbols found in the binary.
#    This is a more thorough test that the order file has been applied.
#

something_tested=false

symbols_output="${TEST_TMPDIR}/symbols_output"
nm -n -j "${BINARY}" > "${symbols_output}"

echo "Symbols found:"
cat "$symbols_output"

# Test that the binary contains FIRST_SYMBOL as the first symbol.
if [[ -n "${FIRST_SYMBOL-}" ]]; then
  something_tested=true

  symbol_output_first=$(head -n 1 "$symbols_output")
  assert_equals "$FIRST_SYMBOL" "$symbol_output_first"
fi

# Test that the binary contains ORDERED_SYMBOLS in order.
if [[ -n "${ORDERED_SYMBOLS-}" ]]; then
  something_tested=true

  ordered_symbols_length=${#ORDERED_SYMBOLS[@]}
  IFS=$'\n' symbols_output_idx=($(head -n $ordered_symbols_length "$symbols_output"))

  for ((idx=0; idx<ordered_symbols_length; ++idx)); do
    assert_equals "${ORDERED_SYMBOLS[idx]}" "${symbols_output_idx[idx]}"
  done
fi

# Lastly clean up the symbols file.
rm -f "${symbols_output}"

if [[ "$something_tested" = false ]]; then
  fail "Rule Misconfigured: Nothing was configured to be validated."
fi