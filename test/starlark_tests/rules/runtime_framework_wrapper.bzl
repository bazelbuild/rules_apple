# Copyright 2026 The Bazel Authors. All rights reserved.
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

"""Rule to wrap an Apple framework target without forwarding AppleEmbeddedFrameworkBundleInfo."""

load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "AppleDsymBundleInfo",
    "AppleFrameworkBundleInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "AppleLinkmapInfo",
)

visibility("//test/starlark_tests/...")

def _runtime_framework_wrapper_impl(ctx):
    target = ctx.attr.target
    providers = [
        DefaultInfo(files = target[DefaultInfo].files),
    ]
    if AppleBundleInfo in target:
        providers.append(target[AppleBundleInfo])
    if AppleDsymBundleInfo in target:
        providers.append(target[AppleDsymBundleInfo])
    if AppleFrameworkBundleInfo in target:
        providers.append(target[AppleFrameworkBundleInfo])
    if AppleLinkmapInfo in target:
        providers.append(target[AppleLinkmapInfo])
    if OutputGroupInfo in target:
        providers.append(target[OutputGroupInfo])
    return providers

runtime_framework_wrapper = rule(
    implementation = _runtime_framework_wrapper_impl,
    attrs = {
        "target": attr.label(
            mandatory = True,
            doc = "The framework target to wrap.",
        ),
    },
    doc = """
Wraps an Apple framework target, forwarding AppleFrameworkBundleInfo, AppleBundleInfo,
AppleDsymBundleInfo, AppleLinkmapInfo, and DefaultInfo(files = target[DefaultInfo].files),
but intentionally omitting AppleEmbeddedFrameworkBundleInfo.

This mimics wrapper rules like j2kt_transitioned_ios_framework to test fallback
framework bundling logic in framework_provider_aspect.
""",
)
