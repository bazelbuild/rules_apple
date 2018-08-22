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

"""Experimental implementation of iOS test bundle rules."""

load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "IosXcTestBundleInfo",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental/testing:apple_test_bundle_support.bzl",
    "apple_test_bundle_support",
)

def ios_test_bundle_impl(ctx):
    """Experimental implementation of ios_application."""
    providers = apple_test_bundle_support.apple_test_bundle_impl(ctx)
    return providers + [IosXcTestBundleInfo()]
