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
    bundle target's registered link action and captures its command line (as the action's `Args`,
    so it isn't flattened during analysis), environment and inputs.
3.  The test rule writes the command line to files (Bazel expands it, including any tree artifacts,
    when it runs those write actions), describes the rest in a JSON spec, adds the link inputs to
    the test's runfiles, and passes the spec to the test runner.
4.  The test runner, which must advertise `supports_deferred_test_linking`, calls its link tool
    (`//tools/deferred_test_linker` for `ios_xctestrun_runner`) after extracting the test bundle.
    The tool replays the link, places the binary (and any Swift dylibs it needs) into the bundle
    and codesigns it. The runner's temporary directory, which
    holds the extracted bundle, is deleted when the test finishes.
"""

load(
    "//apple/internal/partials:swift_dylibs.bzl",
    "binary_needs_swift_dylibs_scan",
)
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
        "swift_stdlib_platform": """
The platform name to copy the Swift dylibs that the linked binary needs for, or `None` if the
binary doesn't need to be scanned for them.
""",
    },
)

_DeferredTestLinkActionInfo = provider(
    doc = "Private provider with the link action that a test bundle target registered.",
    fields = {
        "args": """
The list of `Args` objects of the link action. Their concatenated contents are its command line,
starting with the linker.
""",
        "codesign": "See `AppleDeferredTestLinkInfo.codesign`.",
        "codesignopts": "See `AppleDeferredTestLinkInfo.codesignopts`.",
        "env": "The environment variables of the link action.",
        "executable_name": "See `AppleDeferredTestLinkInfo.executable_name`.",
        "inputs": "A `depset` of `File`s that are inputs of the link action.",
        "outputs": "A list of execution root relative paths of the link action's outputs.",
        "swift_stdlib_platform": "See `AppleDeferredTestLinkInfo.swift_stdlib_platform`.",
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

    # `link_action.argv` would flatten the whole command line, including every library, during
    # analysis; the `Args` are only expanded when the test rule's write actions run.
    if not link_action.args:
        fail("Internal error: the link action for {} has no `Args`.".format(target.label))

    return [
        _DeferredTestLinkActionInfo(
            args = link_action.args,
            codesign = link_info.codesign,
            codesignopts = link_info.codesignopts,
            env = link_action.env,
            executable_name = link_info.executable_name,
            inputs = link_action.inputs,
            outputs = [f.path for f in link_action.outputs.to_list()],
            swift_stdlib_platform = link_info.swift_stdlib_platform,
        ),
    ]

deferred_test_link_aspect = aspect(
    doc = """
Captures the link action registered by a test bundle target that was built with
`apple.defer_test_bundle_linking`, so that the test rule can run it inside of the test action.
""",
    implementation = _deferred_test_link_aspect_impl,
)

def _should_defer_linking(*, codesign_inputs, features, platform_prerequisites, split_deps):
    """Returns whether the test bundle's binary should be linked in the test action.

    The feature is ignored, and the binary linked at build time as usual, for test bundles that it
    can't support. This allows it to be enabled for a whole build that also contains such tests.

    Args:
        codesign_inputs: The `codesign_inputs` files of the test bundle target.
        features: The list of enabled features.
        platform_prerequisites: Struct containing information on the platform being targeted.
        split_deps: The `ctx.split_attr.deps` of the test bundle target, one entry per architecture.

    Returns:
        `True` if the binary should be linked in the test action.
    """
    if DEFERRED_TEST_LINKING_FEATURE not in features:
        return False

    # Only iOS simulator tests have a test runner that supports linking in the test action.
    if str(platform_prerequisites.platform_type) != "ios":
        return False
    if platform_prerequisites.platform.is_device:
        return False

    # The runner links a single binary rather than one per architecture plus a `lipo`.
    if len(split_deps) != 1:
        return False

    # These features scan the linked binary at build time to decide which dylibs to bundle.
    if clang_rt_dylibs.should_package_clang_runtime(features = features):
        return False
    if main_thread_checker_dylibs.should_package_main_thread_checker_dylib(features = features):
        return False

    # `codesignopts` may refer to these files by their execution root relative paths, which don't
    # exist where the test runner signs the bundle. (The test macros don't forward these
    # attributes today, but the bundle rules accept them.)
    if codesign_inputs:
        return False

    return True

def _validate_link_outputs(*, label, link_outputs):
    """Fails if the link action doesn't produce exactly one binary, see `should_defer_linking`."""
    if len(link_outputs) != 1:
        fail((
            "Internal error: expected a single architecture for {label} with '{feature}' " +
            "enabled, found {count} ({archs})."
        ).format(
            archs = ", ".join([o.architecture for o in link_outputs]),
            count = len(link_outputs),
            feature = DEFERRED_TEST_LINKING_FEATURE,
            label = label,
        ))

def _swift_stdlib_platform(*, platform_prerequisites):
    """Returns the `swift_stdlib_platform` for `AppleDeferredTestLinkInfo`."""
    if not binary_needs_swift_dylibs_scan(platform_prerequisites = platform_prerequisites):
        return None
    return platform_prerequisites.platform.name_in_plist.lower()

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
        *   `substitutions`: A `dict` of template substitutions for the test runner template. The
            values are empty when the test bundle was linked at build time.
    """
    if _DeferredTestLinkActionInfo not in test_bundle_target:
        return struct(
            files = [],
            substitutions = {"test_bundle_link_spec": ""},
            transitive_files = [],
        )

    if not getattr(runner_info, "supports_deferred_test_linking", False):
        fail((
            "The '{runner}' test runner does not support the '{feature}' feature. Use a runner " +
            "that supports it, such as `ios_xctestrun_runner`, or disable the feature for this " +
            "test with `features = [\"-{feature}\"]`. Tests with several `runners` share one " +
            "test bundle, so the feature has to be disabled for all of them."
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

    argv_files = []
    for index, args in enumerate(link_action_info.args):
        argv_file = ctx.actions.declare_file(
            "{}.deferred_link_args_{}.txt".format(ctx.label.name, index),
        )
        ctx.actions.write(output = argv_file, content = args)
        argv_files.append(argv_file)

    spec = ctx.actions.declare_file("{}.deferred_link.json".format(ctx.label.name))
    ctx.actions.write(
        output = spec,
        content = json.encode_indent({
            "argv_files": [f.short_path for f in argv_files],
            "codesign": link_action_info.codesign,
            "codesignopts": link_action_info.codesignopts,
            "env": link_action_info.env,
            "executable_name": link_action_info.executable_name,
            "inputs_manifest": inputs_manifest.short_path,
            "outputs": link_action_info.outputs,
            "swift_stdlib_platform": link_action_info.swift_stdlib_platform,
        }),
    )

    return struct(
        files = [inputs_manifest, spec] + argv_files,
        substitutions = {"test_bundle_link_spec": spec.short_path},
        transitive_files = [link_action_info.inputs],
    )

apple_test_deferred_linking = struct(
    bundle_skips_signing_features = _bundle_skips_signing_features,
    should_defer_linking = _should_defer_linking,
    swift_stdlib_platform = _swift_stdlib_platform,
    test_runner_inputs = _test_runner_inputs,
    validate_link_outputs = _validate_link_outputs,
)
