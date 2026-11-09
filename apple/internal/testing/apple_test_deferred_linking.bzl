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

"""Support for linking a test bundle's binary inside of the test action.

When the `apple.defer_test_bundle_linking` feature is enabled, the test bundle target still
registers its link action, but nothing depends on that action's outputs, so Bazel never runs it and
the (potentially very large, statically linked) binary is never written to the output tree or the
remote cache. Instead:

1.  The test bundle is assembled without its executable and advertises
    `AppleDeferredTestLinkInfo`.
2.  `deferred_test_link_aspect`, applied by the test rule to its test bundle dependency, reads the
    bundle target's registered link action and captures its command line, environment and inputs.
3.  The test rule writes that information to a JSON spec, adds the link inputs to the test's
    runfiles, and passes the spec and the `deferred_test_linker` tool to the test runner.
4.  The test runner calls the tool after extracting the test bundle; the tool replays the link,
    places the binary into the bundle and codesigns it. The runner's temporary directory, which
    holds the extracted bundle, is deleted when the test finishes.
"""

load(
    "//apple/internal/utils:clang_rt_dylibs.bzl",
    "clang_rt_dylibs",
)
load(
    "//apple/internal/utils:main_thread_checker_dylibs.bzl",
    "main_thread_checker_dylibs",
)

DEFERRED_TEST_LINKING_FEATURE = "apple.defer_test_bundle_linking"

# The mnemonics that the Starlark C++/Objective-C linking implementations use for linking an
# executable or loadable bundle.
_LINK_MNEMONICS = ["ObjcLink", "CppLink"]

AppleDeferredTestLinkInfo = provider(
    doc = """
Private provider propagated by test bundle targets that were built without linking their binary.
""",
    fields = {
        "codesign": "Whether the bundle should be ad-hoc codesigned after linking the binary.",
        "codesignopts": "A list of extra options to pass to `codesign` for the bundle.",
        "executable_name": "The name of the binary inside of the test bundle.",
    },
)

_DeferredTestLinkActionInfo = provider(
    doc = "Private provider with the link action that a test bundle target registered.",
    fields = {
        "argv": "The list of arguments of the link action.",
        "codesign": "See `AppleDeferredTestLinkInfo.codesign`.",
        "codesignopts": "See `AppleDeferredTestLinkInfo.codesignopts`.",
        "env": "The environment variables of the link action.",
        "executable_name": "See `AppleDeferredTestLinkInfo.executable_name`.",
        "inputs": "A `depset` of `File`s that are inputs of the link action.",
        "outputs": "A list of execution root relative paths of the link action's outputs.",
    },
)

def _deferred_test_link_aspect_impl(target, _ctx):
    if AppleDeferredTestLinkInfo not in target:
        return []

    link_info = target[AppleDeferredTestLinkInfo]
    link_actions = [a for a in target.actions if a.mnemonic in _LINK_MNEMONICS]
    if len(link_actions) != 1:
        fail((
            "Internal error: expected exactly one link action for {label} with " +
            "'{feature}' enabled, found {count}."
        ).format(
            count = len(link_actions),
            feature = DEFERRED_TEST_LINKING_FEATURE,
            label = target.label,
        ))
    link_action = link_actions[0]
    if not link_action.argv:
        fail("Internal error: the link action for {} has no command line.".format(target.label))

    return [
        _DeferredTestLinkActionInfo(
            argv = link_action.argv,
            codesign = link_info.codesign,
            codesignopts = link_info.codesignopts,
            env = link_action.env,
            executable_name = link_info.executable_name,
            inputs = link_action.inputs,
            outputs = [f.path for f in link_action.outputs.to_list()],
        ),
    ]

deferred_test_link_aspect = aspect(
    doc = """
Captures the link action registered by a test bundle target that was built with
`apple.defer_test_bundle_linking`, so that the test rule can run it inside of the test action.
""",
    implementation = _deferred_test_link_aspect_impl,
)

