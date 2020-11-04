# Copyright 2018 The Bazel Authors. All rights reserved.
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

"""Actions that cover historical needs as things migrate."""

load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:platform_support.bzl",
    "platform_support",
)

def _add_dicts(*dictionaries):
    """Adds a list of dictionaries into a single dictionary."""

    # If keys are repeated in multiple dictionaries, the latter one "wins".
    result = {}
    for d in dictionaries:
        result.update(d)

    return result

def _kwargs_for_apple_platform(
        ctx,
        *,
        platform_prerequisites,
        **kwargs):
    """Returns a modified dictionary with required arguments to run on Apple platforms."""
    processed_args = dict(kwargs)

    env_dicts = []
    original_env = processed_args.get("env")
    if original_env:
        env_dicts.append(original_env)

    # This is where things differ from apple_support.

    # TODO(b/161370390): Eliminate need to make platform_prerequisites optional when all calls to
    # run and run_shell with a ctx argument are eliminated.
    if platform_prerequisites:
        platform = platform_prerequisites.platform
        xcode_config = platform_prerequisites.xcode_version_config
        action_execution_requirements = apple_support.action_required_execution_requirements(
            xcode_config = xcode_config,
        )
    else:
        platform = platform_support.platform(ctx)
        xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]
        action_execution_requirements = apple_support.action_required_execution_requirements(ctx)

    env_dicts.append(apple_common.apple_host_system_env(xcode_config))
    env_dicts.append(apple_common.target_apple_env(xcode_config, platform))

    execution_requirement_dicts = []
    original_execution_requirements = processed_args.get("execution_requirements")
    if original_execution_requirements:
        execution_requirement_dicts.append(original_execution_requirements)

    # Add the action execution requirements last to avoid clients overriding this value.
    execution_requirement_dicts.append(action_execution_requirements)

    processed_args["env"] = _add_dicts(*env_dicts)
    processed_args["execution_requirements"] = _add_dicts(*execution_requirement_dicts)

    return processed_args

def _run(
        ctx = None,
        *,
        actions = None,
        platform_prerequisites = None,
        **kwargs):
    """Executes a Darwin-only action with the necessary platform environment.

    Note: The env here is different than apple_support's run/run_shell in that uses
    ctx.fragments.apple.single_arch_platform, where here we look up the platform off some locally
    define attributes. The difference being apple_support's run/run_shell are used in context where
    all transitions have already happened; but this is meant to be used in bundling, where we are
    before any of those transitions, and so the rule must ensure the right platform/arches are being
    used itself.

    TODO(b/121134880): Once we have support Starlark defined rule transitions, we can migrate usages
    of this wrapper to apple_support's run/run_shell, as we'll add a rule transition so that the
    rule context gets the correct platform value configured.

    Args:
      ctx: The Starlark context. Deprecated.
      actions: The actions provider from ctx.actions.
      platform_prerequisites: Struct containing information on the platform being targeted.
      **kwargs: Arguments to be passed into ctx.actions.run.
    """

    # TODO(b/161370390): Eliminate need to make actions and platform_prerequisites optional when all
    # calls to this method with a ctx argument are eliminated.
    if not actions:
        actions = ctx.actions

    actions.run(**_kwargs_for_apple_platform(
        ctx = ctx,
        platform_prerequisites = platform_prerequisites,
        **kwargs
    ))

def _run_shell(
        ctx = None,
        *,
        actions = None,
        platform_prerequisites = None,
        **kwargs):
    """Executes a Darwin-only action with the necessary platform environment.

    Note: The env here is different than apple_support's run/run_shell in that uses
    ctx.fragments.apple.single_arch_platform, where here we look up the platform off some locally
    define attributes. The difference being apple_support's run/run_shell are used in context where
    all transitions have already happened; but this is meant to be used in bundling, where we are
    before any of those transitions, and so the rule must ensure the right platform/arches are being
    used itself.

    TODO(b/121134880): Once we have support Starlark defined rule transitions, we can migrate usages
    of this wrapper to apple_support's run/run_shell, as we'll add a rule transition so that the
    rule context gets the correct platform value configured.

    Args:
      ctx: The Starlark context. Deprecated.
      actions: The actions provider from ctx.actions.
      platform_prerequisites: Struct containing information on the platform being targeted.
      **kwargs: Arguments to be passed into ctx.actions.run_shell.
    """

    # TODO(b/161370390): Eliminate need to make actions and platform_prerequisites optional when all
    # calls to this method with a ctx argument are eliminated.
    if not actions:
        actions = ctx.actions

    actions.run_shell(**_kwargs_for_apple_platform(
        ctx = ctx,
        platform_prerequisites = platform_prerequisites,
        **kwargs
    ))

# Define the loadable module that lists the exported symbols in this file.
legacy_actions = struct(
    run = _run,
    run_shell = _run_shell,
)
