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
    "@build_bazel_rules_apple//apple/bundling:file_actions.bzl",
    "file_actions",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "AppleExtraOutputsInfo",
    LegacySwiftInfo = "SwiftInfo",
)
load(
    "@build_bazel_rules_apple//common:attrs.bzl",
    "attrs",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "SwiftInfo",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)

AppleTestInfo = provider(
    doc = """
Provider that test targets propagate to be used for IDE integration.

This includes information regarding test source files, transitive include paths,
transitive module maps, and transitive Swift modules. Test source files are
considered to be all of which belong to the first-level dependencies on the test
target.
""",
    fields = {
        "includes": """
`depset` of `string`s representing transitive include paths which are needed by
IDEs to be used for indexing the test sources.
""",
        "module_maps": """
`depset` of `File`s representing module maps which are needed by IDEs to be used
for indexing the test sources.
""",
        "module_name": """
`string` representing the module name used by the test's sources. This is only
set if the test only contains a single top-level Swift dependency. This may be
used by an IDE to identify the Swift module (if any) used by the test's sources.
""",
        "non_arc_sources": """
`depset` of `File`s containing non-ARC sources from the test's immediate
deps.
""",
        "sources": """
`depset` of `File`s containing sources from the test's immediate deps.
""",
        "swift_modules": """
`depset` of `File`s representing transitive swift modules which are needed by
IDEs to be used for indexing the test sources.
""",
        "deps": """
`depset` of `string`s representing the labels of all immediate deps of the test.
Only source files from these deps will be present in `sources`. This may be used
by IDEs to differentiate a test target's transitive module maps from its direct
module maps, as including the direct module maps may break indexing for the
source files of the immediate deps.
""",
    },
)

AppleTestRunner = provider(
    doc = """
Provider that runner targets must propagate.

In addition to the fields, all the runfiles that the runner target declares will be
added to the test rules runfiles.
""",
    fields = {
        "execution_requirements": """
Dictionary that represents the specific hardware
requirements for this test.
""",
        "test_environment": """
Dictionary with the environment variables required for the test.
""",
        "test_runner_template": """
Template file that contains the specific mechanism with
which the tests will be run. The apple_ui_test and apple_unit_test rules
will substitute the following values:
    * %(test_host_path)s:   Path to the app being tested.
    * %(test_bundle_path)s: Path to the test bundle that contains the tests.
    * %(test_type)s:        The test type, whether it is unit or UI.
""",
    },
)

CoverageFiles = provider(
    doc = """
Provider used by the `coverage_files_aspect` aspect to propagate the
transitive closure of sources and binaries that a test depends on. These files
are then made available during the coverage action as they are required by the
coverage insfrastructure. The sources are provided in the `coverage_files` field,
and the binaries in the `covered_binaries` field. This provider is only available
if when coverage collecting is enabled.
""",
)

def _coverage_files_aspect_impl(target, ctx):
    """Implementation for the `coverage_files_aspect` aspect."""

    # Skip collecting files if coverage is not enabled.
    if not ctx.configuration.coverage_enabled:
        return struct()

    coverage_files = depset()

    # Collect this target's coverage files.
    for attr in ["srcs", "hdrs", "non_arc_srcs"]:
        for files in [x.files for x in attrs.get(ctx.rule.attr, attr, [])]:
            coverage_files = _merge_depsets(files, coverage_files)

    # Collect dependencies coverage files.
    for dep in attrs.get(ctx.rule.attr, "deps", []):
        coverage_files = _merge_depsets(dep[CoverageFiles].coverage_files, coverage_files)

    # Collect the binaries themselves from the various bundles involved in the test. These will be
    # passed through the test environment so that `llvm-cov` can access the coverage mapping data
    # embedded in them.
    direct_binaries = []
    transitive_binaries_sets = []
    if AppleBundleInfo in target:
        direct_binaries.append(target[AppleBundleInfo].binary)

    for attr in ["binary", "test_host"]:
        if hasattr(ctx.rule.attr, attr):
            attr_value = getattr(ctx.rule.attr, attr)
            if attr_value:
                coverage_files = _merge_depsets(attr_value[CoverageFiles].coverage_files, coverage_files)
                transitive_binaries_sets.append(attr_value[CoverageFiles].covered_binaries)

    return struct(providers = [
        CoverageFiles(
            coverage_files = coverage_files,
            covered_binaries = depset(
                direct = direct_binaries,
                transitive = transitive_binaries_sets,
            ),
        ),
    ])

coverage_files_aspect = aspect(
    attr_aspects = [
        "binary",
        "deps",
        "test_host",
    ],
    doc = """
This aspect walks the dependency graph through the `binary`, `deps` and
`test_host` attributes and collects all the sources and headers that are
depended upon transitively. These files are needed to calculate test coverage on
a test run.

This aspect propagates a `CoverageFiles` provider which is just a set that
contains all the `srcs` and `hdrs` files.
""",
    implementation = _coverage_files_aspect_impl,
)

