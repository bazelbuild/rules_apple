licenses(["notice"])

py_library(
    name = "plisttool_lib",
    srcs = [
        "plisttool.py",
    ],
)

py_test(
    name = "plisttool_unittest",
    srcs = ["plisttool_unittest.py"],
    env = {
        "SWIFT_DETERMINISTIC_HASHING": "1",  # Required for stable binary1 plutil output.
    },
    strict_deps = False,
    deps = [
        ":plisttool_lib",
    ],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]),
    visibility = [
        "//tools:__pkg__",
    ],
)
