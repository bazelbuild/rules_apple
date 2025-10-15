#!/bin/bash

# Copyright 2018 The Bazel Authors. All rights reserved.
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

set -e

simulator_pool_config_output_path="$PWD/simulator_pool_config.json"

"%create_simulator_pool%" \
    --os-version "%os_version%" \
    --device-type "%device_type%" \
    --pool-size "%pool_size%" \
    --simulator-pool-config-output-path "$simulator_pool_config_output_path"

"%simulator_pool_server%" \
    --simulator-pool-config-path "$simulator_pool_config_output_path" \
    --port "%simulator_pool_port%" > "$PWD/simulator_pool_server.log" 2>&1 &
