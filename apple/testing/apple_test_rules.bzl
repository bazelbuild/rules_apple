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

load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts"
)
load(
    "@build_bazel_rules_apple//apple/bundling:file_actions.bzl",
    "file_actions",
)
load(
    "@build_bazel_rules_apple//common:attrs.bzl",
    "attrs",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "AppleExtraOutputsInfo",
)


AppleTestInfo = provider(
    doc="""
Provider that test targets propagate to be used for IDE integration.

This includes information regarding test source files, transitive include paths,
transitive module maps, and transitive Swift modules. Test source files are
considered to be all of which belong to the first-level dependencies on the test
target.
""",
    fields={
        "sources": """
`depset` of `File`s containing sources from the test's immediate deps.
""",
        "non_arc_sources": """
`depset` of `File`s containing non-ARC sources from the test's immediate
deps.
""",
        "includes": """
`depset` of `string`s representing transitive include paths which are needed by
IDEs to be used for indexing the test sources.
""",
        "module_maps": """
`depset` of `File`s representing module maps which are needed by IDEs to be used
for indexing the test sources.
""",
        "swift_modules": """
`depset` of `File`s representing transitive swift modules which are needed by
IDEs to be used for indexing the test sources.
"""
    }
)


AppleTestRunner = provider(
    doc="""
Provider that runner targets must propagate.

In addition to the fields, all the runfiles that the runner target declares will be
added to the test rules runfiles.
""",
    fields={
        "test_runner_template": """
Template file that contains the specific mechanism with
which the tests will be run. The apple_ui_test and apple_unit_test rules
will substitute the following values:
    * %(test_host_path)s:   Path to the app being tested.
    * %(test_bundle_path)s: Path to the test bundle that contains the tests.
    * %(test_type)s:        The test type, whether it is unit or UI.
""",
        "execution_requirements": """
Dictionary that represents the specific hardware
requirements for this test.
""",
        "test_environment": """
Dictionary with the environment variables required for the test.
"""
    }
)


CoverageFiles = provider(
    doc="""
Provider used by the `coverage_files_aspect` aspect to propagate the
transitive closure of sources that a test depends on. These sources are then
made available during the coverage action as they are required by the coverage
insfrastructure. The sources are provided in the `coverage_files` field. This
provider is only available if when coverage collecting is enabled.
"""
)


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
    for files in [x.files for x in attrs.get(ctx.rule.attr, attr, [])]:
      coverage_files += files

  # Collect dependencies coverage files.
  for dep in attrs.get(ctx.rule.attr, "deps", []):
    coverage_files += dep[CoverageFiles].coverage_files
  for attr in ["binary", "test_host"]:
    if hasattr(ctx.rule.attr, attr):
      attr_value = getattr(ctx.rule.attr, attr)
      if attr_value:
        coverage_files += attr_value[CoverageFiles].coverage_files

  return struct(providers=[CoverageFiles(coverage_files=coverage_files)])


coverage_files_aspect = aspect(
    implementation = _coverage_files_aspect_impl,
    attr_aspects = ["binary", "deps", "test_host"],
    doc="""
This aspect walks the dependency graph through the `binary`, `deps` and
`test_host` attributes and collects all the sources and headers that are
depended upon transitively. These files are needed to calculate test coverage on
a test run.

This aspect propagates a `CoverageFiles` provider which is just a set that
contains all the `srcs` and `hdrs` files.
""",
)


def _collect_files(rule_attr, attr_name):
  """Collects files from attr_name (if present) into a depset."""

  attr_val = getattr(rule_attr, attr_name, None)
  if not attr_val:
    return depset()

  attr_val_as_list = attr_val if type(attr_val) == "list" else [attr_val]
  files = [f for src in attr_val_as_list for f in getattr(src, "files", [])]
  return depset(files)


def _merge_depsets(a, b):
  """Combines two depsets into one."""
  return depset(transitive=[a, b])


