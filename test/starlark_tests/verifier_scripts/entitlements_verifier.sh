#!/bin/bash

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

set -euo pipefail

TEMP_OUTPUT="$(mktemp "${TMPDIR:-/tmp}/codesign_output.XXXXXX")"
TEMP_DER_OUTPUT="$(mktemp "${TMPDIR:-/tmp}/codesign_der_output.XXXXXX")"

# If ENTITLEMENT_KEYS, ENTITLEMENTS_KEY, ABSENT_ENTITLEMENT_KEYS, or
# ENTITLEMENT_VALUES was provided via the test's `env` attribute, check those
# keys/values. Otherwise fall back to the default entitlement key from
# third_party/bazel_rules/rules_apple/test/starlark_tests/resources/entitlements.plist.
if [[ -z "${ENTITLEMENT_KEYS[@]:-}" && -z "${ENTITLEMENTS_KEY[@]:-}" && -z "${ABSENT_ENTITLEMENT_KEYS[@]:-}" && -z "${ENTITLEMENT_VALUES[@]:-}" ]]; then
  ENTITLEMENT_KEYS=("${TEST_ENTITLEMENT_KEY:-test-an-entitlement}")
else
  ENTITLEMENT_KEYS=("${ENTITLEMENT_KEYS[@]:-${ENTITLEMENTS_KEY[@]:-}}")
fi
ABSENT_ENTITLEMENT_KEYS=("${ABSENT_ENTITLEMENT_KEYS[@]:-}")
ENTITLEMENT_VALUES=("${ENTITLEMENT_VALUES[@]:-}")

if [[ "$BUILD_TYPE" == "simulator" ]]; then
  # Extract the legacy xml plist section.
  xcrun llvm-objdump --macho --section=__TEXT,__entitlements "$BINARY" | \
      sed -e 's/^[0-9a-f][0-9a-f]*[[:space:]][[:space:]]*//' \
      -e 'tx' -e 'd' -e ':x' | xxd -r -p > "$TEMP_OUTPUT"

  # Extract the new DER encoded section.
  xcrun llvm-objdump --macho --section=__TEXT,__ents_der "$BINARY" | \
      sed -e 's/^[0-9a-f][0-9a-f]*[[:space:]][[:space:]]*//' \
      -e 'tx' -e 'd' -e ':x' | xxd -r -p > "$TEMP_DER_OUTPUT"

elif [[ "$BUILD_TYPE" == "device" ]]; then
  # Extract the legacy xml plist section.
  codesign --display --xml --entitlements "$TEMP_OUTPUT" "$BUNDLE_ROOT"

  # Extract the new DER encoded section.
  codesign --display --der --entitlements "$TEMP_DER_OUTPUT" "$BUNDLE_ROOT"
else
  fail "Unsupported BUILD_TYPE = $BUILD_TYPE for this test"
fi

for key in "${ENTITLEMENT_KEYS[@]}"; do
  if [[ -n "$key" ]]; then
    assert_contains "<key>$key</key>" "$TEMP_OUTPUT"
    assert_contains "$key" "$TEMP_DER_OUTPUT"
  fi
done

for key in "${ABSENT_ENTITLEMENT_KEYS[@]}"; do
  if [[ -n "$key" ]]; then
    assert_not_contains "<key>$key</key>" "$TEMP_OUTPUT"
    assert_not_contains "$key" "$TEMP_DER_OUTPUT"
  fi
done

for kv in "${ENTITLEMENT_VALUES[@]}"; do
  if [[ -n "$kv" ]]; then
    key="${kv%%=*}"
    expected_value="${kv#*=}"
    assert_contains "<key>$key</key>" "$TEMP_OUTPUT"
    assert_contains "$key" "$TEMP_DER_OUTPUT"
    actual_value="$(/usr/libexec/PlistBuddy -c "Print :$key" "$TEMP_OUTPUT" 2>/dev/null || true)"
    assert_equals "$expected_value" "$actual_value"
  fi
done

rm -rf "$TEMP_OUTPUT"
rm -rf "$TEMP_DER_OUTPUT"
