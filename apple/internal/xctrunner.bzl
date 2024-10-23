"""
Rule for merging multiple test targets into a single XCTRunner.app bundle.
"""

load("@build_bazel_rules_apple//apple:providers.bzl", "AppleBundleInfo")

def _xctrunner_impl(ctx):
    # Get test target info
    bundle_info = [target[AppleBundleInfo] for target in ctx.attr.test_targets]
    xctests = [info.archive for info in bundle_info]  # xctest bundles
    infoplist = [info.infoplist for info in bundle_info]  # Info.plist files
    output = ctx.actions.declare_directory(ctx.label.name + ".app")

    # Args for _make_xctrunner
    arguments = ctx.actions.args()
    arguments.add("--name", ctx.label.name)
    arguments.add("--platform", ctx.attr.platform)

    # absolute paths to xctest bundles
    xctest_paths = [xctest.path for xctest in xctests]
    arguments.add_all(
        xctest_paths,
        before_each = "--xctest",
        expand_directories = False,
    )

    # app bundle output path
    arguments.add("--output", output.path)

    ctx.actions.run(
        inputs = depset(xctests + infoplist),
        outputs = [output],
        executable = ctx.executable._make_xctrunner,
        arguments = [arguments],
        mnemonic = "MakeXCTRunner",
    )

    return DefaultInfo(files = depset([output]))

xctrunner = rule(
    implementation = _xctrunner_impl,
    attrs = {
        "test_targets": attr.label_list(
            mandatory = True,
            providers = [
                AppleBundleInfo,
            ],
            doc = "List of test targets to include.",
        ),
        "platform": attr.string(
            default = "iPhoneOS.platform",
            mandatory = False,
            doc = "Platform to bundle for. Default: iPhoneOS.platform",
        ),
        "arch": attr.string(
            default = "arm64",
            mandatory = False,
            doc = "List of architectures to bundle for. Default: arm64",
        ),
        "zip": attr.bool(
            default = False,
            mandatory = False,
            doc = "Whether to zip the resulting bundle.",
        ),
        "_make_xctrunner": attr.label(
            default = Label("//tools/xctrunnertool:run"),
            executable = True,
            cfg = "exec",
            doc = "An executable binary that can merge separate xctest into a single XCTestRunner bundle.",
        ),
    },
    doc = """\
Packages one or more .xctest bundles into a XCTRunner.app.

Note: Tests inside must be qualified with the test target
name as `testTargetName/testClass/testCase` for device farm builds.

Example:

````starlark
load("//apple:xctrunner.bzl", "xctrunner")

ios_ui_test(
    name = "HelloWorldSwiftUITests",
    minimum_os_version = "15.0",
    runner = "@build_bazel_rules_apple//apple/testing/default_runner:ios_xctestrun_ordered_runner",
    test_host = ":HelloWorldSwift",
    deps = [":UITests"],
)

xctrunner(
    name = "HelloWorldSwiftXCTRunner",
    test_targets = [":HelloWorldSwiftUITests"],
    testonly = True,
)
````
    """,
)