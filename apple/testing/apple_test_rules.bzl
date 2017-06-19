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

# Provider used by the `coverage_files_aspect` aspect to propagate the
# transitive closure of sources that a test depends on. These sources are then
# made available during the coverage action as they are required by the coverage
# insfrastructure. The sources are provided in the `coverage_files` field. This
# provider is only available if when coverage collecting is enabled.
CoverageFiles = provider()


def _coverage_files_aspect_impl(target, ctx):
  """Implementation for the `coverage_files_aspect` aspect."""
  # target is needed for the method signature that aspect() expects in the
  # implementation method.
  target = target  # unused argument

  # Skip collecting files if coverage is not enabled.
  if not ctx.configuration.coverage_enabled:
    return struct()

  coverage_files = depset()

  # Collect this target's coverage files.
  for attr in ["srcs", "hdrs", "non_arc_srcs"]:
    if hasattr(ctx.rule.attr, attr):
      for files in [x.files for x in getattr(ctx.rule.attr, attr)]:
        coverage_files += files

  # Collect dependencies coverage files.
  if hasattr(ctx.rule.attr, "deps"):
    for dep in ctx.rule.attr.deps:
      coverage_files += dep[CoverageFiles].coverage_files
  if hasattr(ctx.rule.attr, "binary"):
    coverage_files += ctx.rule.attr.binary[CoverageFiles].coverage_files

  return struct(providers=[CoverageFiles(coverage_files=coverage_files)])


coverage_files_aspect = aspect(
    implementation = _coverage_files_aspect_impl,
    attr_aspects = ["binary", "deps", "test_host"],
)
"""
This aspect walks the dependency graph through the `binary`, `deps` and
`test_host` attributes and collects all the sources and headers that are
depended upon transitively. These files are needed to calculate test coverage on
a test run.

This aspect propagates a `CoverageFiles` provider which is just a set that
contains all the `srcs` and `hdrs` files.
"""


def _apple_test_common_attributes():
  """Returns the attribute that are common for all apple test rules."""
  return {
      # List of files to make available during the running of the test.
      "data": attr.label_list(
          allow_files=True,
          default=[],
      ),
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
          aspects=[coverage_files_aspect],
          providers=["apple_bundle"],
      ),
      # gcov and mcov are binary files required to calculate test coverage.
      "_gcov": attr.label(
          cfg="host",
          allow_files=True,
          single_file=True,
          default=Label("@bazel_tools//tools/objc:gcov"),
      ),
      "_mcov": attr.label(
          cfg="host",
          allow_files=True,
          single_file=True,
          default=Label("@bazel_tools//tools/objc:mcov"),
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


def _get_coverage_test_environment(ctx):
  """Returns environment variables required for test coverage support."""
  gcov_files = ctx.attr._gcov.files.to_list()
  return {
      "APPLE_COVERAGE": "1",
      "COVERAGE_GCOV_PATH": gcov_files[0].path,
  }


def _apple_test_impl(ctx, test_type):
  """Common implementation for the apple test rules."""
  runner = ctx.attr.runner[AppleTestRunner]
  execution_requirements = runner.execution_requirements
  test_environment = runner.test_environment

  test_runfiles = ([ctx.outputs.test_bundle] + ctx.files.test_host +
                   ctx.attr._mcov.files.to_list())

  if ctx.configuration.coverage_enabled:
    test_environment = merge_dictionaries(test_environment,
                                          _get_coverage_test_environment(ctx))
    test_runfiles.extend(
        list(ctx.attr.test_bundle[CoverageFiles].coverage_files))

  file_actions.symlink(ctx,
                       ctx.attr.test_bundle.apple_bundle.archive,
                       ctx.outputs.test_bundle)

  ctx.template_action(
      template = runner.test_runner_template,
      output = ctx.outputs.executable,
      substitutions = _get_template_substitutions(ctx, test_type),
  )

  # Add required data into the runfiles to make it available during test
  # execution.
  for data_dep in ctx.attr.data:
    test_runfiles.extend(data_dep.files.to_list())

  return struct(
      files=depset([ctx.outputs.test_bundle, ctx.outputs.executable]),
      instrumented_files=struct(dependency_attributes=["test_bundle"]),
      providers=[
          testing.ExecutionInfo(execution_requirements),
          testing.TestEnvironment(test_environment)
      ],
      runfiles=ctx.runfiles(
          files=test_runfiles,
          transitive_files=ctx.attr.runner.data_runfiles.files
      ),
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
