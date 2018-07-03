package(default_visibility = ["//visibility:public"])

licenses(["notice"])

sh_binary(
    name = "mapcwrapper",
    srcs = ["mapcwrapper.sh"],
    deps = ["//tools/wrapper_common"],
)

py_binary(
    name = "mapcwrapper_experimental",
    srcs = ["mapcwrapper.py"],
    main = "mapcwrapper.py",
    deps = ["//tools/xctoolrunner"],
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