def _test_info_aspect_impl(target, ctx):
  """See `test_info_aspect` for full documentation."""

  rule_attr = ctx.rule.attr

  # Forward the AppleTestInfo directly if the target is a test bundle.
  if AppleBundleInfo in target:
    return [rule_attr.binary[AppleTestInfo]]

  sources = depset()
  non_arc_sources = depset()
  includes = depset()
  module_maps = depset()
  swift_modules = depset()

  # Not all deps (i.e. source files) will have an AppleTestInfo provider. If the
  # dep doesn't, just filter it out.
  deps = [x for x in getattr(rule_attr, "deps", []) if AppleTestInfo in x]

  # Collect transitive information from deps.
  for dep in deps:
    test_info = dep[AppleTestInfo]
    includes = _merge_depsets(test_info.includes, includes)
    module_maps = _merge_depsets(test_info.module_maps, module_maps)
    swift_modules = _merge_depsets(test_info.swift_modules, swift_modules)

  # Combine the AppleTestInfo sources info from deps into one for apple_binary.
  if ctx.rule.kind == "apple_binary":
    for dep in deps:
      test_info = dep[AppleTestInfo]
      sources = _merge_depsets(test_info.sources, sources)
      non_arc_sources = _merge_depsets(test_info.non_arc_sources,
                                       non_arc_sources)
  else:
    # Collect sources from the current target and add any relevant transitive
    # information. Note that we do not propagate sources transitively as we
    # intentionally only show test sources from the test's first-level of
    # dependencies instead of all transitive dependencies.
    sources = _collect_files(rule_attr, "srcs")
    non_arc_sources = _collect_files(rule_attr, "non_arc_srcs")

    if apple_common.Objc in target:
      includes = _merge_depsets(target[apple_common.Objc].include, includes)
      # Module maps should only be used by Swift targets.
      if hasattr(target, "swift"):
        module_maps = _merge_depsets(target.objc.module_map, module_maps)

    if hasattr(target, "swift") and hasattr(target.swift, "transitive_modules"):
      swift_modules = _merge_depsets(target.swift.transitive_modules,
                                     swift_modules)

  return [AppleTestInfo(
      sources=sources,
      non_arc_sources=non_arc_sources,
      includes=includes,
      module_maps=module_maps,
      swift_modules=swift_modules,
  )]


test_info_aspect = aspect(
    implementation = _test_info_aspect_impl,
    attr_aspects = ["binary", "deps"],
    doc="""
This aspect walks the dependency graph through the `binary` and `deps`
attributes and collects sources, transitive includes, transitive module maps,
and transitive Swift modules.

This aspect propagates an `AppleTestInfo` provider.
""",
)


def _apple_test_common_attributes():
  """Returns the attribute that are common for all apple test rules."""
  return {
      "data": attr.label_list(
          allow_files=True,
          cfg="data",
          default=[],
          doc="Files to be made available to the test during its execution.",
      ),
      "platform_type": attr.string(
          doc="""
The Apple platform that this test is targeting. Required. Possible values are
'ios', 'macos' and 'tvos'.
""",
          mandatory=True,
          values=["ios", "macos", "tvos"],
      ),
      "runner": attr.label(
          doc="""
The runner target that will provide the logic on how to run the tests. Needs to
provide the AppleTestRunner provider. Required.
""",
          providers=[AppleTestRunner],
          mandatory=True,
      ),
      "test_bundle": attr.label(
          aspects=[coverage_files_aspect, test_info_aspect],
          doc="""
The xctest bundle that contains the test code and resources. Required.
""",
          mandatory=True,
          providers=[AppleBundleInfo],
      ),
      # gcov and mcov are binary files required to calculate test coverage.
      "_gcov": attr.label(
          allow_files=True,
          cfg="host",
          default=Label("@bazel_tools//tools/objc:gcov"),
          single_file=True,
      ),
      "_mcov": attr.label(
          allow_files=True,
          cfg="host",
          default=Label("@bazel_tools//tools/objc:mcov"),
          single_file=True,
      ),
      # The realpath binary needed for symlinking.
      "_realpath": attr.label(
          allow_files=True,
          cfg="host",
          default=Label("@build_bazel_rules_apple//tools/realpath"),
          single_file=True,
      ),
  }


def _apple_unit_test_attributes():
  """Returns the attributes for the apple_unit_test rule."""
  return dicts.add(
      _apple_test_common_attributes(),
      {
          "test_host": attr.label(
              doc="The test app that will host the tests. Optional.",
              mandatory=False,
              providers=[AppleBundleInfo],
          ),
      }
  )


def _apple_ui_test_attributes():
  """Returns the attributes for the apple_ui_test rule."""
  return dicts.add(
      _apple_test_common_attributes(),
      {
          "test_host": attr.label(
              doc="The app to be tested. Required.",
              mandatory=True,
              providers=[AppleBundleInfo],
          ),
      }
  )


def _get_template_substitutions(ctx, test_type):
  """Dictionary with the substitutions to be applied to the template script."""
  subs = {}

  if ctx.attr.test_host:
    subs["test_host_path"] = ctx.attr.test_host[AppleBundleInfo].archive.short_path
  else:
    subs["test_host_path"] = ""
  subs["test_bundle_path"] = ctx.outputs.test_bundle.short_path
  subs["test_type"] = test_type.upper()

  return {"%(" + k + ")s": subs[k] for k in subs}


