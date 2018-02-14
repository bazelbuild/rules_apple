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

"""iOS test runner rule."""

load(
    "@build_bazel_rules_apple//apple/testing:apple_test_rules.bzl",
    "AppleTestRunner"
)


def _get_template_substitutions(ctx):
  """Returns the template substitutions for this runner."""
  test_env = ctx.configuration.test_env
  subs = {
      "os_version": ctx.attr.os_version,
      "test_env": ",".join([k + "=" + v for (k, v) in test_env.items()]),
      "testrunner_binary": ctx.executable._testrunner.short_path,
      "device_type": ctx.attr.device_type,
  }
  return {"%(" + k + ")s": subs[k] for k in subs}


def _ios_test_runner_impl(ctx):
  """Implementation for the ios_test_runner rule."""
  ctx.template_action(
      template = ctx.file._test_template,
      output = ctx.outputs.test_runner_template,
      substitutions = _get_template_substitutions(ctx)
  )
  return struct(
      providers = [
          AppleTestRunner(
              test_runner_template = ctx.outputs.test_runner_template,
              execution_requirements = ctx.attr.execution_requirements,
              test_environment = ctx.configuration.test_env,
          ),
      ],
      runfiles = ctx.runfiles(
          files = [ctx.file._testrunner]
      ),
  )


ios_test_runner = rule(
    _ios_test_runner_impl,
    attrs={
        "_testrunner":
            attr.label(
                default=Label(
                    "@xctestrunner//file"),
                allow_single_file=True,
                executable=True,
                cfg="host",
                doc="""
It is the rule that needs to provide the AppleTestRunner provider. This
dependency is the test runner binary.
"""
            ),
        "_test_template":
            attr.label(
                default=Label(
                    "@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.template.sh"),
                allow_single_file=True,
            ),
        "device_type":
            attr.string(
                default="",
                doc="""
The device type of the iOS simulator to run test. The supported types correspond
to the output of `xcrun simctl list devicetypes`. E.g., iPhone 6, iPad Air.
By default, it is the latest supported iPhone type.'
"""
            ),
        "execution_requirements":
            attr.string_dict(
                allow_empty=False,
                default={"requires-darwin": ""},
                doc="""
Dictionary of strings to strings which specifies the execution requirements for
the runner. In most common cases, this should not be used.
"""
            ),
        "os_version":
            attr.string(
                default="",
                doc="""
The os version of the iOS simulator to run test. The supported os versions
correspond to the output of `xcrun simctl list runtimes`. ' 'E.g., 11.2, 9.3.
By default, it is the latest supported version of the device type.'
"""
            )
    },
    outputs={
        "test_runner_template": "%{name}.sh",
    },
    fragments = ["apple", "objc"],
)
"""Rule to identify an iOS runner that runs tests for iOS.

The runner will create a new simulator according to the given arguments to run
tests.

Outputs:
  AppleTestRunner:
    test_runner_template: Template file that contains the specific mechanism
        with which the tests will be performed.
    execution_requirements: Dictionary that represents the specific hardware
        requirements for this test.
  Runfiles:
    files: The files needed during runtime for the test to be performed.
"""
