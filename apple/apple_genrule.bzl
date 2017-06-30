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

load("@build_bazel_rules_apple//apple:utils.bzl",
     "apple_action",
     "DARWIN_EXECUTION_REQUIREMENTS")


def _compute_make_variables(resolved_srcs, files_to_build):
  variables = {"SRCS": cmd_helper.join_paths(" ", resolved_srcs),
               "OUTS": cmd_helper.join_paths(" ", files_to_build)}
  if len(resolved_srcs) == 1:
    variables["<"] = list(resolved_srcs)[0].path
  if len(files_to_build) == 1:
    variables["@"] = list(files_to_build)[0].path
  return variables


def _apple_genrule_impl(ctx):
  resolved_srcs = set()
  if not ctx.outputs.outs:
    fail("apple_genrule must have one or more outputs", attr="outs")
  files_to_build = set(ctx.outputs.outs)

  if ctx.attr.executable and len(files_to_build) > 1:
    fail("if genrules produce executables, they are allowed only one output. "
          + "If you need the executable=1 argument, then you should split this "
          + "genrule into genrules producing single outputs",
         attr="executable")

  label_dict = {}
  for dep in ctx.attr.srcs:
    resolved_srcs += dep.files
    label_dict[dep.label] = dep.files

  resolved_inputs, argv, runfiles_manifests = ctx.resolve_command(
      command=ctx.attr.cmd,
      attribute="cmd",
      expand_locations=True,
      make_variables=_compute_make_variables(set(resolved_srcs), files_to_build),
      tools=ctx.attr.tools,
      label_dict=label_dict,
      execution_requirements=DARWIN_EXECUTION_REQUIREMENTS)

  message = ctx.attr.message or "Executing apple_genrule"

  env = ctx.configuration.default_shell_env
  env += ctx.fragments.apple.apple_host_system_env()

  apple_action(ctx,
               inputs=list(resolved_srcs) + resolved_inputs,
               outputs=list(files_to_build),
               env=env,
               command=argv,
               progress_message="%s %s" % (message, ctx),
               mnemonic="Genrule",
               input_manifests=runfiles_manifests)

  return struct(files=files_to_build,
                data_runfiles=ctx.runfiles(transitive_files=files_to_build))


_apple_genrule_inner = rule(
    implementation=_apple_genrule_impl,
    attrs={
        "srcs": attr.label_list(allow_files=True),
        "tools": attr.label_list(cfg="host", allow_files=True),
        "outs": attr.output_list(mandatory=True),
        "cmd": attr.string(mandatory=True),
        "message": attr.string(),
        "output_licenses": attr.license(),
        "executable": attr.bool(default=False),
        },
    output_to_genfiles = True,
    fragments=["apple"])


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

  The following environment variables are added to the rule action:

  DEVELOPER_DIR: The base developer directory as defined on Apple architectures,
                 most commonly used in invoking Apple tools such as xcrun.
  """
  if executable:
    if len(outs) != 1:
      fail("apple_genrule, if executable, must have exactly one output")
    intermediate_out = outs[0] + "_nonexecutable"
    _apple_genrule_inner(
        name = name + "_nonexecutable",
        outs = [intermediate_out],
        cmd = cmd,
        **kwargs)
    # Remove anything from kwargs that might have a meaning that isn't wanted
    # on the genrule that does the copy. Generally, we are just trying to
    # keep things like test_only, visibility, etc.
    trimmed_kwargs = dict(kwargs)
    trimmed_kwargs.pop("srcs", None)
    trimmed_kwargs.pop("tools", None)
    trimmed_kwargs.pop("stamp", None)
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
        **kwargs)

