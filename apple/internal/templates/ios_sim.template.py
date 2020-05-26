#!/usr/bin/env python3

# Copyright 2020 The Bazel Authors. All rights reserved.
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

"""Invoked by `bazel run` to launch ios_application targets in the simulator."""

# This script is to:
# 1. create a new simulator by running "xcrun simctl create ..."
# 2. launch the created simulator by passing the ID to the simulator app,
# 3. install the target app on the created simulator by running
# "xcrun simctl install ..."
# 4. launch the target app on the created simulator by running
# "xcrun simctl launch <device> <app identifier> <args>", and get its PID. We
# pass in the env vars to the app by exporting the env vars adding the prefix
# "SIMCTL_CHILD_" in the calling environment.
# 5. check the app's PID periodically, exit the script when the app is not
# running.
# 6. when exit, will shutdown and delete the new created simulator.

import contextlib
import logging
import os.path
import platform
import plistlib
import subprocess
import tempfile
import time
import zipfile

logging.basicConfig(
    format="%(asctime)s.%(msecs)03d %(levelname)s %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    level=logging.INFO)
logger = logging.getLogger(__name__)

if platform.system() != "Darwin":
  raise Exception("Cannot run iOS targets on a non-mac machine.")


def wait_for_sim_to_boot(udid):
  """Blocks until the given simulator is booted.

  Args:
    udid: The identifier of the simulator to wait for.

  Returns:
    True if the simulator boots within 60 seconds, False otherwise.
  """
  logger.info("Waiting for simulator to boot...")
  for _ in range(0, 60):
    # The expected output of "xcrun simctl list" is like:
    # -- iOS 8.4 --
    # iPhone 5s (E946FA1C-26AB-465C-A7AC-24750D520BEA) (Shutdown)
    # TestDevice (8491C4BC-B18E-4E2D-934A-54FA76365E48) (Booted)
    # So if there's any booted simulator, $booted_device will not be empty.
    simctl_list_result = subprocess.run(["xcrun", "simctl", "list", "devices"],
                                        encoding="utf-8",
                                        check=True,
                                        stdout=subprocess.PIPE)
    for line in simctl_list_result.stdout.split("\n"):
      if line.find(udid) != -1 and line.find("Booted") != -1:
        logger.debug("Simulator is booted.")
        # Simulator is booted.
        return True
    logger.debug("Simulator not booted, still waiting...")
    time.sleep(1)
  return False


@contextlib.contextmanager
def booted_simulator(developer_path, udid):
  """Launches the iOS simulator for the given identifier.

  Args:
    developer_path: The path to /Applications/Xcode.app/Contents/Developer.
    udid: The identifier of the simulator to wait for.

  Yields:
    A running subprocess.Popen object for the simulator.

  Raises:
    Exception: if the simulator did not launch within 60 seconds.
  """
  logger.info("Launching simulator with udid: %s", udid)
  simulator_path = os.path.join(
      developer_path, "Applications/Simulator.app/Contents/MacOS/Simulator")
  with subprocess.Popen([simulator_path, "-CurrentDeviceUDID", udid],
                        stdout=subprocess.DEVNULL) as simulator_process:
    logger.debug("Simulator launched.")
    if not wait_for_sim_to_boot(udid):
      raise Exception("Failed to launch simulator with UDID: " + udid)
    yield simulator_process


@contextlib.contextmanager
def temporary_ios_simulator(device, version):
  """Creates a temporary iOS simulator, cleaned up automatically upon close.

  Args:
    device: The name of the device (e.g. "iPhone 8 Plus").
    version: The version of the iOS runtime (e.g. "13.2").

  Yields:
    The UDID of the newly-created iOS simulator.
  """
  runtime_version_name = version.replace(".", "-")
  logger.info("Creating simulator, device=%s, version=%s", device, version)
  simctl_create_result = subprocess.run([
      "xcrun", "simctl", "create", "TestDevice", device,
      "com.apple.CoreSimulator.SimRuntime.iOS-" + runtime_version_name
  ],
                                        encoding="utf-8",
                                        check=True,
                                        stdout=subprocess.PIPE)
  udid = simctl_create_result.stdout.rstrip()
  try:
    logger.info("Killing all running simulators...")
    subprocess.run(["pkill", "Simulator"],
                   stderr=subprocess.DEVNULL,
                   check=False)
    yield udid
  finally:
    logger.info("Shutting down simulator with udid: %s", udid)
    subprocess.run(["xcrun", "simctl", "shutdown", udid],
                   stderr=subprocess.DEVNULL,
                   check=False)
    logger.info("Deleting simulator with udid: %s", udid)
    subprocess.run(["xcrun", "simctl", "delete", udid], check=True)


@contextlib.contextmanager
def extracted_app(ios_application_output_path, app_name):
  """Extracts Foo.app from an ios_application() rule's output.

  Args:
    ios_application_output_path: Path to the output of an `ios_application()`.
      If the path is an .ipa archive, unzips it to a temporary directory.
    app_name: The name of the application (e.g. "Foo" for "Foo.app").

  Yields:
    Path to Foo.app.
  """
  if os.path.isdir(ios_application_output_path):
    logger.debug("Found app directory: %s", ios_application_output_path)
    yield os.path.realpath(ios_application_output_path)
  else:
    with tempfile.TemporaryDirectory(prefix="bazel_temp") as temp_dir:
      logger.debug("Unzipping IPA from %s to %s", ios_application_output_path,
                   temp_dir)
      with zipfile.ZipFile(ios_application_output_path) as ipa_zipfile:
        ipa_zipfile.extractall(temp_dir)
        yield os.path.join(temp_dir, "Payload", app_name + ".app")


def bundle_id(bundle_path):
  """Returns the bundle ID given a bundle directory path."""
  info_plist_path = os.path.join(bundle_path, "Info.plist")
  with open(info_plist_path, mode="rb") as plist_file:
    plist = plistlib.load(plist_file)
    return plist["CFBundleIdentifier"]


def simctl_launch_environ():
  """Calculates an environment dictionary for running `simctl launch`."""
  # Pass environment variables prefixed with "IOS_" to the simulator, replace
  # the prefix with "SIMCTL_CHILD_". bazel adds "IOS_" to the env vars which
  # will be passed to the app as prefix to differentiate from other env vars. We
  # replace the prefix "IOS_" with "SIMCTL_CHILD_" here, because "simctl" only
  # pass the env vars prefixed with "SIMCTL_CHILD_" to the app.
  result = {}
  for k, v in os.environ.items():
    if not k.startswith("IOS_"):
      continue
    new_key = k.replace("IOS_", "SIMCTL_CHILD_", 1)
    result[new_key] = v
  return result


def run_app_in_temporary_simulator(sim_device, sim_os_version, developer_path,
                                   ios_application_output_path, app_name):
  """Creates a temporary simulator and launches an app inside.

  Shuts down and deletes the simulator when done.

  Args:
    sim_device: The name of the device (e.g. "iPhone 8 Plus").
    sim_os_version: The version of the iOS runtime (e.g. "13.2").
    developer_path: The path to /Applications/Xcode.app/Contents/Developer.
    ios_application_output_path: Path to the output of an `ios_application()`.
    app_name: The name of the application (e.g. "Foo" for "Foo.app").
  """
  with temporary_ios_simulator(sim_device, sim_os_version) as simulator_udid, \
       booted_simulator(developer_path, simulator_udid) as _, \
       extracted_app(ios_application_output_path, app_name) as app_path:
    logger.debug("Installing app %s to simulator %s", app_path, simulator_udid)
    subprocess.run(["xcrun", "simctl", "install", simulator_udid, app_path],
                   check=True)
    app_bundle_id = bundle_id(app_path)
    logger.info("Launching app %s in simulator %s", app_bundle_id,
                simulator_udid)
    subprocess.run([
        "xcrun", "simctl", "launch", "--console-pty", simulator_udid,
        app_bundle_id
    ],
                   env=simctl_launch_environ(),
                   check=False)


def main(sim_device, sim_os_version, ios_application_output_path, app_name):
  """Main entry point to `bazel run` for ios_application() targets.

  Args:
    sim_device: The name of the device (e.g. "iPhone 8 Plus").
    sim_os_version: The version of the iOS runtime (e.g. "13.2").
    ios_application_output_path: Path to the output of an `ios_application()`.
    app_name: The name of the application (e.g. "Foo" for "Foo.app").

  Raises:
    Exception: if --ios_simulator_version and --ios_simulator_device are not
      both specified.
  """
  xcode_select_result = subprocess.run(["xcode-select", "-p"],
                                       encoding="utf-8",
                                       check=True,
                                       stdout=subprocess.PIPE)
  developer_path = xcode_select_result.stdout.rstrip()

  if sim_device and sim_os_version:
    run_app_in_temporary_simulator(sim_device, sim_os_version, developer_path,
                                   ios_application_output_path, app_name)
  else:
    raise Exception(
        "No simulator device or version configured. Please use both " +
        "--ios_simulator_version and --ios_simulator_device to specify them.")


if __name__ == "__main__":
  try:
    # Tempate values filled in by rules_apple/apple/internal/run_support.bzl.
    main("%sim_device%", "%sim_os_version%", "%ipa_file%", "%app_name%")
  except subprocess.CalledProcessError as e:
    logger.error("%s exited with error code %d", e.cmd, e.returncode)
  except KeyboardInterrupt:
    pass
