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
load("@com_github_bazelbuild_tulsi//src/TulsiGenerator/Bazel:tulsi/tulsi_aspects.bzl", "tulsi_sources_aspect", "TulsiOutputAspectInfo", "tulsi_outputs_aspect", "TulsiSourcesAspectInfo")
load("@build_bazel_rules_apple//apple:providers.bzl", "AppleBundleInfo")

COPY_FILE_COMMAND = """\
for f in ${{@}}; do
    cat ${{f}} >> {out}
done
"""

def _xcodeproj_impl(ctx):
    projname = (ctx.attr.project_name or ctx.attr.name)
    project_name = projname + ".xcodeproj/project.pbxproj"
    project_json_name = projname + ".json"
    project = ctx.actions.declare_file(project_name)
    json_xcodegen = ctx.actions.declare_file(project_json_name)

    clang_stub = ctx.actions.declare_file(projname + ".xcodeproj/clang-stub")
    ctx.actions.run_shell(
        inputs = ctx.files._clang_stub,
        outputs = [clang_stub],
        command = COPY_FILE_COMMAND.format(out = clang_stub.path),
        arguments = [f.path for f in ctx.files._clang_stub],
    )

    swiftc_stub = ctx.actions.declare_file(projname + ".xcodeproj/swiftc-stub")
    ctx.actions.run_shell(
        inputs = ctx.files._swiftc_stub,
        outputs = [swiftc_stub],
        command = COPY_FILE_COMMAND.format(out = swiftc_stub.path),
        arguments = [f.path for f in ctx.files._swiftc_stub],
    )

    ld_stub = ctx.actions.declare_file(projname + ".xcodeproj/ld-stub")
    ctx.actions.run_shell(
        inputs = ctx.files._ld_stub,
        outputs = [ld_stub],
        command = COPY_FILE_COMMAND.format(out = ld_stub.path),
        arguments = [f.path for f in ctx.files._ld_stub],
    )

    outputfilemap = ctx.actions.declare_file(projname + ".xcodeproj/outputfilemap")
    ctx.actions.run_shell(
        inputs = ctx.files._output_file_map,
        outputs = [outputfilemap],
        command = COPY_FILE_COMMAND.format(out = outputfilemap.path),
        arguments = [f.path for f in ctx.files._output_file_map],
    )

    index_import = ctx.actions.declare_file(projname + ".xcodeproj/index-import")
    ctx.actions.run_shell(
        inputs = [ctx.executable._index_import],
        outputs = [index_import],
        command = COPY_FILE_COMMAND.format(out = index_import.path),
        arguments = [ctx.executable._index_import.path],
    )

    bep = ctx.actions.declare_file(projname + ".xcodeproj/bep")
    ctx.actions.run_shell(
        inputs = ctx.files._bep,
        outputs = [bep],
        command = COPY_FILE_COMMAND.format(out = bep.path),
        arguments = [f.path for f in ctx.files._bep],
    )


    for dep in ctx.attr.deps:
        if TulsiSourcesAspectInfo in dep:
            tif = dep[TulsiSourcesAspectInfo].transitive_info_files
            args = ctx.actions.args()
            args.add(ctx.attr.project_name or ctx.attr.name)
            args.add(json_xcodegen)
            if AppleBundleInfo in dep:
                bundle_info = dep[AppleBundleInfo]
                args.add(bundle_info.infoplist.path)
            else:
                args.add("")
            args.add_all(tif)
            ctx.actions.run(
                inputs = tif,
                outputs = [json_xcodegen],
                arguments = [args],
                executable = ctx.executable._xcodeprojgen,
            )

    # Call xcodegen with our JSON file
    args = ctx.actions.args()
    args.add_all([
        "--quiet",
        "--no-env",
        "--spec",
        json_xcodegen,
        "--project",
        paths.dirname(project.dirname),
    ])
    ctx.actions.run(
        executable = ctx.executable._xcodegen,
        arguments = [args],
        inputs = [json_xcodegen],
        outputs = [project],
    )

    # Create a runner script that will open with XCode
    runner = ctx.actions.declare_file("runner.sh")
    ctx.actions.write(
        output = runner,
        is_executable = True,
        content = """\
#!/bin/bash

cd $BUILD_WORKSPACE_DIRECTORY

PROJECT_PATH={}
BASE_PROJECT_PATH=$(basename $PROJECT_PATH)

# Sed the pbxproj so we can be outside the sandbox to run bazel
sed -i '' -e "s#%%BWR%%#${{BUILD_WORKSPACE_DIRECTORY}}#g" bazel-bin/$PROJECT_PATH/*.pbxproj
sed -i '' -e "s#%%BWD%%#${{BUILD_WORKSPACE_DIRECTORY}}/bazel-$(basename ${{BUILD_WORKSPACE_DIRECTORY}})#g" bazel-bin/$PROJECT_PATH/*.pbxproj

# Move out of the sandbox
rm -rf $BASE_PROJECT_PATH
cp -R bazel-bin/$PROJECT_PATH $BASE_PROJECT_PATH

open $BASE_PROJECT_PATH
""".format(paths.dirname(project.short_path)),
    )

    outfiles = [json_xcodegen, project, clang_stub, swiftc_stub, ld_stub, outputfilemap, index_import, bep]
    return [
        DefaultInfo(
            executable = runner,
            files = depset(outfiles),
            runfiles = ctx.runfiles(files = outfiles),
        )
    ]

xcodeproj = rule(
    implementation = _xcodeproj_impl,
    doc = """\
    """,
    attrs = {
        "deps": attr.label_list(mandatory = True, allow_empty = False, providers = [], aspects = [tulsi_sources_aspect, tulsi_outputs_aspect]),
        "project_name": attr.string(mandatory = False),
        "_xcodegen": attr.label(executable = True, default = Label("@com_github_yonaskolb_xcodegen//:xcodegen"), cfg = "host"),
        "_xcodeprojgen": attr.label(executable = True, default = Label("//tools/xcodeprojgen:xcodeprojgen"), cfg = "host"),
        "_clang_stub": attr.label(allow_single_file = ["sh"], default = Label("//tools/xcodeprojgen:clang-stub.sh"), cfg = "host"),
        "_swiftc_stub": attr.label(allow_single_file = ["sh"], default = Label("//tools/xcodeprojgen:swiftc-stub.sh"), cfg = "host"),
        "_ld_stub": attr.label(allow_single_file = ["sh"], default = Label("//tools/xcodeprojgen:ld-stub.sh"), cfg = "host"),
        "_output_file_map": attr.label(allow_single_file = ["py"], default = Label("//tools/xcodeprojgen:outputfilemap.py"), cfg = "host"),
        "_index_import": attr.label(executable = True, default = Label("@build_bazel_rules_swift_index_import//:index_import"), cfg = "host"),
        "_bep": attr.label(allow_single_file = ["py"], default = Label("//tools/xcodeprojgen:bep.py"), cfg = "host"),
    },
    executable = True,
)