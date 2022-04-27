# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Starlark test rules for debug symbols."""

load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBinaryInfo",
    "AppleBundleInfo",
    "AppleDsymBundleInfo",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@bazel_skylib//lib:unittest.bzl",
    "analysistest",
    "asserts",
)

def check_public_provider_outputs(
        *,
        dsym_bundle_info_outputs,
        dsyms_attr_name,
        env,
        expected_dsyms_attr,
        test_package):
    """Verify all outputs of the public AppleDsymBundleInfo provider given outputs of a field"""
    expected_bundles = [
        "{0}/dSYMs/{1}.dSYM".format(test_package, x)
        for x in expected_dsyms_attr
    ]

    for expected in expected_bundles:
        asserts.true(
            env,
            expected in dsym_bundle_info_outputs,
            msg = """\
Expected\n\n{0}\n\nto be in the {1} field of the AppleDsymBundleInfo provider.
Contents were:\n\n{2}\n\n""".format(
                expected,
                dsyms_attr_name,
                "\n".join(dsym_bundle_info_outputs.keys()),
            ),
        )

def _dsyms_test_impl(ctx):
    """Implementation of the dsyms_test rule."""
    env = analysistest.begin(ctx)
    target_under_test = ctx.attr.target_under_test[0]
    architectures = ctx.attr.architectures

    if not architectures:
        if AppleBundleInfo in target_under_test:
            platform_type = target_under_test[AppleBundleInfo].platform_type
            if platform_type == "watchos":
                architectures = ["i386"]
            else:
                architectures = ["x86_64"]
        elif AppleBinaryInfo in target_under_test:
            # AppleBinaryInfo does not supply a platform_type. In this case, assume x86_64.
            architectures = ["x86_64"]
        else:
            fail(("Target %s does not provide AppleBundleInfo or AppleBinaryInfo") %
                 target_under_test.label)

    output_group_dsyms = {
        x.short_path: None
        for x in target_under_test[OutputGroupInfo]["dsyms"].to_list()
    }

    package = target_under_test.label.package

    all_expected_dsyms = ctx.attr.expected_direct_dsyms + ctx.attr.expected_transitive_dsyms

    expected_infoplists = [
        "{0}/{1}.dSYM/Contents/Info.plist".format(package, x)
        for x in all_expected_dsyms
    ]

    if ctx.attr.expected_binaries:
        expected_binaries = [
            "{0}/{1}".format(
                package,
                x,
            )
            for x in ctx.attr.expected_binaries
        ]
    else:
        expected_binaries = [
            "{0}/{1}.dSYM/Contents/Resources/DWARF/{2}".format(
                package,
                x,
                paths.split_extension(x)[0],
            )
            for x in all_expected_dsyms
        ]

    workspace = target_under_test.label.workspace_name
    if workspace != "":
        expected_infoplists = [
            paths.join("..", workspace, x)
            for x in expected_infoplists
        ]
        expected_binaries = [
            paths.join("..", workspace, x)
            for x in expected_binaries
        ]

    for expected in expected_infoplists + expected_binaries:
        asserts.true(
            env,
            expected in output_group_dsyms,
            msg = """\
Expected\n\n{0}\n\nto be in the dSYM output group.
Contents were:\n\n{1}\n\n""".format(
                expected,
                "\n".join(output_group_dsyms.keys()),
            ),
        )

    if ctx.attr.check_public_provider:
        if AppleDsymBundleInfo not in target_under_test:
            fail(("Target %s does not provide AppleDsymBundleInfo") % target_under_test.label)

        dsym_bundle_info_direct_outputs = {
            x.short_path: None
            for x in target_under_test[AppleDsymBundleInfo].direct_dsyms
        }
        check_public_provider_outputs(
            dsym_bundle_info_outputs = dsym_bundle_info_direct_outputs,
            dsyms_attr_name = "direct_dsyms",
            env = env,
            expected_dsyms_attr = ctx.attr.expected_direct_dsyms,
            test_package = package,
        )

        dsym_bundle_info_transitive_outputs = {
            x.short_path: None
            for x in target_under_test[AppleDsymBundleInfo].transitive_dsyms.to_list()
        }
        check_public_provider_outputs(
            dsym_bundle_info_outputs = dsym_bundle_info_transitive_outputs,
            dsyms_attr_name = "transitive_dsyms",
            env = env,
            expected_dsyms_attr = ctx.attr.expected_transitive_dsyms,
            test_package = package,
        )

    return analysistest.end(env)

dsyms_test = analysistest.make(
    _dsyms_test_impl,
    attrs = {
        "architectures": attr.string_list(
            mandatory = False,
            default = [],
            doc = """
List of architectures to verify for the given dSYM bundles as provided. Defaults to x86_64 for all
platforms except for watchOS, which has a default of i386.
""",
        ),
        "expected_direct_dsyms": attr.string_list(
            mandatory = True,
            doc = """
List of bundle names in the format <bundle_name>.<bundle_extension> to verify that dSYM bundles are
created for them as direct dependencies of the given providers.
""",
        ),
        "expected_transitive_dsyms": attr.string_list(
            mandatory = True,
            doc = """
List of bundle names in the format <bundle_name>.<bundle_extension> to verify that dSYM bundles are
created for them as transitive dependencies of the given providers.
""",
        ),
        "expected_binaries": attr.string_list(
            mandatory = False,
            doc = """
List of expected binaries in dSYMs bundles in the format
<bundle_name>.<bundle_extension>/Contents/Resources/DWARF/<executable_name> to
verify that dSYMs binaries are created with the correct names.
""",
        ),
        "check_public_provider": attr.bool(
            default = True,
            doc = """
Checks for the presence of the AppleDsymBundleInfo provider and verifies its File-referenced
contents. Defaults to `True`.
""",
        ),
    },
    config_settings = {
        "//command_line_option:apple_generate_dsym": "true",
    },
)
