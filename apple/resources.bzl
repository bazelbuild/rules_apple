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

"""Rules related to Apple resources and resource bundles."""

load(
    "@build_bazel_rules_apple//apple/internal:resource_rules.bzl",
    _apple_bundle_import = "apple_bundle_import",
    _apple_resource_bundle = "apple_resource_bundle",
)

apple_bundle_import = _apple_bundle_import
apple_resource_bundle = _apple_resource_bundle
