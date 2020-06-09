load(
    "//apple:dtrace.bzl",
    "dtrace_compile",
)

licenses(["notice"])

package(
    default_testonly = 1,
    default_visibility = ["//test/starlark_tests:__subpackages__"],
)

TARGETS_UNDER_TEST_TAGS = [
    "manual",
    "notap",
]

dtrace_compile(
    name = "dtrace",
    srcs = [
        "folder1/probes.d",
        "folder2/probes.d",
    ],
    tags = TARGETS_UNDER_TEST_TAGS,
)
