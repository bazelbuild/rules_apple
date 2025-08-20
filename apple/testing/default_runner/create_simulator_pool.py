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
import apple.testing.default_runner.simulator_utils
import random
import string
import sys
import json

def _golden_device_name(device_type: str, os_version: str) -> str:
    return f"RULES_APPLE_GOLDEN_SIMULATOR_{device_type}_{os_version}"

def _clone_simulator_name(device_type: str, os_version: str) -> str:
    device_name_suffix = ''.join(random.choices(string.ascii_letters + string.digits, k=8))
    return f"RULES_APPLE_CLONED_GOLDEN_SIMULATOR_{device_type}_{os_version}_{device_name_suffix}"

def _clone_simulator(simulator_id: str, device_type: str, os_version: str) -> str:
    return simctl(["clone", simulator_id, _clone_simulator_name(device_type, os_version)]).strip()

def _shutdown_simulator(simulator_id: str) -> None:
    simctl(["shutdown", simulator_id])

def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "os_version", help="The iOS version to use for simulators created in the pool, ex: 12.1"
    )
    parser.add_argument(
        "device_type", help="The iOS device to use for simulators created in the pool, ex: iPhone X"
    )
    parser.add_argument(
        "pool_size", help="The number of simulators to create in the pool, ex: 3", type=int
    )
    return parser


def _main(os_version: str, device_type: str, pool_size: int) -> None:
    devices = json.loads(simctl(["list", "devices", "-j"]))["devices"]
    device_name = _golden_device_name(device_type, os_version)
    runtime_identifier = "com.apple.CoreSimulator.SimRuntime.iOS-{}".format(
        os_version.replace(".", "-")
    )

    devices_for_os = devices.get(runtime_identifier) or []
    existing_device = next(
        (blob for blob in devices_for_os if blob["name"] == device_name), None
    )

    if existing_device:
        simulator_id = existing_device["udid"]
        name = existing_device["name"]
        # If the device is already booted assume that it was created with this
        # script and bootstatus has already waited for it to be in a good state
        # once
        state = existing_device["state"].lower()
        print(f"Existing simulator '{name}' ({simulator_id}) state is: {state}", file=sys.stderr)
        if state == "booted":
            _shutdown_simulator(simulator_id)
        for _ in range(pool_size - 1):
            _clone_simulator(simulator_id, device_type, os_version)
            print(f"Cloned simulator '{name}' ({simulator_id})", file=sys.stderr)
        boot_simulator(simulator_id)
    else:
        simulator_id = simctl(
            ["create", device_name, device_type, runtime_identifier]
        ).strip()
        print(f"Created new simulator '{device_name}' ({simulator_id})", file=sys.stderr)
        for _ in range(pool_size - 1):
            _clone_simulator(simulator_id, device_type, os_version)
            print(f"Cloned simulator '{device_name}' ({simulator_id})", file=sys.stderr)
        boot_simulator(simulator_id)


if __name__ == "__main__":
    args = _build_parser().parse_args()
    _main(args.os_version, args.device_type, args.pool_size)