def _validate_bundle(
        *,
        features,
        link_outputs,
        platform_prerequisites):
    """Fails if the test bundle can't be built with deferred linking."""
    if platform_prerequisites.platform.is_device:
        fail("'{}' is only supported for tests that target a simulator.".format(
            DEFERRED_TEST_LINKING_FEATURE,
        ))
    if len(link_outputs) != 1:
        fail((
            "'{feature}' only supports test bundles built for a single architecture, but " +
            "{count} were requested ({archs})."
        ).format(
            archs = ", ".join([o.architecture for o in link_outputs]),
            count = len(link_outputs),
            feature = DEFERRED_TEST_LINKING_FEATURE,
        ))

    # These features scan the linked binary at build time to decide which dylibs to bundle.
    if clang_rt_dylibs.should_package_clang_runtime(features = features):
        fail("'{}' is not supported together with sanitizer features.".format(
            DEFERRED_TEST_LINKING_FEATURE,
        ))
    if main_thread_checker_dylibs.should_package_main_thread_checker_dylib(features = features):
        fail("'{}' is not supported together with 'apple.include_main_thread_checker'.".format(
            DEFERRED_TEST_LINKING_FEATURE,
        ))

def _is_enabled(*, features):
    return DEFERRED_TEST_LINKING_FEATURE in features

def _bundle_skips_signing_features(*, features):
    """Returns `features` with bundle signing disabled.

    The bundle can't be signed before its binary exists, so signing is skipped at build time and
    the test runner signs the bundle after linking the binary.
    """
    return features + ["apple.skip_codesign_simulator_bundles"]

def _input_mapping(file):
    return "{}\t{}".format(file.path, file.short_path)

def _test_runner_inputs(*, ctx, runner_info, test_bundle_target):
    """Returns the runfiles and substitutions the test runner needs to link the test bundle.

    Args:
        ctx: The test rule context.
        runner_info: The `AppleTestRunnerInfo` provider of the test runner.
        test_bundle_target: The test bundle target.

    Returns:
        A `struct` with the fields:

        *   `files`: A `list` of `File`s to add to the test's runfiles.
        *   `transitive_files`: A `list` of `depset`s of `File`s to add to the test's runfiles.
        *   `runfiles`: A `list` of `runfiles` objects to merge into the test's runfiles.
        *   `substitutions`: A `dict` of template substitutions for the test runner template. The
            values are empty when the test bundle was linked at build time.
    """
    if _DeferredTestLinkActionInfo not in test_bundle_target:
        return struct(
            files = [],
            runfiles = [],
            substitutions = {
                "test_bundle_link_spec": "",
                "test_bundle_link_tool": "",
            },
            transitive_files = [],
        )

    if not getattr(runner_info, "supports_deferred_test_linking", False):
        fail((
            "The '{runner}' test runner does not support the '{feature}' feature. Use a runner " +
            "that supports it, such as `ios_xctestrun_runner`."
        ).format(
            feature = DEFERRED_TEST_LINKING_FEATURE,
            runner = ctx.attr.runner.label,
        ))

    link_action_info = test_bundle_target[_DeferredTestLinkActionInfo]

    inputs_manifest = ctx.actions.declare_file(
        "{}.deferred_link_inputs.txt".format(ctx.label.name),
    )
    inputs_args = ctx.actions.args()
    inputs_args.set_param_file_format("multiline")
    inputs_args.add_all(link_action_info.inputs, map_each = _input_mapping)
    ctx.actions.write(output = inputs_manifest, content = inputs_args)

    spec = ctx.actions.declare_file("{}.deferred_link.json".format(ctx.label.name))
    ctx.actions.write(
        output = spec,
        content = json.encode_indent({
            "argv": link_action_info.argv,
            "codesign": link_action_info.codesign,
            "codesignopts": link_action_info.codesignopts,
            "env": link_action_info.env,
            "executable_name": link_action_info.executable_name,
            "inputs_manifest": inputs_manifest.short_path,
            "outputs": link_action_info.outputs,
        }),
    )

    linker = ctx.attr._deferred_test_linker
    return struct(
        files = [inputs_manifest, spec],
        runfiles = [linker[DefaultInfo].default_runfiles],
        substitutions = {
            "test_bundle_link_spec": spec.short_path,
            "test_bundle_link_tool": linker[DefaultInfo].files_to_run.executable.short_path,
        },
        transitive_files = [link_action_info.inputs],
    )

apple_test_deferred_linking = struct(
    bundle_skips_signing_features = _bundle_skips_signing_features,
    is_enabled = _is_enabled,
    test_runner_inputs = _test_runner_inputs,
    validate_bundle = _validate_bundle,
)
