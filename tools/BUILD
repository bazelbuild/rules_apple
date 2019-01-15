licenses(["notice"])

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]) + [
        "//tools/bundletool:for_bazel_tests",
        "//tools/clangrttool:for_bazel_tests",
        "//tools/codesigningtool:for_bazel_tests",
        "//tools/environment_plist:for_bazel_tests",
        "//tools/plisttool:for_bazel_tests",
        "//tools/provisioning_profile_tool:for_bazel_tests",
        "//tools/realpath:for_bazel_tests",
        "//tools/swift_stdlib_tool:for_bazel_tests",
        "//tools/versiontool:for_bazel_tests",
        "//tools/wrapper_common:for_bazel_tests",
        "//tools/xctoolrunner:for_bazel_tests",
    ],
    visibility = [
        "//:__pkg__",
    ],
)
