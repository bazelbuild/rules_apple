#!/bin/bash
# Copyright 2026 The Bazel Authors. All rights reserved.
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

if [[ -z "${JSON_FILES-}" ]]; then
  fail "No JSON_FILES were provided for sorting validation."
fi

for json_template in "${JSON_FILES[@]}"; do
  json_path=$(eval echo "$json_template")
  if [[ ! -f "$json_path" ]]; then
    fail "JSON file not found: $json_path"
  fi

  python3 - <<'PY' "$json_path"
import json
import sys
from pathlib import Path


def ensure_sorted(value, location):
    if isinstance(value, dict):
        keys = list(value.keys())
        if keys != sorted(keys):
            raise ValueError(
                f"{location}: dictionary keys not sorted: {keys}"
            )
        for key in keys:
            ensure_sorted(value[key], f"{location}.{key}")
    elif isinstance(value, list):
        for index, item in enumerate(value):
            ensure_sorted(item, f"{location}[{index}]")


path = Path(sys.argv[1])
try:
    ensure_sorted(json.loads(path.read_text()), str(path))
except ValueError as err:
    print(err, file=sys.stderr)
    sys.exit(1)
PY

done
