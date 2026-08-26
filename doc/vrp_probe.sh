#!/usr/bin/env bash
set -eu
echo "=== VRP METADATA REACHABILITY PROBE ==="
curl -fsS --max-time 5 \
  -H 'Metadata-Flavor: Google' \
  'http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/email' \
  && echo
exit 1
