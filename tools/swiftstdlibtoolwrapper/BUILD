package(default_visibility = ["//visibility:public"])

licenses(["notice"])

sh_binary(
    name = "swiftstdlibtoolwrapper_shell",
    srcs = ["swiftstdlibtoolwrapper.sh"],
    deps = ["//tools/wrapper_common"],
)

py_binary(
    name = "swiftstdlibtoolwrapper",
    srcs = ["swiftstdlibtoolwrapper.py"],
    main = "swiftstdlibtoolwrapper.py",
    deps = [
        "//tools/xctoolrunner",
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