def _collect_files(rule_attr, attr_name):
    """Collects files from attr_name (if present) into a depset."""

    attr_val = getattr(rule_attr, attr_name, None)
    if not attr_val:
        return depset()

    attr_val_as_list = attr_val if type(attr_val) == type([]) else [attr_val]
    files = [f for src in attr_val_as_list for f in getattr(src, "files", [])]
    return depset(files)

def _merge_depsets(a, b):
    """Combines two depsets into one."""
    return depset(transitive = [a, b])

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
    dep_labels = []
    module_name = None

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
        swift_infos = []
        for dep in deps:
            dep_labels.append(str(dep.label))

            if SwiftInfo in dep:
                swift_infos.append(dep[SwiftInfo])

            test_info = dep[AppleTestInfo]
            sources = _merge_depsets(test_info.sources, sources)
            non_arc_sources = _merge_depsets(
                test_info.non_arc_sources,
                non_arc_sources,
            )

        # Set module_name only for test targets with a single Swift dependency.
        # This is not used if there are multiple Swift dependencies, as it will
        # not be possible to reduce them into a single Swift module and picking
        # an arbitrary one is fragile.
        if len(swift_infos) == 1:
            module_name = getattr(swift_infos[0], "module_name", None)
    else:
        # Collect sources from the current target and add any relevant transitive
        # information. Note that we do not propagate sources transitively as we
        # intentionally only show test sources from the test's first-level of
        # dependencies instead of all transitive dependencies.
        sources = _collect_files(rule_attr, "srcs")
        non_arc_sources = _collect_files(rule_attr, "non_arc_srcs")

        if apple_common.Objc in target:
            objc_provider = target[apple_common.Objc]
            includes = _merge_depsets(objc_provider.include, includes)

            # Module maps should only be used by Swift targets.
            if SwiftInfo in target or LegacySwiftInfo in target:
                module_maps = _merge_depsets(objc_provider.module_map, module_maps)

        if (SwiftInfo in target and
            hasattr(target[SwiftInfo], "transitive_swiftmodules")):
            swift_modules = _merge_depsets(
                target[SwiftInfo].transitive_swiftmodules,
                swift_modules,
            )
        if (LegacySwiftInfo in target and
            hasattr(target[LegacySwiftInfo], "transitive_modules")):
            swift_modules = _merge_depsets(
                target[LegacySwiftInfo].transitive_modules,
                swift_modules,
            )

    return [AppleTestInfo(
        sources = sources,
        non_arc_sources = non_arc_sources,
        includes = includes,
        module_maps = module_maps,
        swift_modules = swift_modules,
        deps = depset(dep_labels),
        module_name = module_name,
    )]

test_info_aspect = aspect(
    attr_aspects = [
        "binary",
        "deps",
    ],
    doc = """
This aspect walks the dependency graph through the `binary` and `deps`
attributes and collects sources, transitive includes, transitive module maps,
and transitive Swift modules.

This aspect propagates an `AppleTestInfo` provider.
""",
    implementation = _test_info_aspect_impl,
)

def _apple_test_common_attributes():
    """Returns the attribute that are common for all apple test rules."""
    return {
        "data": attr.label_list(
            allow_files = True,
            default = [],
            doc = "Files to be made available to the test during its execution.",
        ),
        "env": attr.string_dict(
            doc = """
Dictionary of environment variables that should be set during the test execution.
""",
        ),
        "platform_type": attr.string(
            doc = """
The Apple platform that this test is targeting. Required. Possible values are
'ios', 'macos' and 'tvos'.
""",
            mandatory = True,
            values = ["ios", "macos", "tvos"],
        ),
        "runner": attr.label(
            doc = """
The runner target that will provide the logic on how to run the tests. Needs to
provide the AppleTestRunner provider. Required.
""",
            providers = [AppleTestRunner],
            mandatory = True,
        ),
        "test_bundle": attr.label(
            aspects = [coverage_files_aspect, test_info_aspect],
            doc = """
The xctest bundle that contains the test code and resources. Required.
""",
            mandatory = True,
            providers = [AppleBundleInfo],
        ),
        "_apple_coverage_support": attr.label(
            cfg = "host",
            default = Label("@build_bazel_apple_support//tools:coverage_support"),
        ),
        # gcov and mcov are binary files required to calculate test coverage.
        "_gcov": attr.label(
            cfg = "host",
            default = Label("@bazel_tools//tools/objc:gcov"),
            allow_single_file = True,
        ),
        "_mcov": attr.label(
            cfg = "host",
            default = Label("@bazel_tools//tools/objc:mcov"),
            allow_single_file = True,
        ),
        # The realpath binary needed for symlinking.
        "_realpath": attr.label(
            cfg = "host",
            default = Label("@build_bazel_rules_apple//tools/realpath"),
            allow_single_file = True,
        ),
    }

def _apple_unit_test_attributes():
    """Returns the attributes for the apple_unit_test rule."""
    return dicts.add(
        _apple_test_common_attributes(),
        {
            "test_host": attr.label(
                doc = "The test app that will host the tests. Optional.",
                mandatory = False,
                providers = [AppleBundleInfo],
            ),
        },
    )

