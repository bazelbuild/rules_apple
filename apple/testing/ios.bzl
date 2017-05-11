# Copyright 2017 The Bazel Authors. All rights reserved.
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

"""Proxy file for loading the test rules."""

load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_ui_test",
     "ios_unit_test",
     "ios_unit_test_suite"
    )

print("This file is deprecated. Please load the test rules using " +
      "@build_bazel_rules_apple//apple:ios.bzl.\n" +
      "This file will be deleted after version 0.0.2 is released."
     )
