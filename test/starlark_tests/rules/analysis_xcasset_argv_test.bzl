# Copyright 2019 The Bazel Authors. All rights reserved.
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

"Starlark test for testing the argv of actions that create xcassets."

load(
    "@bazel_skylib//lib:unittest.bzl",
    "analysistest",
    "unittest",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
)

def _analysis_xcasset_argv_test_impl(ctx):
    "Test that the argv values sent to `actool` match the target's values."
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    if not AppleBundleInfo in target:
        unittest.fail(env, "Could not read AppleBundleInfo.")
        return analysistest.end(env)
    bundle_info = target[AppleBundleInfo]
    platform_type = getattr(apple_common.platform_type, bundle_info.platform_type)
    platform = ctx.fragments.apple.multi_arch_platform(platform_type)
    expected_argv = [
        "--minimum-deployment-target " + bundle_info.minimum_os_version,
        "--product-type " + bundle_info.product_type,
        "--platform " + platform.name_in_plist.lower(),
    ]
    no_xcasset = True
    for action in analysistest.target_actions(env):
        if hasattr(action, "argv") and action.argv:
            concat_action_argv = " ".join(action.argv)
            if not "xctoolrunner actool " in concat_action_argv:
                continue
            for test_argv in expected_argv:
                if not test_argv in concat_action_argv:
                    unittest.fail(env, "\"{}\" not in actool's arguments \"{}\".".format(
                        test_argv,
                        concat_action_argv,
                    ))
            no_xcasset = False

    if no_xcasset:
        unittest.fail(env, "Did not find any xcasset actions to test.")
    return analysistest.end(env)

analysis_xcasset_argv_test = analysistest.make(
    _analysis_xcasset_argv_test_impl,
    fragments = ["apple"],
)
