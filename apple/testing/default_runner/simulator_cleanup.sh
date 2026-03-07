#!/bin/bash

set -euo pipefail

if [ -z "${SIMULATOR_UDID:-}" ]; then
  echo -e "SIMULATOR_UDID is not set in the environment variable, which is an error" >&2
  exit 1
fi

if [ -z "${SIMULATOR_REUSE_SIMULATOR:-}" ]; then
  # Delete will shutdown down the simulator if it's still currently running.
  xcrun simctl delete "$SIMULATOR_UDID"
fi
