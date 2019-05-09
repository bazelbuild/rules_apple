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

set -eu

# Loads the unittest framework for common assert methods.
source test/unittest.bash
source test/apple_shell_testutils.sh

# Unzip the archive into a temporary location.
ARCHIVE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/bundle_tmp_dir.XXXXXX")"
trap 'rm -rf "${ARCHIVE_ROOT}"' ERR EXIT
unzip -qq "%{archive}s" -d "$ARCHIVE_ROOT"

# Define common bundle locations to be used by the verifier scripts.
BINARY_ROOT="$ARCHIVE_ROOT/%{archive_relative_binary}s"
BUNDLE_ROOT="$ARCHIVE_ROOT/%{archive_relative_bundle}s"
CONTENT_ROOT="$ARCHIVE_ROOT/%{archive_relative_contents}s"
RESOURCE_ROOT="$ARCHIVE_ROOT/%{archive_relative_resources}s"

# Invoke the verifier script.
source %{verifier_script}s
