licenses(["notice"])

# TODO(b/277604599): Address supporting Apple Silicon. This target is only supported on an Intel
# Mac, which incurs a performance penalty for all spawned subprocesses including /usr/bin/codesign
# when it is executed.
py_binary(
    name = "dossier_codesigning_reader",
    srcs = ["dossier_codesigning_reader.py"],
    strict_deps = False,
    deps = [":dossier_codesigning_reader_lib"],
)

py_library(
    name = "dossier_codesigning_reader_lib",
    srcs = ["dossier_codesigning_reader.py"],
    strict_deps = False,
)

filegroup(
    name = "watchos_dossier_zip",
    testonly = True,
    srcs = ["//test/starlark_tests/targets_under_test/watchos:app_companion"],
    output_group = "combined_dossier_zip",
)

py_test(
    name = "dossier_codesigning_reader_test",
    srcs = ["dossier_codesigning_reader_test.py"],
    data = [
        ":watchos_dossier_zip",
        "//test/starlark_tests/targets_under_test/ios:app",
        "//test/starlark_tests/targets_under_test/watchos:app_companion",
    ],
    strict_deps = False,
    deps = [
        ":dossier_codesigning_reader_lib",
        "@absl_py//absl/testing:parameterized",
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
