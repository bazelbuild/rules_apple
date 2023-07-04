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

if [ ! -d "{docc_bundle}" ]; then
  echo "ERROR: Expected a .docc directory bundle for target: {target_name}"
  echo "Previewing requires a .docc bundle to be provided in the target's resources."
  exit 1
fi

cd "$BUILD_WORKSPACE_DIRECTORY"

env -i \
  APPLE_SDK_PLATFORM="{platform}" \
  APPLE_SDK_VERSION_OVERRIDE="{sdk_version}" \
  XCODE_VERSION_OVERRIDE="{xcode_version}" \
  /usr/bin/xcrun docc preview \
  --index \
  --fallback-display-name "{fallback_display_name}" \
  --fallback-bundle-identifier "{fallback_bundle_identifier}" \
  --fallback-bundle-version "{fallback_bundle_version}" \
  --additional-symbol-graph-dir "{symbol_graph_dirs}" \
  --output-dir "$(mktemp -d)" \
  "{docc_bundle}"
