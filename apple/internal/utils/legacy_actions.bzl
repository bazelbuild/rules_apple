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
load(
    "@bazel_skylib//lib:types.bzl",
    "types",
)

def _add_dicts(*dictionaries):
    """Adds a list of dictionaries into a single dictionary."""

    # If keys are repeated in multiple dictionaries, the latter one "wins".
    result = {}
    for d in dictionaries:
        result.update(d)

    return result

def _kwargs_for_apple_platform(ctx, additional_env = None, **kwargs):
    """Returns a modified dictionary with required arguments to run on Apple platforms."""
    processed_args = dict(kwargs)

    env_dicts = []
    original_env = processed_args.get("env")
    if original_env:
        env_dicts.append(original_env)
    if additional_env:
        env_dicts.append(additional_env)

    # This is where things differ from apple_support.
    platform = platform_support.platform(ctx)
    xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]
    env_dicts.append(apple_common.apple_host_system_env(xcode_config))
    env_dicts.append(apple_common.target_apple_env(xcode_config, platform))

    execution_requirement_dicts = []
    original_execution_requirements = processed_args.get("execution_requirements")
    if original_execution_requirements:
        execution_requirement_dicts.append(original_execution_requirements)

    # Add the execution requirements last to avoid clients overriding this value.
    execution_requirement_dicts.append(apple_support.action_required_execution_requirements())

    processed_args["env"] = _add_dicts(*env_dicts)
    processed_args["execution_requirements"] = _add_dicts(*execution_requirement_dicts)

    return processed_args

def _run(ctx, **kwargs):
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
      ctx: The Skylark context.
      **kwargs: Arguments to be passed into ctx.actions.run.
    """
    ctx.actions.run(**_kwargs_for_apple_platform(ctx, **kwargs))

def _run_shell(ctx, **kwargs):
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
      ctx: The Skylark context.
      **kwargs: Arguments to be passed into ctx.actions.run_shell.
    """

    # TODO(b/77637734) remove "workaround" once the bazel issue is resolved.
    # Bazel doesn't always get the shell right for a single string `commands`;
    # so work around that case by faking it as a list of strings that forces
    # the shell correctly.
    command = kwargs.get("command")
    if command and types.is_string(command):
        processed_args = dict(kwargs)
        processed_args["command"] = ["/bin/sh", "-c", command]
        kwargs = processed_args

    ctx.actions.run_shell(**_kwargs_for_apple_platform(ctx, **kwargs))

# Define the loadable module that lists the exported symbols in this file.
legacy_actions = struct(
    run = _run,
    run_shell = _run_shell,
)
