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
    `AppleDeferredTestLinkInfo` with the options of the link tool.
2.  `deferred_test_link_aspect`, applied by the test rule to its test bundle dependency, reads the
    bundle target's registered link action and captures its command line (as the action's `Args`,
    so it isn't flattened during analysis), environment and inputs.
3.  The test rule writes the command line to files (Bazel expands it, including any tree artifacts,
    when it runs those write actions), describes the rest in a JSON spec, adds the link inputs to
    the test's runfiles, and passes the spec to the test runner.
4.  The test runner, which must advertise `supports_deferred_test_linking`, calls its link tool
    (`//tools/deferred_test_linker` for `ios_xctestrun_runner`) after extracting the test bundle.
    The tool replays the link, places the binary (and the dylibs bundled based on it) into the
    bundle and codesigns it. The runner's temporary directory, which holds the extracted bundle, is
    deleted when the test finishes.
"""

DEFERRED_TEST_LINKING_FEATURE = "apple.defer_test_bundle_linking"

# The mnemonics that the Starlark C++/Objective-C linking implementations use for linking an
# executable or loadable bundle.
_LINK_MNEMONICS = ["ObjcLink", "CppLink"]

# Bazel resolves `DEVELOPER_DIR` and `SDKROOT` from these for any action that has them.
_XCODE_ENV_KEYS = ["APPLE_SDK_PLATFORM", "APPLE_SDK_VERSION_OVERRIDE", "XCODE_VERSION_OVERRIDE"]

AppleDeferredTestLinkInfo = provider(
    doc = """
Private provider propagated by test bundle targets that were built without linking their binary.
""",
    fields = {
        "options": """
A `dict` of options for `//tools/deferred_test_linker`, which documents them, added to its spec.
""",
    },
)

_DeferredTestLinkActionInfo = provider(
    doc = "Private provider with the link action that a test bundle target registered.",
    fields = {"action": "The link action."},
)

def _deferred_test_link_aspect_impl(target, _ctx):
    if AppleDeferredTestLinkInfo not in target:
        return []
    link_actions = [a for a in target.actions if a.mnemonic in _LINK_MNEMONICS]
    if len(link_actions) != 1 or len(link_actions[0].outputs.to_list()) != 1:
        fail("Internal error: expected a single link action with a single output for {}.".format(
            target.label,
        ))
    return [_DeferredTestLinkActionInfo(action = link_actions[0])]

deferred_test_link_aspect = aspect(
    doc = """
Captures the link action registered by a test bundle target that was built with
`apple.defer_test_bundle_linking`, so that the test rule can run it inside of the test action.
""",
    implementation = _deferred_test_link_aspect_impl,
)

def _should_defer_linking(*, features, platform_prerequisites, split_deps):
    """Returns whether the test bundle's binary should be linked in the test action.

    The feature is ignored, and the binary linked at build time as usual, for test bundles that it
    can't support. This allows it to be enabled for a whole build that also contains such tests.

    Args:
        features: The list of enabled features.
        platform_prerequisites: Struct containing information on the platform being targeted.
        split_deps: The `ctx.split_attr.deps` of the test bundle target, one entry per architecture.

    Returns:
        `True` if the binary should be linked in the test action.
    """
    return (
        DEFERRED_TEST_LINKING_FEATURE in features and
        # Only iOS simulator tests have a test runner that supports linking in the test action.
        str(platform_prerequisites.platform_type) == "ios" and
        not platform_prerequisites.platform.is_device and
        # The runner links a single binary rather than one per architecture plus a `lipo`.
        len(split_deps) == 1
    )

def _input_mapping(file):
    return "{}\t{}".format(file.path, file.short_path)

def _test_runner_inputs(*, ctx, runner_info, test_bundle_target):
    """Returns what the test runner needs to link the test bundle's binary.

    Args:
        ctx: The test rule context.
        runner_info: The `AppleTestRunnerInfo` provider of the test runner.
        test_bundle_target: The test bundle target.

    Returns:
        A `struct` with the fields:

        *   `execution_environment`: A `dict` of environment variables for the test action.
        *   `files`: A `list` of `File`s to add to the test's runfiles.
        *   `transitive_files`: A `list` of `depset`s of `File`s to add to the test's runfiles.
        *   `substitutions`: A `dict` of template substitutions for the test runner template. The
            values are empty when the test bundle was linked at build time.
    """
    if _DeferredTestLinkActionInfo not in test_bundle_target:
        return struct(
            execution_environment = {},
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

    action = test_bundle_target[_DeferredTestLinkActionInfo].action
    prefix = "{}.deferred_link".format(ctx.label.name)

    inputs_manifest = ctx.actions.declare_file(prefix + "_inputs.txt")
    inputs_args = ctx.actions.args()
    inputs_args.set_param_file_format("multiline")
    inputs_args.add_all(action.inputs, map_each = _input_mapping)
    ctx.actions.write(output = inputs_manifest, content = inputs_args)

    # Writing the `Args` expands them, including tree artifacts, at execution time; reading
    # `action.argv` would flatten every library of the command line during analysis.
    argv_files = []
    for index, args in enumerate(action.args):
        argv_files.append(ctx.actions.declare_file("{}_args_{}.txt".format(prefix, index)))
        ctx.actions.write(output = argv_files[-1], content = args)

    spec = ctx.actions.declare_file(prefix + ".json")
    ctx.actions.write(
        output = spec,
        content = json.encode_indent(test_bundle_target[AppleDeferredTestLinkInfo].options | {
            "argv_files": [f.short_path for f in argv_files],
            "env": action.env,
            "inputs_manifest": inputs_manifest.short_path,
            "output": action.outputs.to_list()[0].path,
        }),
    )

    return struct(
        execution_environment = {k: action.env[k] for k in _XCODE_ENV_KEYS if k in action.env},
        files = [inputs_manifest, spec] + argv_files,
        substitutions = {"test_bundle_link_spec": spec.short_path},
        transitive_files = [action.inputs],
    )

apple_test_deferred_linking = struct(
    should_defer_linking = _should_defer_linking,
    test_runner_inputs = _test_runner_inputs,
)