def _get_coverage_test_environment(ctx):
  """Returns environment variables required for test coverage support."""
  gcov_files = ctx.attr._gcov.files.to_list()
  return {
      "APPLE_COVERAGE": "1",
      # TODO(b/72383680): Remove the workspace_name prefix for the path.
      "COVERAGE_GCOV_PATH": "/".join(["runfiles",
                                      ctx.workspace_name,
                                      gcov_files[0].path]),
  }


def _apple_test_impl(ctx, test_type):
  """Common implementation for the apple test rules."""
  runner = ctx.attr.runner[AppleTestRunner]
  execution_requirements = runner.execution_requirements
  test_environment = runner.test_environment

  test_runfiles = [ctx.outputs.test_bundle]
  test_host = ctx.attr.test_host
  if test_host:
    test_runfiles.append(test_host[AppleBundleInfo].archive)

  if ctx.configuration.coverage_enabled:
    test_environment = dicts.add(test_environment,
                                 _get_coverage_test_environment(ctx))
    test_runfiles.extend(
        list(ctx.attr.test_bundle[CoverageFiles].coverage_files))
    test_runfiles.extend(ctx.attr._gcov.files.to_list())
    test_runfiles.extend(ctx.attr._mcov.files.to_list())

  file_actions.symlink(ctx,
                       ctx.attr.test_bundle[AppleBundleInfo].archive,
                       ctx.outputs.test_bundle)

  executable = ctx.actions.declare_file("%s" % ctx.label.name)
  ctx.actions.expand_template(
      template = runner.test_runner_template,
      output = executable,
      substitutions = _get_template_substitutions(ctx, test_type),
  )

  # Add required data into the runfiles to make it available during test
  # execution.
  for data_dep in ctx.attr.data:
    test_runfiles.extend(data_dep.files.to_list())

  outputs = depset([ctx.outputs.test_bundle, executable])

  extra_outputs_provider = ctx.attr.test_bundle[AppleExtraOutputsInfo]
  if extra_outputs_provider:
    outputs += extra_outputs_provider.files

  extra_providers = []
  # TODO(b/110264170): Repropagate the provider that makes the dSYM bundle
  # available as opposed to AppleDebugOutputs which propagates the standalone
  # binaries.
  if apple_common.AppleDebugOutputs in ctx.attr.test_bundle:
    extra_providers.append(
        ctx.attr.test_bundle[apple_common.AppleDebugOutputs]
    )

  return struct(
      # TODO(b/79527231): Migrate to new style providers.
      instrumented_files=struct(dependency_attributes=["test_bundle"]),
      providers=[
          ctx.attr.test_bundle[AppleBundleInfo],
          ctx.attr.test_bundle[AppleTestInfo],
          testing.ExecutionInfo(execution_requirements),
          testing.TestEnvironment(test_environment),
          DefaultInfo(
              executable=executable,
              files=outputs,
              runfiles=ctx.runfiles(
                  files=test_runfiles,
                  transitive_files=ctx.attr.runner.data_runfiles.files
              ),
          ),
      ] + extra_providers,
  )


def _apple_unit_test_impl(ctx):
  """Implementation for the apple_unit_test rule."""
  return _apple_test_impl(ctx, "xctest")


def _apple_ui_test_impl(ctx):
  """Implementation for the apple_ui_test rule."""
  return _apple_test_impl(ctx, "xcuitest")


apple_ui_test = rule(
    implementation=_apple_ui_test_impl,
    attrs=_apple_ui_test_attributes(),
    doc="""
Rule to execute UI (XCUITest) tests for a generic Apple platform.

Outputs:
  test_bundle: The xctest bundle being tested. This is returned here as a
      symlink to the bundle target in order to make it available for inspection
      when executing `bazel build` on this target.
  executable: The test script to be executed to run the tests.
""",
    fragments=["apple", "objc"],
    outputs={
        "test_bundle": "%{name}.zip",
    },
    test=True,
)


apple_unit_test = rule(
    _apple_unit_test_impl,
    attrs=_apple_unit_test_attributes(),
    doc="""
Rule to execute unit (XCTest) tests for a generic Apple platform.

Outputs:
  test_bundle: The xctest bundle being tested. This is returned here as a
      symlink to the bundle target in order to make it available for inspection
      when executing `bazel build` on this target.
  executable: The test script to be executed to run the tests.
""",
    fragments=["apple", "objc"],
    outputs={
        "test_bundle": "%{name}.zip",
    },
    test=True,
)
