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
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "AppleExtraOutputsInfo",
    "AppleTestInfo",
    "AppleTestRunnerInfo",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
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

# Key to extract all values for inserting into the binary at load time.
INSERT_LIBRARIES_KEY = "DYLD_INSERT_LIBRARIES"

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

    if hasattr(ctx.rule.attr, "test_host") and ctx.rule.attr.test_host:
        coverage_files.append(ctx.rule.attr.test_host[CoverageFilesInfo].coverage_files)
        transitive_binaries_sets.append(ctx.rule.attr.test_host[CoverageFilesInfo].covered_binaries)

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
    attr_aspects = ["deps", "frameworks", "test_host"],
    doc = """
This aspect walks the dependency graph through the dependency graph and collects all the sources and
headers that are depended upon transitively. These files are needed to calculate test coverage on a
test run.

This aspect propagates a `CoverageFilesInfo` provider.
""",
    implementation = _coverage_files_aspect_impl,
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

def _get_coverage_execution_environment(_ctx, covered_binaries):
    """Returns environment variables required for test coverage support."""
    covered_binary_paths = [f.short_path for f in covered_binaries.to_list()]

    return {
        "APPLE_COVERAGE": "1",
        "TEST_BINARIES_FOR_LLVM_COV": ";".join(covered_binary_paths),
    }

def _apple_test_rule_impl(ctx, test_type):
    """Implementation for the Apple test rules."""
    runner = ctx.attr.runner[AppleTestRunnerInfo]
    execution_requirements = getattr(runner, "execution_requirements", {})

    test_bundle_target = ctx.attr.deps[0]

    test_bundle = test_bundle_target[AppleTestInfo].test_bundle

    # Environment variables to be set as the %(test_env)s substitution, which includes the
    # --test_env and env attribute values, but not the execution environment variables.
    test_environment = _get_simulator_test_environment(ctx, runner)

    # Environment variables for the Bazel test action itself.
    execution_environment = dict(getattr(runner, "execution_environment", {}))

    direct_runfiles = []
    transitive_runfiles = []

    test_host_archive = test_bundle_target[AppleTestInfo].test_host
    if test_host_archive:
        direct_runfiles.append(test_host_archive)

    direct_runfiles.append(test_bundle)

    if ctx.configuration.coverage_enabled:
        covered_binaries = test_bundle_target[CoverageFilesInfo].covered_binaries
        execution_environment = dicts.add(
            execution_environment,
            _get_coverage_execution_environment(
                ctx,
                covered_binaries,
            ),
        )

        transitive_runfiles.append(covered_binaries)
        transitive_runfiles.append(test_bundle_target[CoverageFilesInfo].coverage_files)

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
        is_executable = True,
    )

    # Add required data into the runfiles to make it available during test
    # execution.
    for data_dep in ctx.attr.data:
        transitive_runfiles.append(data_dep.files)

    return [
        # Repropagate the AppleBundleInfo and AppleTestInfo providers from the test bundle so that
        # clients interacting with the test targets themselves can access the bundle's structure.
        test_bundle_target[AppleBundleInfo],
        test_bundle_target[AppleTestInfo],
        test_bundle_target[OutputGroupInfo],
        coverage_common.instrumented_files_info(
            ctx,
            dependency_attributes = ["deps"],
        ),
        testing.ExecutionInfo(execution_requirements),
        testing.TestEnvironment(execution_environment),
        DefaultInfo(
            executable = executable,
            files = depset(
                [executable, test_bundle],
                transitive = [test_bundle_target[AppleExtraOutputsInfo].files],
            ),
            runfiles = ctx.runfiles(
                files = direct_runfiles,
                transitive_files = depset(transitive = transitive_runfiles),
            )
                .merge(ctx.attr.runner.default_runfiles)
                .merge(ctx.attr.runner.data_runfiles),
        ),
    ]

apple_test_rule_support = struct(
    apple_test_rule_impl = _apple_test_rule_impl,
)

def _get_simulator_test_environment(ctx, runner):
    """Returns the test environment for the current process running in the simulator

    All DYLD_INSERT_LIBRARIES key-value pairs are merged from the command-line, test
    rule and test runner.
    """

    # Get mutable copies of the different test environment dicts.
    command_line_test_env = dicts.add(ctx.configuration.test_env)
    rule_test_env = dicts.add(ctx.attr.env)
    runner_test_env = dicts.add(getattr(runner, "test_environment", {}))

    # Combine all DYLD_INSERT_LIBRARIES values in a list ordered as per the source:
    # 1. Command line test-env
    # 2. Test Rule test-env
    # 3. Test Runner test-env
    insert_libraries_values = []
    command_line_values = command_line_test_env.pop(INSERT_LIBRARIES_KEY, default = None)
    if command_line_values:
        insert_libraries_values.append(command_line_values)
    rule_values = rule_test_env.pop(INSERT_LIBRARIES_KEY, default = None)
    if rule_values:
        insert_libraries_values.append(rule_values)
    runner_values = runner_test_env.pop(INSERT_LIBRARIES_KEY, default = None)
    if runner_values:
        insert_libraries_values.append(runner_values)

    # Combine all DYLD_INSERT_LIBRARIES values in a single string separated by ":" and then save it
    # to a dict to be combined with other test_env pairs.
    insert_libraries_values_joined = ":".join(insert_libraries_values)
    test_env_dyld_insert_pairs = {}
    if insert_libraries_values_joined:
        test_env_dyld_insert_pairs = {INSERT_LIBRARIES_KEY: insert_libraries_values_joined}

    # Combine all the environments with the DYLD_INSERT_LIBRARIES values merged together.
    return dicts.add(
        command_line_test_env,
        rule_test_env,
        runner_test_env,
        test_env_dyld_insert_pairs,
    )
