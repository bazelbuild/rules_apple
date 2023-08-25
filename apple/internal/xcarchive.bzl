"""
Rule for packaging a bundle into a .xcarchive.
"""

load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "AppleDsymBundleInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "new_applebinaryinfo",
)

def _xcarchive_impl(ctx):
    """
    Implementation for xcarchive.

    This rule uses the providers from the bundle target to re-package it into a .xcarchive.
    The .xcarchive is a directory that contains the .app bundle, dSYM and other metadata.
    """
    bundle_info = ctx.attr.bundle[AppleBundleInfo]
    dsym_info = ctx.attr.bundle[AppleDsymBundleInfo]
    xcarchive = ctx.actions.declare_directory("%s.xcarchive" % bundle_info.bundle_name)

    arguments = ctx.actions.args()
    arguments.add("--info_plist", bundle_info.infoplist.path)
    arguments.add("--bundle", bundle_info.archive.path)
    arguments.add("--output", xcarchive.path)

    for dsym in dsym_info.direct_dsyms:
        arguments.add("--dsym", dsym.path)

    ctx.actions.run(
        inputs = depset([
            bundle_info.archive,
            bundle_info.infoplist,
        ] + dsym_info.direct_dsyms),
        outputs = [xcarchive],
        executable = ctx.executable._make_xcarchive,
        arguments = [arguments],
        mnemonic = "XCArchive",
    )

    # Limiting the contents of AppleBinaryInfo to what is necessary for testing and validation.
    xcarchive_binary_info = new_applebinaryinfo(
        binary = xcarchive,
        infoplist = None,
        product_type = None,
    )

    return [
        DefaultInfo(files = depset([xcarchive])),
        xcarchive_binary_info,
    ]

xcarchive = rule(
    implementation = _xcarchive_impl,
    attrs = {
        "bundle": attr.label(
            providers = [
                AppleBundleInfo,
                AppleDsymBundleInfo,
            ],
            doc = """\
The label to a target to re-package into a .xcarchive. For example, an
`ios_application` target.
            """,
        ),
        "_make_xcarchive": attr.label(
            default = Label("@build_bazel_rules_apple//tools/xcarchivetool:make_xcarchive"),
            executable = True,
            cfg = "exec",
            doc = """\
An executable binary that can re-package a bundle into a .xcarchive.
            """,
        ),
    },
    doc = """\
Re-packages an Apple bundle into a .xcarchive.

This rule uses the providers from the bundle target to construct the required
metadata for the .xcarchive.

Example:

````starlark
load("@build_bazel_rules_apple//apple:xcarchive.bzl", "xcarchive")

ios_application(
    name = "App",
    bundle_id = "com.example.my.app",
    ...
)

xcarchive(
    name = "App.xcarchive",
    bundle = ":App",
)
````
    """,
)
