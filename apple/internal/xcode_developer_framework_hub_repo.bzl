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

"""Create the user reference-able repo that points to per-Xcode framework targets."""

_XCODE_VERSION_FLAG = "@bazel_tools//tools/osx:xcode_version_flag_exact"

def _sanitize(v):
    return v.replace(".", "_").replace("-", "_")

def _xcode_config_settings(versions):
    parts = []
    for version in versions:
        name = "xcode_{}".format(_sanitize(version))
        parts.append(
            """\
config_setting(
    name = "{}",
    flag_values = {{
        "{}": "{}",
    }},
)
""".format(name, _XCODE_VERSION_FLAG, version),
        )

    return "\n".join(parts)

def _render_alias(*, name, target_name, xcode_versions, no_match_error):
    lines = ["alias("]
    lines.append('    name = "{}",'.format(name))
    lines.append("    actual = select(")
    lines.append("        {")
    for version in xcode_versions:
        lines.append('            ":xcode_{v}": "@developer_frameworks_xcode_{v}//:{t}",'.format(
            v = _sanitize(version),
            t = target_name,
        ))
    lines.append("        },")
    lines.append('        no_match_error = "{}",'.format(no_match_error))
    lines.append("    ),")
    lines.append(")\n")
    return lines

def _render_root_aliases(framework_names, usr_lib_files, xcode_versions):
    no_match_error = (
        "No matching --xcode_version for @developer_frameworks. " +
        "Available: " + ", ".join(xcode_versions) + "."
    )
    lines = []
    for framework_name in framework_names:
        # Top-level alias for the xcode_developer_framework_import target itself.
        lines.extend(_render_alias(
            name = framework_name,
            target_name = framework_name,
            xcode_versions = xcode_versions,
            no_match_error = no_match_error,
        ))

        # Alias for the raw framework files filegroup. Lets users re-wrap with
        # their own xcode_developer_framework_import target (e.g. to add
        # linker_imports for companion archives).
        files_target = "{}_framework_files".format(framework_name)
        lines.extend(_render_alias(
            name = files_target,
            target_name = files_target,
            xcode_versions = xcode_versions,
            no_match_error = no_match_error,
        ))

    for usr_lib_file in usr_lib_files:
        # Alias names match the source path (e.g. "usr/lib/libXcodeExtension.a").
        lines.extend(_render_alias(
            name = usr_lib_file,
            target_name = usr_lib_file,
            xcode_versions = xcode_versions,
            no_match_error = no_match_error,
        ))
    return "\n".join(lines)

def _xcode_developer_framework_hub_repo_impl(rctx):
    xcode_versions = rctx.attr.xcode_versions
    rctx.watch(rctx.attr.default_manifest)
    framework_names = sorted(json.decode(rctx.read(rctx.attr.default_manifest)))

    usr_lib_files = []
    if rctx.attr.default_usr_lib_manifest:
        rctx.watch(rctx.attr.default_usr_lib_manifest)
        usr_lib_files = sorted(json.decode(rctx.read(rctx.attr.default_usr_lib_manifest)))

    rctx.file(
        "BUILD.bazel",
        'package(default_visibility = ["//visibility:public"])\n' +
        _xcode_config_settings(xcode_versions) +
        _render_root_aliases(framework_names, usr_lib_files, xcode_versions),
    )

xcode_developer_framework_hub_repo = repository_rule(
    implementation = _xcode_developer_framework_hub_repo_impl,
    attrs = {
        "default_manifest": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "Label of the default Xcode repo's framework_names.json.",
        ),
        "default_usr_lib_manifest": attr.label(
            allow_single_file = True,
            doc = "Label of the default Xcode repo's usr_lib_files.json.",
        ),
        "xcode_versions": attr.string_list(
            mandatory = True,
            doc = "All canonical Xcode versions.",
        ),
    },
    doc = "Export developer framework targets referencing Xcode version specific repos.",
    environ = [
        "DEVELOPER_DIR",
        "XCODE_VERSION",
    ],
)
