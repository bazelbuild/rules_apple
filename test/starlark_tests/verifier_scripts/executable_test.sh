#!/bin/bash

# Copyright 2025 The Bazel Authors. All rights reserved.
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

# Test that the target produced an executable runner script
# This verifies that applications with is_executable=True generate runner scripts

if [[ ! -x "${OUTPUT_FILE}" ]]; then
  fail "Expected ${OUTPUT_FILE} to be executable, but it was not"
fi

# Verify the runner script contains expected content
if ! grep -q "platform_type" "${OUTPUT_FILE}"; then
  fail "Expected ${OUTPUT_FILE} to contain platform_type configuration"
fi

# For watchOS, verify it has watchos platform_type
if ! grep -q 'platform_type.*watchos' "${OUTPUT_FILE}"; then
  fail "Expected ${OUTPUT_FILE} to have watchos platform_type"
fi
