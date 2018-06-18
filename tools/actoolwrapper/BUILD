package(default_visibility = ["//visibility:public"])

licenses(["notice"])

sh_binary(
    name = "actoolwrapper",
    srcs = ["actoolwrapper.sh"],
    deps = ["//tools/wrapper_common"],
)

py_binary(
    name = "actoolwrapper_experimental",
    srcs = ["actoolwrapper.py"],
    main = "actoolwrapper.py",
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
