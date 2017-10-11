#!/bin/bash

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

set -eu

# Runs the integration tests, ensuring that sandboxing is disabled.
#
# Individual actions in the bundling rules disable sandboxing when required
# (for example, for actool and ibtool), but because the integration tests
# create a temporary workspace and spawn a second Bazel in it, the sandbox
# from that outer instance still ends up restricting the inner instances
# unless its sandbox is disabled as well.
#
# Usage: run_integration_tests.sh [tests to run...]
#
# The "tests to run..." argument can be a list of test targets that will be
# passed directly to "bazel test". If omitted, the script will simply run all
# tests under "//test/...".

if [[ "$#" -eq 0 ]]; then
  readonly tests="//test/..."
else
  readonly tests="$@"
fi

bazel test "$tests" --experimental_objc_crosstool=all --test_strategy=standalone --strategy=TestRunner=standalone
