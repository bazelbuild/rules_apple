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

import json
import sys
import time
import subprocess
from typing import List


def simctl(extra_args: List[str]) -> str:
    """Execute simctl command with the given arguments.

    Args:
        extra_args: List of additional arguments to pass to simctl

    Returns:
        The decoded output from the simctl command

    Raises:
        subprocess.CalledProcessError: If the simctl command fails
    """
    return subprocess.check_output(["xcrun", "simctl"] + extra_args).decode()

def boot_simulator(simulator_id: str) -> None:
    # This private command boots the simulator if it isn't already, and waits
    # for the appropriate amount of time until we can actually run tests
    try:
        output = simctl(["bootstatus", simulator_id, "-b"])
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
                simctl(["list", "devices", "-j", simulator_id]),
            )["devices"]
            device = next(
                (
                    blob
                    for devices_for_os in devices.values()
                    for blob in devices_for_os
                    if blob["udid"] == simulator_id
                ),
                None
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
