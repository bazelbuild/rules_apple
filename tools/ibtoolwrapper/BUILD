package(default_visibility = ["//visibility:public"])

licenses(["notice"])

sh_binary(
    name = "ibtoolwrapper",
    srcs = ["ibtoolwrapper.sh"],
    deps = ["//tools/wrapper_common"],
)

py_binary(
    name = "ibtoolwrapper_experimental",
    srcs = ["ibtoolwrapper.py"],
    main = "ibtoolwrapper.py",
    deps = ["//tools/wrapper_common:execute"],
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
