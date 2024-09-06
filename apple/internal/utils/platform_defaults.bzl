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

"""Shared default values for Apple platforms."""

visibility("//apple/internal/...")

_PLATFORM_TYPE_TO_DEVICE_FAMILIES = {
    "ios": ["iphone", "ipad"],
    "macos": ["mac"],
    "tvos": ["tv"],
    "visionos": ["vision"],
    "watchos": ["watch"],
}

def _device_families(platform_type):
    """Returns the default device families list for a given platform."""
    return _PLATFORM_TYPE_TO_DEVICE_FAMILIES[platform_type]

platform_defaults = struct(
    device_families = _device_families,
)
