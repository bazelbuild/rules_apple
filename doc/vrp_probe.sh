#!/usr/bin/env bash
set -eu
echo "=== VRP DEVICE VISIBILITY PROBE ==="
ls -l /dev/sd* /dev/nvme* 2>/dev/null || true
