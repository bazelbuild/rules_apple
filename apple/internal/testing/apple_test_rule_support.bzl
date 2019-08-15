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

"""Helper methods for implementing test rules."""

load(
    "@build_bazel_rules_apple//apple/internal:outputs.bzl",
    "outputs",
)
load(
    "@build_bazel_rules_apple//apple/internal/testing:apple_test_bundle_support.bzl",
    "apple_test_bundle_support",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "SwiftInfo",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)
load(
    "@bazel_skylib//lib:types.bzl",
    "types",
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

AppleTestRunnerInfo = provider(
    doc = """
Provider that runner targets must propagate.

In addition to the fields, all the runfiles that the runner target declares will be added to the
test rules runfiles.
""",
    fields = {
        "execution_requirements": """
Optional dictionary that represents the specific hardware requirements for this test.
""",
        "execution_environment": """
Optional dictionary with the environment variables that are to be set in the test action, and are
not propagated into the XCTest invocation. These values will _not_ be added into the %(test_env)s
substitution, but will be set in the test action.
""",
        "test_environment": """
Optional dictionary with the environment variables that are to be propagated into the XCTest
invocation. These values will be included in the %(test_env)s substitution and will _not_ be set in
the test action.
""",
        "test_runner_template": """
Required template file that contains the specific mechanism with which the tests will be run. The
apple_ui_test and apple_unit_test rules will substitute the following values:
    * %(test_host_path)s:   Path to the app being tested.
    * %(test_bundle_path)s: Path to the test bundle that contains the tests.
    * %(test_env)s:         Environment variables for the XCTest invocation (e.g FOO=BAR,BAZ=QUX).
    * %(test_type)s:        The test type, whether it is unit or UI.
""",
    },
)

CoverageFilesInfo = provider(
    doc = """
Provider used by the `coverage_files_aspect` aspect to propagate the
transitive closure of sources and binaries that a test depends on. These files
are then made available during the coverage action as they are required by the
coverage insfrastructure. The sources are provided in the `coverage_files` field,
and the binaries in the `covered_binaries` field. This provider is only available
if when coverage collecting is enabled.
""",
    fields = {
        "coverage_files": "`depset` of files required to be present during a coverage run.",
        "covered_binaries": """
`depset` of files representing the binaries that are being tested under a coverage run.
""",
    },
)

def _coverage_files_aspect_impl(target, ctx):
    """Implementation for the `coverage_files_aspect` aspect."""

    # Skip collecting files if coverage is not enabled.
    if not ctx.configuration.coverage_enabled:
        return []

    coverage_files = []

    # Collect this target's coverage files.
    for attr in ["srcs", "hdrs", "non_arc_srcs"]:
        for files in [x.files for x in getattr(ctx.rule.attr, attr, [])]:
            coverage_files.append(files)

    # Collect the binaries themselves from the various bundles involved in the test. These will be
    # passed through the test environment so that `llvm-cov` can access the coverage mapping data
    # embedded in them.
    direct_binaries = []
    transitive_binaries_sets = []
    if AppleBundleInfo in target:
        direct_binaries.append(target[AppleBundleInfo].binary)

    # Collect dependencies coverage files.
    for dep in getattr(ctx.rule.attr, "deps", []):
        coverage_files.append(dep[CoverageFilesInfo].coverage_files)

    for fmwk in getattr(ctx.rule.attr, "frameworks", []):
        coverage_files.append(fmwk[CoverageFilesInfo].coverage_files)
        transitive_binaries_sets.append(fmwk[CoverageFilesInfo].covered_binaries)

    return [
        CoverageFilesInfo(
            coverage_files = depset(transitive = coverage_files),
            covered_binaries = depset(
                direct = direct_binaries,
                transitive = transitive_binaries_sets,
            ),
        ),
    ]

coverage_files_aspect = aspect(
    attr_aspects = ["deps", "frameworks"],
    doc = """
This aspect walks the dependency graph through the `deps` and `frameworks` attributes and collects
all the sources and headers that are depended upon transitively. These files are needed to calculate
test coverage on a test run.

This aspect propagates a `CoverageFilesInfo` provider.
""",
    implementation = _coverage_files_aspect_impl,
)

def _collect_files(rule_attr, attr_name):
    """Collects files from attr_name (if present) into a depset."""

    attr_val = getattr(rule_attr, attr_name, None)
    if not attr_val:
        return depset()

    attr_val_as_list = attr_val if types.is_list(attr_val) else [attr_val]
    return depset(transitive = [f.files for f in attr_val_as_list])

def _test_info_aspect_impl(target, ctx):
    """See `test_info_aspect` for full documentation."""
    includes = []
    module_maps = []
    swift_modules = []

    # Not all deps (i.e. source files) will have an AppleTestInfo provider. If the
    # dep doesn't, just filter it out.
    test_infos = [
        x[AppleTestInfo]
        for x in getattr(ctx.rule.attr, "deps", [])
        if AppleTestInfo in x
    ]

    # Collect transitive information from deps.
    for test_info in test_infos:
        includes.append(test_info.includes)
        module_maps.append(test_info.module_maps)
        swift_modules.append(test_info.swift_modules)

    if apple_common.Objc in target:
        objc_provider = target[apple_common.Objc]
        includes.append(objc_provider.include)

        # Module maps should only be used by Swift targets.
        if SwiftInfo in target:
            module_maps.append(objc_provider.module_map)

    if (SwiftInfo in target and
        hasattr(target[SwiftInfo], "transitive_swiftmodules")):
        swift_modules.append(target[SwiftInfo].transitive_swiftmodules)

    # Collect sources from the current target and add any relevant transitive
    # information. Note that we do not propagate sources transitively as we
    # intentionally only show test sources from the test's first-level of
    # dependencies instead of all transitive dependencies.
    non_arc_sources = _collect_files(ctx.rule.attr, "non_arc_srcs")
    sources = _collect_files(ctx.rule.attr, "srcs")

    return [AppleTestInfo(
        includes = depset(transitive = includes),
        module_maps = depset(transitive = module_maps),
        non_arc_sources = non_arc_sources,
        sources = sources,
        swift_modules = depset(transitive = swift_modules),
    )]

test_info_aspect = aspect(
    attr_aspects = [
        "deps",
    ],
    doc = """
This aspect walks the dependency graph through the `deps` attribute and collects sources, transitive
includes, transitive module maps, and transitive Swift modules.

This aspect propagates an `AppleTestInfo` provider.
""",
    implementation = _test_info_aspect_impl,
)

def _get_template_substitutions(test_type, test_bundle, test_environment, test_host = None):
    """Dictionary with the substitutions to be applied to the template script."""
    subs = {}

    if test_host:
        subs["test_host_path"] = test_host.short_path
    else:
        subs["test_host_path"] = ""
    subs["test_bundle_path"] = test_bundle.short_path
    subs["test_type"] = test_type.upper()
    subs["test_env"] = ",".join([k + "=" + v for (k, v) in test_environment.items()])

    return {"%(" + k + ")s": subs[k] for k in subs}

def _get_coverage_execution_environment(ctx, covered_binaries):
    """Returns environment variables required for test coverage support."""
    gcov_files = ctx.attr._gcov.files.to_list()
    covered_binary_paths = [f.short_path for f in covered_binaries.to_list()]

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

def _apple_test_info_provider(deps):
    """Returns an AppleTestInfo provider by collecting the relevant data from dependencies."""
    dep_labels = []
    swift_infos = []

    transitive_includes = []
    transitive_module_maps = []
    transitive_non_arc_sources = []
    transitive_sources = []
    transitive_swift_modules = []

    for dep in deps:
        dep_labels.append(str(dep.label))

        if SwiftInfo in dep:
            swift_infos.append(dep[SwiftInfo])

        test_info = dep[AppleTestInfo]

        transitive_includes.append(test_info.includes)
        transitive_module_maps.append(test_info.module_maps)
        transitive_non_arc_sources.append(test_info.non_arc_sources)
        transitive_sources.append(test_info.sources)
        transitive_swift_modules.append(test_info.swift_modules)

    # Set module_name only for test targets with a single Swift dependency.
    # This is not used if there are multiple Swift dependencies, as it will
    # not be possible to reduce them into a single Swift module and picking
    # an arbitrary one is fragile.
    module_name = None
    if len(swift_infos) == 1:
        module_name = getattr(swift_infos[0], "module_name", None)

    return AppleTestInfo(
        deps = depset(dep_labels),
        includes = depset(transitive = transitive_includes),
        module_maps = depset(transitive = transitive_module_maps),
        module_name = module_name,
        non_arc_sources = depset(transitive = transitive_non_arc_sources),
        sources = depset(transitive = transitive_sources),
        swift_modules = depset(transitive = transitive_swift_modules),
    )

def _apple_test_rule_impl(ctx, test_type, extra_output_files = None):
    """Implementation for the Apple test rules."""
    runner = ctx.attr.runner[AppleTestRunnerInfo]
    execution_requirements = getattr(runner, "execution_requirements", {})

    # Environment variables to be set as the %(test_env)s substitution, which includes the
    # --test_env and env attribute values, but not the execution environment variables.
    test_environment = dicts.add(
        ctx.configuration.test_env,
        ctx.attr.env,
        getattr(runner, "test_environment", {}),
    )

    # Environment variables for the Bazel test action itself.
    execution_environment = dict(getattr(runner, "execution_environment", {}))

    direct_runfiles = []
    transitive_runfiles = []

    direct_outputs = []
    transitive_outputs = []
    if extra_output_files:
        transitive_outputs.append(extra_output_files)

    test_host = ctx.attr.test_host
    test_host_archive = None
    if test_host:
        test_host_archive = test_host[AppleBundleInfo].archive
        direct_runfiles.append(test_host_archive)

    test_bundle = outputs.archive(ctx)
    direct_runfiles.append(test_bundle)

    if ctx.configuration.coverage_enabled:
        transitive_covered_binaries = []
        transitive_coverage_files = []

        for dep in ctx.attr.deps:
            transitive_covered_binaries.append(dep[CoverageFilesInfo].covered_binaries)
            transitive_coverage_files.append(dep[CoverageFilesInfo].coverage_files)

        if test_host:
            transitive_covered_binaries.append(test_host[CoverageFilesInfo].covered_binaries)
            transitive_coverage_files.append(test_host[CoverageFilesInfo].coverage_files)

        covered_binaries = depset([outputs.binary(ctx)], transitive = transitive_covered_binaries)
        execution_environment = dicts.add(
            execution_environment,
            _get_coverage_execution_environment(
                ctx,
                covered_binaries,
            ),
        )

        transitive_runfiles.append(covered_binaries)
        transitive_runfiles.extend(transitive_coverage_files)

        transitive_runfiles.append(ctx.attr._gcov.files)
        transitive_runfiles.append(ctx.attr._mcov.files)
        transitive_runfiles.append(ctx.attr._apple_coverage_support.files)

    executable = ctx.actions.declare_file("%s" % ctx.label.name)
    ctx.actions.expand_template(
        template = runner.test_runner_template,
        output = executable,
        substitutions = _get_template_substitutions(
            test_type,
            test_bundle,
            test_environment,
            test_host = test_host_archive,
        ),
    )
    direct_outputs.append(executable)

    # Add required data into the runfiles to make it available during test
    # execution.
    for data_dep in ctx.attr.data:
        transitive_runfiles.append(data_dep.files)

    return [
        _apple_test_info_provider(ctx.attr.deps),
        coverage_common.instrumented_files_info(
            ctx,
            dependency_attributes = ["deps", "test_host"],
        ),
        testing.ExecutionInfo(execution_requirements),
        testing.TestEnvironment(execution_environment),
        DefaultInfo(
            executable = executable,
            files = depset(direct_outputs, transitive = transitive_outputs),
            runfiles = ctx.runfiles(
                files = direct_runfiles,
                transitive_files = depset(transitive = transitive_runfiles),
            )
                .merge(ctx.attr.runner.default_runfiles)
                .merge(ctx.attr.runner.data_runfiles),
        ),
    ]

def _apple_test_impl(ctx, test_type, extra_providers = []):
    """Common implementation for the Apple bundle and test rules."""
    bundle_providers, bundle_outputs = apple_test_bundle_support.apple_test_bundle_impl(ctx)
    test_providers = _apple_test_rule_impl(
        ctx,
        test_type,
        extra_output_files = bundle_outputs,
    )
    return bundle_providers + test_providers + extra_providers

apple_test_rule_support = struct(
    apple_test_impl = _apple_test_impl,
)
