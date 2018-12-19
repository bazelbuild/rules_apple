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

"""Genrule which provides Apple's Xcode environment."""

load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

def _compute_make_variables(
        genfiles_dir,
        label,
        resolved_srcs,
        files_to_build):
    resolved_srcs_list = resolved_srcs.to_list()
    files_to_build_list = files_to_build.to_list()
    variables = {
        "OUTS": " ".join([x.path for x in files_to_build_list]),
        "SRCS": " ".join([x.path for x in resolved_srcs_list]),
    }
    if len(resolved_srcs_list) == 1:
        variables["<"] = resolved_srcs_list[0].path
    if len(files_to_build_list) == 1:
        variables["@"] = files_to_build_list[0].path
        variables["@D"] = paths.dirname(variables["@"])
    else:
        variables["@D"] = genfiles_dir.path + "/" + label.package
    return variables

def _apple_genrule_impl(ctx):
    resolved_srcs = depset()
    if not ctx.outputs.outs:
        fail("apple_genrule must have one or more outputs", attr = "outs")
    files_to_build = depset(ctx.outputs.outs)

    if ctx.attr.executable and len(files_to_build.to_list()) > 1:
        fail(
            "if genrules produce executables, they are allowed only one output. " +
            "If you need the executable=1 argument, then you should split this " +
            "genrule into genrules producing single outputs",
            attr = "executable",
        )

    label_dict = {}
    for dep in ctx.attr.srcs:
        resolved_srcs = depset(transitive = [resolved_srcs, dep.files])
        label_dict[dep.label] = dep.files.to_list()

    resolved_inputs, argv, runfiles_manifests = ctx.resolve_command(
        command = ctx.attr.cmd,
        attribute = "cmd",
        expand_locations = True,
        make_variables = _compute_make_variables(
            ctx.genfiles_dir,
            ctx.label,
            depset(resolved_srcs.to_list()),
            files_to_build,
        ),
        tools = ctx.attr.tools,
        label_dict = label_dict,
        execution_requirements = {"requires-darwin": ""},
    )

    message = ctx.attr.message or "Executing apple_genrule"

    env = dict(ctx.configuration.default_shell_env)
    xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]
    env.update(apple_common.apple_host_system_env(xcode_config))

    _apple_action(
        ctx,
        inputs = resolved_srcs.to_list() + resolved_inputs,
        outputs = files_to_build.to_list(),
        env = env,
        command = argv,
        progress_message = "%s %s" % (message, ctx.label),
        mnemonic = "Genrule",
        input_manifests = runfiles_manifests,
        no_sandbox = ctx.attr.no_sandbox,
    )

    return [
        DefaultInfo(
            files = files_to_build,
            data_runfiles = ctx.runfiles(transitive_files = files_to_build),
        ),
    ]

_apple_genrule_inner = rule(
    implementation = _apple_genrule_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "outs": attr.output_list(mandatory = True),
        "cmd": attr.string(mandatory = True),
        "executable": attr.bool(default = False),
        "message": attr.string(),
        "no_sandbox": attr.bool(),
        "tools": attr.label_list(cfg = "host", allow_files = True),
        "_xcode_config": attr.label(default = configuration_field(
            fragment = "apple",
            name = "xcode_config_label",
        )),
    },
    output_to_genfiles = True,
    fragments = ["apple"],
)

def _apple_action(ctx, **kw):
    execution_requirements = kw.get("execution_requirements", {})
    execution_requirements["requires-darwin"] = ""

    no_sandbox = kw.pop("no_sandbox", False)
    if no_sandbox:
        execution_requirements["no-sandbox"] = "1"

    kw["execution_requirements"] = execution_requirements

    # Disable the lint warning because this can't be remapped, it needs
    # to be split into run and run_shell, which is pending work.
    # ...and disabling the linter doesn't work:
    # github.com/bazelbuild/buildtools/issues/458
    ctx.action(**kw)  # buildozer: disable=ctx-actions

def apple_genrule(
        name,
        cmd,
        executable = False,
        outs = [],
        **kwargs):
    """Genrule which provides Apple specific environment and make variables.

    This mirrors the native genrule except that it provides a different set of
    make variables. This rule will only run on a Mac.

    Example of use:

    load("@build_bazel_rules_apple//apple:apple_genrule.bzl", "apple_genrule")

    apple_genrule(
        name = "world",
        outs = ["hi"],
        cmd = "touch $(@)",
    )

    This rule also does location expansion, much like the native genrule.
    For example, $(location hi) may be used to refer to the output in the
    above example.

    The set of make variables that are supported for this rule:

    OUTS: The outs list. If you have only one output file, you can also use $@.
    SRCS: The srcs list (or more precisely, the pathnames of the files
          corresponding to labels in the srcs list). If you have only one source
          file, you can also use $<.
    <: srcs, if it's a single file.
    @: outs, if it's a single file.
    @D: The output directory. If there is only one filename in outs, this expands
        to the directory containing that file. If there are multiple filenames,
        this variable instead expands to the package's root directory in the
        genfiles tree, even if all the generated files belong to the same
        subdirectory.

    The following environment variables are added to the rule action:

    DEVELOPER_DIR: The base developer directory as defined on Apple architectures,
                   most commonly used in invoking Apple tools such as xcrun.

    Args:
      name: The name of the target.
      cmd: The command to run. Subject the variable substitution.
      executable: Boolean. Declare output to be executable. Setting this flag to
        1 means the output is an executable file and can be run using the run
        command. The genrule must produce exactly one output in this case.
      outs: A list of files generated by this rule. If the executable flag is
        set, outs must contain exactly one label.
      **kwargs: Extra args meant to just be the common rules for all rules
        (tags, etc.).
    """
    print(
        "DEPRECATED: rules_apple's apple_genrule is deprecated; please migrate" +
        " to the one provide by https://github.com/bazelbuild/apple_support," +
        " this one will go away in the next release. You should be able to" +
        "simply swap the load to be:" +
        "  load(\"@build_bazel_apple_support//rules:apple_genrule.bzl\", \"apple_genrule\")",
    )

    if executable:
        if len(outs) != 1:
            fail("apple_genrule, if executable, must have exactly one output")
        intermediate_out = outs[0] + "_nonexecutable"
        _apple_genrule_inner(
            name = name + "_nonexecutable",
            outs = [intermediate_out],
            cmd = cmd,
            **kwargs
        )

        # Remove anything from kwargs that might have a meaning that isn't wanted
        # on the genrule that does the copy. Generally, we are just trying to
        # keep things like testonly, visibility, etc.
        trimmed_kwargs = dict(kwargs)
        trimmed_kwargs.pop("srcs", None)
        trimmed_kwargs.pop("tools", None)
        trimmed_kwargs.pop("stamp", None)
        trimmed_kwargs.pop("no_sandbox", None)
        native.genrule(
            name = name,
            outs = outs,
            srcs = [intermediate_out],
            cmd = "cp $< $@",
            executable = True,
            **trimmed_kwargs
        )
    else:
        _apple_genrule_inner(
            name = name,
            outs = outs,
            cmd = cmd,
            **kwargs
        )
