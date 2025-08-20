licenses(["notice"])

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]) + [
        "//tools/bundletool:for_bazel_tests",
        "//tools/dossier_codesigningtool:for_bazel_tests",
        "//tools/environment_plist:for_bazel_tests",
        "//tools/plisttool:for_bazel_tests",
        "//tools/versiontool:for_bazel_tests",
    ],
    visibility = [
        "//:__pkg__",
    ],
)
