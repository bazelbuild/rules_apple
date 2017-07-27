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

"""Sample Apple test runner rule."""

load(
    "@build_bazel_rules_apple//apple/testing:apple_test_rules.bzl",
    "AppleTestRunner"
)


def _macos_sample_test_runner_impl(ctx):
  """Implementation for the macos_sample_test_runner rule."""
  ctx.template_action(
      template = ctx.file._test_template,
      output = ctx.outputs.test_runner_template,
      substitutions = {}
  )

  return struct(
      providers = [
          AppleTestRunner(
              test_runner_template = ctx.outputs.test_runner_template,
              execution_requirements = {"requires-darwin": ""},
              test_environment = {},
          ),
      ],
      runfiles = ctx.runfiles(
          files = [],
      ),
  )


macos_sample_test_runner = rule(
    _macos_sample_test_runner_impl,
    attrs={
        "_test_template": attr.label(
            default=Label("@build_bazel_rules_apple//apple/testing/default_runner:macos_sample_test_runner.template.sh"),
            allow_single_file=True,
        ),
    },
    outputs={
        "test_runner_template": "%{name}.sh",
    },
    fragments=["apple", "objc"],
)
"""Sample rule that shows how to setup a macOS test runner.

This runner does not actually perform any tests yet.

Provides:
  AppleTestRunner:
    test_runner_template: Template file that contains the specific mechanism
        with which the tests will be performed.
    execution_requirements: Dictionary that represents the specific hardware
        requirements for this test.
    test_environment: Dictionary with the environment variables required for the
        test.
  runfiles:
    files: The files needed during runtime for the test to be performed.
"""
