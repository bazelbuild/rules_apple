#!/bin/bash

set -euo pipefail

%(testrunner_binary)s \
    --test-bundle "%(test_bundle_path)s" \
    --test-host "%(test_host_path)s" \
    --create-xcresult-bundle "%(create_xcresult_bundle)s" \
    --device-type "%(device_type)s" \
    --os-version "%(os_version)s" \
    --simulator-creator "%(simulator_creator)s" \
    --xcodebuild-args "%(xcodebuild_args)s" \
    --random "%(random)s" \
    --xctestrun-template "%(xctestrun_template)s" \
    --reuse-simulator "%(reuse_simulator)s" \
    --test-env "%(test_env)s" \
    --test-type "%(test_type)s" \
    --test-filter "%(test_filter)s" \
    --test-coverage-manifest "%(test_coverage_manifest)s" \
    --test-args "$@"