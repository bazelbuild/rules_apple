load("@rules_python//python:py_binary.bzl", "py_binary")
load("@rules_python//python:py_library.bzl", "py_library")
load("@rules_python//python:py_test.bzl", "py_test")

licenses(["notice"])

# Encodes entitlements as DER (TN3125) byte-compatibly with /usr/bin/derq, so
# the __ents_der section of simulator binaries can be produced on any host.
# Opt-in through --features=apple.portable_derq; Xcode's derq stays the default.
py_binary(
    name = "derq",
    srcs = ["derq.py"],
    python_version = "PY3",
    srcs_version = "PY3",
    visibility = [
        "//apple/internal:__pkg__",
    ],
    deps = [":derq_lib"],
)

py_library(
    name = "derq_lib",
    srcs = [
        "__init__.py",
        "derq.py",
    ],
    srcs_version = "PY3",
)

py_test(
    name = "derq_unittest",
    srcs = ["derq_unittest.py"],
    python_version = "PY3",
    srcs_version = "PY3",
    deps = [":derq_lib"],
)
