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

"""Configure Xcode developer framework repos for all local Xcode versions."""

load("@bazel_tools//tools/osx:xcode_configure.bzl", "run_xcode_locator")
load(":xcode_developer_framework_hub_repo.bzl", "xcode_developer_framework_hub_repo")
load(":xcode_developer_framework_repo.bzl", "xcode_developer_framework_repo")

_XCODE_LOCATOR_SRC = Label("@bazel_tools//tools/osx:xcode_locator.m")
_SCANNER_SCRIPT = Label("//tools/xcode_developer_frameworks:scan.py")

def _sanitize(v):
    return v.replace(".", "_").replace("-", "_")

def _default_xcode_path(module_ctx):
    result = module_ctx.execute(
        ["xcode-select", "-p"],
        environment = {"DEVELOPER_DIR": module_ctx.os.environ.get("DEVELOPER_DIR", "")},
    )
    output = result.stdout.strip()
    if result.return_code != 0 or not output:
        fail("xcode-select failed.\nstdout:\n{}\nstderr:\n{}".format(
            output,
            result.stderr,
        ))

    if output == "/Library/Developer/CommandLineTools":
        return None
    return output

def _generate_local_repos(module_ctx):
    toolchains, err = run_xcode_locator(module_ctx, _XCODE_LOCATOR_SRC)
    if err:
        fail("xcode-locator failed: " + err)
    if not toolchains:
        _developer_frameworks_stub_repo(name = "developer_frameworks")
        return

    default_path = _default_xcode_path(module_ctx)
    if not default_path:
        default_path = sorted(
            toolchains,
            key = lambda t: t.version,
            reverse = True,
        )[0].developer_dir

    versions_ordered = []
    default_manifest = None
    default_usr_lib_manifest = None
    for tc in toolchains:
        repo_name = "developer_frameworks_xcode_" + _sanitize(tc.version)
        xcode_developer_framework_repo(
            name = repo_name,
            xcode_version = tc.version,
            developer_dir = tc.developer_dir,
        )
        versions_ordered.append(tc.version)
        if tc.developer_dir == default_path:
            default_manifest = "@{}//:framework_names.json".format(repo_name)
            default_usr_lib_manifest = "@{}//:usr_lib_files.json".format(repo_name)

    xcode_developer_framework_hub_repo(
        name = "developer_frameworks",
        default_manifest = default_manifest,
        default_usr_lib_manifest = default_usr_lib_manifest,
        xcode_versions = versions_ordered,
    )

_STUB_BUILD_FILE = 'package(default_visibility = ["//visibility:public"])\n'

def _developer_frameworks_stub_repo_impl(rctx):
    rctx.file("BUILD.bazel", _STUB_BUILD_FILE)

_developer_frameworks_stub_repo = repository_rule(
    implementation = _developer_frameworks_stub_repo_impl,
    doc = "Empty repo used when no full Xcode is available so @developer_frameworks always resolves.",
)

def _developer_frameworks_impl(module_ctx):
    module_ctx.watch(_SCANNER_SCRIPT)

    if module_ctx.os.name != "mac os x":
        _developer_frameworks_stub_repo(name = "developer_frameworks")
        return

    _generate_local_repos(module_ctx)

developer_frameworks = module_extension(
    implementation = _developer_frameworks_impl,
    doc = "Generate repositories for Xcode developer frameworks.",
    environ = [
        "DEVELOPER_DIR",
        "XCODE_VERSION",
    ],
)