def _apple_ui_test_attributes():
    """Returns the attributes for the apple_ui_test rule."""
    return dicts.add(
        _apple_test_common_attributes(),
        {
            "provisioning_profile": attr.label(
                doc = "The provisioning_profile for signing .xctest",
                allow_single_file = [".mobileprovision", ".provisionprofile"],
            ),
            "test_host": attr.label(
                doc = "The app to be tested. Required.",
                mandatory = True,
                providers = [AppleBundleInfo],
            ),
        },
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
    coverage_files = ctx.attr.test_bundle[CoverageFiles]
    covered_binary_paths = [f.short_path for f in coverage_files.covered_binaries.to_list()]

    return {
        "APPLE_COVERAGE": "1",
        # TODO(b/72383680): Remove the workspace_name prefix for the path.
        "COVERAGE_GCOV_PATH": "/".join([
            "runfiles",
            ctx.workspace_name,
            gcov_files[0].path,
        ]),
        "TEST_BINARIES_FOR_LLVM_COV": ";".join(covered_binary_paths),
    }

def _apple_test_impl(ctx, test_type):
    """Common implementation for the apple test rules."""
    runner = ctx.attr.runner[AppleTestRunner]
    execution_requirements = runner.execution_requirements

    # TODO(b/120222745): Standardize the setup of the environment variables passed on the env
    # attribute.
    test_environment = dicts.add(
        ctx.attr.env,
        runner.test_environment,
    )

    direct_runfiles = [ctx.outputs.test_bundle]
    transitive_runfiles = []
    test_host = ctx.attr.test_host
    if test_host:
        direct_runfiles.append(test_host[AppleBundleInfo].archive)

    if ctx.configuration.coverage_enabled:
        test_environment = dicts.add(
            test_environment,
            _get_coverage_test_environment(ctx),
        )
        transitive_runfiles.append(
            ctx.attr.test_bundle[CoverageFiles].coverage_files,
        )
        transitive_runfiles.append(
            ctx.attr.test_bundle[CoverageFiles].covered_binaries,
        )
        transitive_runfiles.append(ctx.attr._gcov.files)
        transitive_runfiles.append(ctx.attr._mcov.files)
        transitive_runfiles.append(ctx.attr._apple_coverage_support.files)

    file_actions.symlink(
        ctx,
        ctx.attr.test_bundle[AppleBundleInfo].archive,
        ctx.outputs.test_bundle,
    )

    executable = ctx.actions.declare_file("%s" % ctx.label.name)
    ctx.actions.expand_template(
        template = runner.test_runner_template,
        output = executable,
        substitutions = _get_template_substitutions(ctx, test_type),
    )

    # Add required data into the runfiles to make it available during test
    # execution.
    for data_dep in ctx.attr.data:
        transitive_runfiles.append(data_dep.files)

    outputs = depset([ctx.outputs.test_bundle, executable])

    extra_outputs_provider = ctx.attr.test_bundle[AppleExtraOutputsInfo]
    if extra_outputs_provider:
        outputs = _merge_depsets(extra_outputs_provider.files, outputs)

    extra_providers = []

    # TODO(b/110264170): Repropagate the provider that makes the dSYM bundle
    # available as opposed to AppleDebugOutputs which propagates the standalone
    # binaries.
    if apple_common.AppleDebugOutputs in ctx.attr.test_bundle:
        extra_providers.append(
            ctx.attr.test_bundle[apple_common.AppleDebugOutputs],
        )

    return struct(
        # TODO(b/79527231): Migrate to new style providers.
        instrumented_files = struct(dependency_attributes = ["test_bundle"]),
        providers = [
            ctx.attr.test_bundle[AppleBundleInfo],
            ctx.attr.test_bundle[AppleTestInfo],
            testing.ExecutionInfo(execution_requirements),
            testing.TestEnvironment(test_environment),
            DefaultInfo(
                executable = executable,
                files = outputs,
                runfiles = ctx.runfiles(
                    files = direct_runfiles,
                    transitive_files = depset(transitive = transitive_runfiles),
                )
                    .merge(ctx.attr.runner.default_runfiles)
                    .merge(ctx.attr.runner.data_runfiles),
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
    attrs = _apple_ui_test_attributes(),
    doc = """
Rule to execute UI (XCUITest) tests for a generic Apple platform.

Outputs:
  test_bundle: The xctest bundle being tested. This is returned here as a
      symlink to the bundle target in order to make it available for inspection
      when executing `bazel build` on this target.
  executable: The test script to be executed to run the tests.
""",
    fragments = [
        "apple",
        "objc",
    ],
    outputs = {
        "test_bundle": "%{name}.zip",
    },
    test = True,
    implementation = _apple_ui_test_impl,
)

apple_unit_test = rule(
    _apple_unit_test_impl,
    attrs = _apple_unit_test_attributes(),
    doc = """
Rule to execute unit (XCTest) tests for a generic Apple platform.

Outputs:
  test_bundle: The xctest bundle being tested. This is returned here as a
      symlink to the bundle target in order to make it available for inspection
      when executing `bazel build` on this target.
  executable: The test script to be executed to run the tests.
""",
    fragments = [
        "apple",
        "objc",
    ],
    outputs = {
        "test_bundle": "%{name}.zip",
    },
    test = True,
)
