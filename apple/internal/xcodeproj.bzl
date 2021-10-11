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

"""Exposes rules to generate a xcodeproj"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("//apple/internal/aspects:xcodeproj_aspect.bzl", "XcodeGenTargetInfo", "sources_aspect")
load("@build_bazel_rules_apple//apple:providers.bzl", "IosApplicationBundleInfo")

_XCODEPROJ_RUNNER_SCRIPT = """\
#!/bin/bash
set -eu -o pipefail

cd $BUILD_WORKSPACE_DIRECTORY

export DEVELOPER_DIR=$({xcode_locator} {xcode_version} 2> /dev/null)

BAZEL_WORKSPACE=$BUILD_WORKSPACE_DIRECTORY
BAZEL_EXECROOT=$(bazel info execution_root)
BAZEL_OUTPUT_BASE=$(bazel info output_base)

BASE_PROJECT_PATH=$(basename {project})

# Move out of the sandbox
rm -rf $BASE_PROJECT_PATH
cp -R {project} $BASE_PROJECT_PATH
chmod -R 755 $BASE_PROJECT_PATH

# Sed the pbxproj so we can be outside the sandbox to run bazel
sed -i '' \
    -e "s#%%BAZEL_WORKSPACE%%#${{BAZEL_WORKSPACE}}#g" \
    -e "s#%%BAZEL_EXECROOT%%#${{BAZEL_EXECROOT}}#g" \
    -e "s#%%BAZEL_OUTPUT_BASE%%#${{BAZEL_OUTPUT_BASE}}#g" \
    $BASE_PROJECT_PATH/*.pbxproj

mkdir -p $BASE_PROJECT_PATH/project.xcworkspace/xcshareddata
cp -cf bazel-bin/WorkspaceSettings.xcsettings $BASE_PROJECT_PATH/project.xcworkspace/xcshareddata

open $BASE_PROJECT_PATH
"""

def _filter_depset(ds):
    return depset([
        f
        for f in ds.to_list()
        if f.is_source and not _is_file_external(f)
    ])

def _is_file_external(f):
    """Returns True if the given file is an external file."""
    return f.owner.workspace_root != ""

def _file_path(f):
    #prefix = "$BAZEL_WORKSPACE"
    prefix = ""
    if not f.is_source:
        prefix = "$BAZEL_EXECROOT"
    elif _is_file_external(f):
        prefix = "$BAZEL_OUTPUT_BASE"
    return paths.join(prefix, f.path)

def _collect_indexstores(info):
    return depset(
        transitive = [
            dep.swift.indexstore
            for dep in info.transitive_deps.to_list()
            if hasattr(dep, "swift")
        ],
    )

def _file_bazel_path(f, prefix = "", suffix = ""):
    bazel_dir = "BAZEL_WORKSPACE"
    if not f.is_source:
        bazel_dir = "BAZEL_EXECROOT"
    elif _is_file_external(f):
        bazel_dir = "BAZEL_OUTPUT_BASE"
    return paths.join(prefix + bazel_dir + suffix, f.path)

def _xcodeproj_impl(ctx):
    targets = {}
    schemes = {}
    inputs = []
    for dep in ctx.attr.deps:
        if XcodeGenTargetInfo in dep:
            xti = dep[XcodeGenTargetInfo]

            # _index_imports(xti)
            inputs.append(xti.srcs)
            targets[xti.name] = xti.target
            for d in xti.transitive_deps.to_list():
                # Also search for schemes in transitive dependencies (extensions)
                if hasattr(d, "scheme") and d.scheme != None:
                    schemes[d.name] = d.scheme
                inputs.append(d.srcs)
                targets[d.name] = d.target
            if hasattr(xti, "scheme") and xti.scheme != None:
                schemes[xti.name] = xti.scheme

    inputs = _filter_depset(depset(transitive = inputs))

    projname = (ctx.attr.project_name or ctx.attr.name)
    project_name = projname + ".xcodeproj"
    project_json_name = projname + ".json"
    project = ctx.actions.declare_directory(project_name)
    json_xcodegen = ctx.actions.declare_file(project_json_name)

    args = ctx.actions.args()
    args.add(ctx.attr.project_name or ctx.attr.name)
    args.add(json_xcodegen)

    #################################
    # Handle aspect's provider info #
    #################################

    info = struct(
        name = ctx.attr.project_name,
        options = {
            "createIntermediateGroups": True,
            "defaultConfig": "Debug",
            "groupSortPosition": "none",
            "settingPresets": "none",
        },
        settings = {
            "base": {
                "CC": _file_bazel_path(ctx.file._clang_stub, prefix = "$"),
                "CXX": "$CC",
                "CLANG_ANALYZER_EXEC": "$CC",
                "SWIFT_EXEC": _file_bazel_path(ctx.file._swiftc_stub, prefix = "$"),
                "LD": _file_bazel_path(ctx.file._ld_stub, prefix = "$"),
                "LIBTOOL": "/usr/bin/true",
                "OTHER_LDFLAGS": "-fuse-ld={}".format(_file_bazel_path(ctx.file._ld_stub, prefix = "$")),
                "USE_HEADERMAP": False,
                "CODE_SIGNING_ALLOWED": False,
                "DEBUG_INFORMATION_FORMAT": "dwarf",
                "DONT_RUN_SWIFT_STDLIB_TOOL": True,
                "SWIFT_OBJC_INTERFACE_HEADER_NAME": "",
                "SWIFT_VERSION": 5,
                "BAZEL_WORKSPACE": "%%BAZEL_WORKSPACE%%",
                "BAZEL_EXECROOT": "%%BAZEL_EXECROOT%%",
                "BAZEL_OUTPUT_BASE": "%%BAZEL_OUTPUT_BASE%%",
                "INDEX_IMPORT": _file_bazel_path(ctx.file._index_import, prefix = "$"),
                "ONLY_ACTIVE_ARCH": "YES",
                "CLANG_ENABLE_MODULES": "YES",
                "CLANG_ENABLE_OBJ_ARC": "YES",
                "XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED": "NO",
            },
            "configs": {
                "Debug": {
                    "GCC_PREPROCESSOR_DEFINITIONS": "DEBUG",
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
                },
                "Release": {},
            },
        },
        configs = {
            "Debug": "debug",
            "Release": "release",
        },
        schemes = schemes,
        targets = targets,
    )
    ctx.actions.write(json_xcodegen, info.to_json())

    # Call xcodegen with our JSON file
    args = ctx.actions.args()
    args.add_all([
        "--quiet",
        "--no-env",
        "--spec",
        json_xcodegen,
        "--project-root",
        ".",
        "--project",
        project.dirname,
    ])
    ctx.actions.run(
        executable = ctx.executable._xcodegen,
        arguments = [args],
        inputs = depset([json_xcodegen], transitive = [inputs]),
        outputs = [project],
    )

    # Codegen the WorkspaceSettings.xcsettings to disable the auto create schemes
    workspace_settings = ctx.actions.declare_file("WorkspaceSettings.xcsettings")
    ctx.actions.write(
        output = workspace_settings,
        is_executable = False,
        content = """\
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>IDEWorkspaceSharedSettings_AutocreateContextsIfNeeded</key>
        <false/>
</dict>
</plist>
""",
    )

    # Create a runner script that will open with XCode
    xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]
    runner = ctx.actions.declare_file("runner.sh")
    ctx.actions.write(
        output = runner,
        is_executable = True,
        content = _XCODEPROJ_RUNNER_SCRIPT.format(
            project = _file_bazel_path(project, prefix = "$"),
            xcode_locator = ctx.executable._xcode_locator.short_path,
            xcode_version = str(xcode_config.xcode_version()),
        ),
    )

    outfiles = [
        json_xcodegen,
        project,
        workspace_settings,
        ctx.file._clang_stub,
        ctx.file._swiftc_stub,
        ctx.file._ld_stub,
    ]
    return [
        DefaultInfo(
            executable = runner,
            files = depset(outfiles),
            runfiles = ctx.runfiles(files = outfiles),
        ),
    ]

xcodeproj = rule(
    implementation = _xcodeproj_impl,
    attrs = {
        "project_name": attr.string(mandatory = False),
        "deps": attr.label_list(
            mandatory = True,
            allow_empty = False,
            providers = [IosApplicationBundleInfo],
            aspects = [sources_aspect],
        ),
        "_xcodegen": attr.label(
            default = "@com_github_yonaskolb_xcodegen//:xcodegen",
            executable = True,
            cfg = "host",
        ),
        "_clang_stub": attr.label(
            default = "//tools/xcodeprojgen:clang-stub.sh",
            cfg = "host",
            allow_single_file = True,
        ),
        "_swiftc_stub": attr.label(
            default = "//tools/xcodeprojgen:swiftc-stub.sh",
            cfg = "host",
            allow_single_file = True,
        ),
        "_ld_stub": attr.label(
            default = "//tools/xcodeprojgen:ld-stub.sh",
            cfg = "host",
            allow_single_file = True,
        ),
        "_index_import": attr.label(
            executable = True,
            default = "@build_bazel_rules_swift_index_import//:index_import",
            cfg = "host",
            allow_single_file = True,
        ),
        "_xcode_config": attr.label(
            default = "@bazel_tools//tools/osx:current_xcode_config",
        ),
        # Use built-in xcode-locator binary to get the DEVELOPER_DIR from the
        # Xcode version. Properly setting the DEVELOPER_DIR ensures the right
        # Xcode version is launched based on the --xcode_version bazel flag.
        "_xcode_locator": attr.label(
            default = "@bazel_tools//tools/osx:xcode-locator",
            allow_single_file = True,
            cfg = "host",
            executable = True,
        ),
    },
    executable = True,
)
