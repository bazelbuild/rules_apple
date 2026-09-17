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

"""Rule that exposes data files as runfiles for Apple tests."""

load(
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "AppleBundleImportInfo",
    "AppleResourceBundleInfo",
    "AppleResourceGroupInfo",
    "AppleRunfilesInfo",
    "new_applerunfilesinfo",
)

visibility([
    "@build_bazel_rules_apple//apple/...",
])

def _apple_runfiles_data_impl(ctx):
    all_targets = ctx.attr.srcs + ctx.attr.deps
    for dep in all_targets:
        if (
            AppleResourceBundleInfo in dep or
            AppleResourceGroupInfo in dep or
            AppleBundleImportInfo in dep
        ):
            fail((
                "apple_runfiles_data target '{label}' cannot depend on Apple resource rule " +
                "'{dep}'. apple_runfiles_data is intended for host runfiles accessed " +
                "via TEST_SRCDIR, not for bundled Apple resources."
            ).format(
                dep = str(dep.label),
                label = str(ctx.label),
            ))

    transitive_files = [
        dep[DefaultInfo].files
        for dep in all_targets
        if DefaultInfo in dep
    ]
    transitive_runfiles = [
        dep[AppleRunfilesInfo].runfiles if AppleRunfilesInfo in dep else dep[DefaultInfo].default_runfiles
        for dep in all_targets
        if AppleRunfilesInfo in dep or DefaultInfo in dep
    ]
    runfiles = ctx.runfiles(
        transitive_files = depset(transitive = transitive_files),
    ).merge_all(transitive_runfiles)
    return [
        DefaultInfo(
            files = depset(),
            runfiles = runfiles,
        ),
        new_applerunfilesinfo(
            runfiles = runfiles,
        ),
    ]

apple_runfiles_data = rule(
    implementation = _apple_runfiles_data_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = True,
            doc = """
The list of files to expose as runfiles.
""",
        ),
        "deps": attr.label_list(
            doc = """
Targets whose runfiles should be transitively included in this target's runfiles.
""",
        ),
    },
    doc =
        """
Exposes files and transitive dependencies as runfiles accessible via `TEST_SRCDIR`.
""",
)
