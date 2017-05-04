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

"""Generic test rules for running tests against Apple platforms.

These are internal rules not to be used outside of the
@build_bazel_rules_apple//apple package.
"""

load("@build_bazel_rules_apple//apple/bundling:file_actions.bzl",
     "file_actions")
load("@build_bazel_rules_apple//apple:utils.bzl",
     "merge_dictionaries")


# Provider that runner targets must conform to. The required fields that need to
# be present are:
#
# test_runner_template: Template file that contains the specific mechanism with
#   which the tests will be run. The apple_ui_test and apple_unit_test rules
#   will substitute the following values:
#     * %(test_host_path)s:   Path to the app being tested.
#     * %(test_bundle_path)s: Path to the test bundle that contains the tests.
#     * %(test_type)s:        The test type, whether it is unit or UI.
#
# execution_requirements: Dictionary that represents the specific hardware
#   requirements for this test.
#
# test_environment: Dictionary with the environment variables required for the
#   test.
#
# In addition to this, all the runfiles that the runner target declares will be
# added to the test rules runfiles.
AppleTestRunner = provider()


def _apple_test_common_attributes():
  """Returns the attribute that are common for all apple test rules."""
  return {
      # The runner target that provides the logic on how to run the test by
      # means of the AppleTestRunner provider.
      "runner": attr.label(
          # TODO(b/31854716): Enable provider enforcing once it accepts the
          # new declared providers style.
          # providers=[AppleTestRunner],
          mandatory=True,
      ),
      # The test_bundle target that provides the xctest bundle with the test
      # code.
      "test_bundle": attr.label(
          mandatory=True,
          providers = ["apple_bundle"],
      ),
      # The realpath binary needed for symlinking.
      "_realpath": attr.label(
          cfg="host",
          allow_files=True,
          single_file=True,
          default=Label("@build_bazel_rules_apple//tools/realpath"),
      ),
  }


def _apple_unit_test_attributes():
  """Returns the attributes for the apple_unit_test rule."""
  return merge_dictionaries(
      _apple_test_common_attributes(),
      {
          # The test host app being tested.
          "test_host": attr.label(
              mandatory=True,
              providers = ["apple_bundle"],
          ),
      }
  )


def _apple_ui_test_attributes():
  """Returns the attributes for the apple_ui_test rule."""
  return merge_dictionaries(
      _apple_test_common_attributes(),
      {
          # The test host app being tested.
          "test_host": attr.label(
              mandatory=True,
              providers = ["apple_bundle"],
          ),
      }
  )


def _get_template_substitutions(ctx, test_type):
  """Dictionary with the substitutions to be applied to the template script."""
  subs = {}

  subs["test_host_path"] = ctx.attr.test_host.apple_bundle.archive.short_path
  subs["test_bundle_path"] = ctx.outputs.test_bundle.short_path
  subs["test_type"] = test_type.upper()

  return {"%(" + k + ")s": subs[k] for k in subs}


def _apple_test_impl(ctx, test_type):
  """Common implementation for the apple test rules."""
  runner = ctx.attr.runner[AppleTestRunner]
  execution_requirements = runner.execution_requirements
  test_environment = runner.test_environment

  test_runfiles = [ctx.outputs.test_bundle] + ctx.files.test_host

  file_actions.symlink(ctx,
                       ctx.attr.test_bundle.apple_bundle.archive,
                       ctx.outputs.test_bundle)

  ctx.template_action(
      template = runner.test_runner_template,
      output = ctx.outputs.executable,
      substitutions = _get_template_substitutions(ctx, test_type),
  )

  return struct(
      providers=[
          testing.ExecutionInfo(execution_requirements),
          testing.TestEnvironment(test_environment)
      ],
      runfiles=ctx.runfiles(
          files = test_runfiles,
          transitive_files=ctx.attr.runner.data_runfiles.files
      ),
      files=depset([ctx.outputs.test_bundle, ctx.outputs.executable]),
  )


def _apple_unit_test_impl(ctx):
  """Implementation for the apple_unit_test rule."""
  return _apple_test_impl(ctx, "xctest")


def _apple_ui_test_impl(ctx):
  """Implementation for the apple_ui_test rule."""
  return _apple_test_impl(ctx, "xcuitest")


apple_ui_test = rule(
    _apple_ui_test_impl,
    test=True,
    attrs=_apple_ui_test_attributes(),
    outputs={
        # TODO(b/34978210): Revert to .zip once Tulsi supports this use case.
        "test_bundle": "%{name}.ipa",
    },
    fragments=["apple", "objc"],
)
"""Rule to execute unit (XCTest) tests for a generic Apple platform.

Args:
  runner: The runner target that will provide the logic on how to run the tests.
      Needs to provide the AppleTestRunner provider. Required.
  test_bundle: The xctest bundle that contains the test code and resources.
      Required.
  test_host: The test app that will host the tests. Optional.

Outputs:
  test_bundle: The xctest bundle being tested. This is returned here as a
      symlink to the bundle target in order to make it available for inspection
      when executing `blaze build` on this target.
  executable: The test script to be executed to run the tests.
"""


apple_unit_test = rule(
    _apple_unit_test_impl,
    test=True,
    attrs=_apple_unit_test_attributes(),
    outputs={
        # TODO(b/34978210): Revert to .zip once Tulsi supports this use case.
        "test_bundle": "%{name}.ipa",
    },
    fragments=["apple", "objc"],
)
"""Rule to execute UI (XCUITest) tests for a generic Apple platform.

Args:
  runner: The runner target that will provide the logic on how to run the tests.
      Needs to provide the AppleTestRunner provider. Required.
  test_bundle: The xctest bundle that contains the test code and resources.
      Required.
  test_host: The test app that will be tested using XCUITests. Required.

Outputs:
  test_bundle: The xctest bundle being tested. This is returned here as a
      symlink to the bundle target in order to make it available for inspection
      when executing `blaze build` on this target.
  executable: The test script to be executed to run the tests.
"""
