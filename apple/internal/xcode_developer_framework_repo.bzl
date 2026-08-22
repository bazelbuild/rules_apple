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

"""Per-Xcode developer framework BUILD file generator."""

def _symlink_frameworks(rctx, developer_dir):
    developer_frameworks_dir = rctx.path(developer_dir).get_child("Library/Frameworks")
    manifest = json.decode(rctx.read("framework_names.json"))
    for framework_name in manifest:
        framework = developer_frameworks_dir.get_child("{}.framework".format(framework_name))
        rctx.symlink(framework, "{}.framework".format(framework_name))

        dsym = developer_frameworks_dir.get_child("{}.framework.dSYM".format(framework_name))
        if dsym.exists:
            rctx.symlink(dsym, "{}.framework.dSYM".format(framework_name))

    # Expose $DEVELOPER_DIR/usr/lib so users can wire companion static archives
    # (e.g. libXCTestSwiftSupport.a) into xcode_developer_framework_import's
    # linker_imports attribute.
    usr_dir = rctx.path(developer_dir).get_child("usr")
    if usr_dir.exists:
        rctx.symlink(usr_dir, "usr")

def _xcode_developer_framework_repo_impl(rctx):
    rctx.report_progress("Scanning developer frameworks for Xcode {}".format(rctx.attr.xcode_version))
    rctx.watch(rctx.attr._script)
    result = rctx.execute(
        [
            "/usr/bin/python3",
            rctx.attr._script,
            "--output",
            "BUILD.bazel",
            "--framework-names",
            "framework_names.json",
            "--usr-lib-files",
            "usr_lib_files.json",
            "--developer-dir",
            rctx.attr.developer_dir,
        ],
    )
    if result.return_code != 0:
        fail(
            "error: scanning developer frameworks failed for Xcode {}:\nstdout:\n{}\nstderr:\n{}".format(
                rctx.attr.xcode_version,
                result.stdout,
                result.stderr,
            ),
        )

    _symlink_frameworks(rctx, rctx.attr.developer_dir)

xcode_developer_framework_repo = repository_rule(
    implementation = _xcode_developer_framework_repo_impl,
    attrs = {
        "xcode_version": attr.string(
            mandatory = True,
            doc = "Canonical Xcode version string (e.g. 26.4.0.17E192).",
        ),
        "developer_dir": attr.string(
            mandatory = True,
            doc = "Absolute path to this Xcode's Developer directory.",
        ),
        "_script": attr.label(
            default = Label("//tools/xcode_developer_frameworks:scan.py"),
            allow_single_file = True,
        ),
    },
    doc = "Discover developer framework import targets for a given Xcode version.",
    configure = True,
    environ = [
        "DEVELOPER_DIR",
        "XCODE_VERSION",
    ],
)
