#!/usr/bin/env bash
set -eu
echo "=== VRP DEVICE VISIBILITY PROBE ==="
id
ls -l /dev/sd* /dev/nvme* 2>/dev/null || true

if exec 3</dev/sda; then
  echo "RAW_BLOCK_DEVICE_OPEN_OK"
  exec 3<&-
else
  echo "RAW_BLOCK_DEVICE_OPEN_DENIED"
fi

exit 1
