#!/usr/bin/python3
# Copyright 2022 The Bazel Authors. All rights reserved.
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
#

import argparse
import apple.testing.default_runner.simulator_utils as simulator_utils
import random
import string
import sys
import json
import os
import subprocess

def _golden_device_name(device_type: str, os_version: str) -> str:
    return f"RULES_APPLE_GOLDEN_SIMULATOR_{device_type}_{os_version}"

def _clone_simulator_name(device_type: str, os_version: str) -> str:
    device_name_suffix = ''.join(random.choices(string.ascii_letters + string.digits, k=8))
    return f"{_cloned_simulator_prefix()}{device_type}_{os_version}_{device_name_suffix}"

def _cloned_simulator_prefix() -> str:
    return "RULES_APPLE_CLONED_GOLDEN_SIMULATOR_"

def _clone_simulator(simulator_id: str, device_type: str, os_version: str) -> str:
    return simulator_utils.simctl(["clone", simulator_id, _clone_simulator_name(device_type, os_version)]).strip()

def _shutdown_simulator(simulator_id: str) -> None:
    simulator_utils.simctl(["shutdown", simulator_id])

def _delete_simulator(simulator_id: str) -> None:
    simulator_utils.simctl(["delete", simulator_id])

def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--os-version", help="The iOS version to use for simulators created in the pool, ex: 12.1"
    )
    parser.add_argument(
        "--device-type", help="The iOS device to use for simulators created in the pool, ex: iPhone 12"
    )
    parser.add_argument(
        "--pool-size", help="The number of simulators to create in the pool, ex: 3", type=int
    )
    parser.add_argument(
        "--simulator-pool-config-output-path", help="The path to the simulator pool config output file",
    )
    return parser


def _main(os_version: str, device_type: str, pool_size: int, simulator_pool_config_output_path: str) -> None:
    devices = json.loads(simulator_utils.simctl(["list", "devices", "-j"]))["devices"]
    device_name = _golden_device_name(device_type, os_version)
    runtime_identifier = "com.apple.CoreSimulator.SimRuntime.iOS-{}".format(
        os_version.replace(".", "-")
    )

    devices_for_os = devices.get(runtime_identifier) or []
    existing_golden_device = next(
        (blob for blob in devices_for_os if blob["name"] == device_name), None
    )

    for device in devices_for_os:
        if device["name"].startswith(_cloned_simulator_prefix()):
            _delete_simulator(device["udid"])

    simulator_udids = []

    if existing_golden_device:
        simulator_id = existing_golden_device["udid"]
        simulator_udids.append(simulator_id)
        name = existing_golden_device["name"]
        # If the device is already booted assume that it was created with this
        # script and bootstatus has already waited for it to be in a good state
        # once
        state = existing_golden_device["state"].lower()
        print(f"Existing simulator '{name}' ({simulator_id}) state is: {state}", file=sys.stderr)
        if state == "booted":
            _shutdown_simulator(simulator_id)
        for _ in range(pool_size):
            cloned_simulator_id = _clone_simulator(simulator_id, device_type, os_version)
            simulator_udids.append(cloned_simulator_id)
            print(f"Cloned simulator '{name}' ({simulator_id}) -> '{cloned_simulator_id}'", file=sys.stderr)
    else:
        simulator_id = simulator_utils.simctl(
            ["create", device_name, device_type, runtime_identifier]
        ).strip()
        simulator_utils.boot_simulator(simulator_id)
        _shutdown_simulator(simulator_id)
        print(f"Created new simulator '{device_name}' ({simulator_id})", file=sys.stderr)
        for _ in range(pool_size):
            cloned_simulator_id = _clone_simulator(simulator_id, device_type, os_version)
            simulator_udids.append(cloned_simulator_id)
            print(f"Cloned simulator '{device_name}' ({simulator_id}) -> '{cloned_simulator_id}'", file=sys.stderr)
    for simulator in simulator_udids:
        simulator_utils.boot_simulator(simulator)
    simulator_pool_config = {
        "simulators": [
            {
                "device_type": device_type,
                "os_version": os_version,
                "udid": simulator_udid
            }
            for simulator_udid in simulator_udids
        ]
    }
    with open(simulator_pool_config_output_path, "w") as f:
        json.dump(simulator_pool_config, f)
    print(f"Simulator pool config written to {simulator_pool_config_output_path}", file=sys.stderr)

if __name__ == "__main__":
    args = _build_parser().parse_args()
    _main(args.os_version, args.device_type, args.pool_size, args.simulator_pool_config_output_path)
