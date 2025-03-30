#!/usr/bin/env python3

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

import argparse
import json
import random
import string
import subprocess
import sys
import time
from typing import Any, Optional


class SimulatorCreatorError(Exception):
    pass


def _simctl(*args: str, **kwargs: Any) -> str:
    kwargs["text"] = True
    return subprocess.check_output(("xcrun", "simctl", *args), **kwargs)


def _form_device_name(
    name: Optional[str], device_type: str, runtime_version: str
) -> str:
    return name or f"BAZEL_TEST_{device_type}_{runtime_version}"


def _create_simulator(
    device_name: str, device_type: str, runtime_identifier: str
) -> str:
    simulator_id = _simctl(
        "create", device_name, device_type, runtime_identifier
    ).strip()
    print(f"Created new simulator '{device_name}' ({simulator_id})", file=sys.stderr)
    return simulator_id


def _boot_simulator(simulator_id: str) -> None:
    # This private command boots the simulator if it isn't already, and waits
    # for the appropriate amount of time until we can actually run tests
    try:
        output = _simctl("bootstatus", simulator_id, "-b")
        print(output, file=sys.stderr)
    except subprocess.CalledProcessError as e:
        exit_code = e.returncode

        # When reusing simulators we may encounter the error:
        # 'Unable to boot device in current state: Booted'.
        #
        # This is because the simulator is already booted, and we can ignore it
        # if we check and the simulator is in fact booted.
        if exit_code == 149:
            devices = json.loads(
                _simctl("list", "devices", "-j", simulator_id),
            )["devices"]
            device = next(
                (
                    blob
                    for devices_for_os in devices.values()
                    for blob in devices_for_os
                    if blob["udid"] == simulator_id
                ),
                None,
            )
            if device and device["state"].lower() == "booted":
                print(
                    f"Simulator '{device['name']}' ({simulator_id}) is already booted",
                    file=sys.stderr,
                )
                exit_code = 0

        # Both of these errors translate to strange simulator states that may
        # end up causing issues, but attempting to actually use the simulator
        # instead of failing at this point might still succeed
        #
        # 164: EBADDEVICE
        # 165: EBADDEVICESTATE
        if exit_code in (164, 165):
            print(
                f"Ignoring 'simctl bootstatus' exit code {exit_code}",
                file=sys.stderr,
            )
        elif exit_code != 0:
            print(f"'simctl bootstatus' exit code {exit_code}", file=sys.stderr)
            raise

    # Add more arbitrary delay before tests run. Even bootstatus doesn't wait
    # long enough and tests can still fail because the simulator isn't ready
    time.sleep(3)


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--device-type",
        required=True,
        help="The iOS device to run the tests on, ex: iPhone X",
    )
    parser.add_argument(
        "--os-version",
        required=True,
        help="The iOS simulator runtime version to run the tests on, ex: 12.1",
    )
    parser.add_argument(
        "--name",
        help="The name to use for the device; default is 'BAZEL_TEST_[device_type]_[os_version]'",
    )
    parser.add_argument(
        "--reuse-simulator",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Toggle simulator reuse; default is True",
    )
    return parser


def _main(
    *,
    device_type: str,
    os_version: str,
    name: Optional[str],
    reuse_simulator: bool,
) -> None:
    simctl_state = json.loads(_simctl("list", "-j"))
    devices = simctl_state["devices"]
    runtimes = simctl_state["runtimes"]
    runtime = next(
        (runtime for runtime in runtimes if runtime["version"].startswith(os_version)),
        None,
    )

    if not runtime:
        raise SimulatorCreatorError(f"no runtime matching {os_version} could be found")
    if not runtime["isAvailable"]:
        raise SimulatorCreatorError(
            f"matching runtime {runtime['buildversion']} is unavailable"
        )

    runtime_identifier = runtime["identifier"]
    runtime_version = runtime["version"]
    device_name = _form_device_name(name, device_type, runtime_version)

    if reuse_simulator:
        existing_device = next(
            (
                device
                for device in devices.get(runtime_identifier, [])
                if device["name"] == device_name
            ),
            None,
        )
        if existing_device:
            simulator_id: str = existing_device["udid"]
            name = existing_device["name"]
            # If the device is already booted assume that it was created with this
            # script and bootstatus has already waited for it to be in a good state
            # once
            state = existing_device["state"].lower()
            print(
                f"Existing simulator '{name}' ({simulator_id}) state is: {state}",
                file=sys.stderr,
            )
            if state != "booted":
                _boot_simulator(simulator_id)
        else:
            simulator_id = _create_simulator(
                device_name, device_type, runtime_identifier
            )
            _boot_simulator(simulator_id)
    else:
        device_name_suffix = "".join(
            random.choices(string.ascii_letters + string.digits, k=8)
        )
        simulator_id = _create_simulator(
            f"{device_name}_{device_name_suffix}", device_type, runtime_identifier
        )
        _boot_simulator(simulator_id)

    print(simulator_id.strip())


if __name__ == "__main__":
    args = _build_parser().parse_args()
    _main(
        device_type=args.device_type,
        os_version=args.os_version,
        name=args.name,
        reuse_simulator=args.reuse_simulator,
    )
