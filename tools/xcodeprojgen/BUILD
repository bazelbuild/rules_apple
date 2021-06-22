licenses(["notice"])

exports_files(glob(["*.sh", "*.py"]), visibility = ["//visibility:public"])

py_binary(
    name = "xcodeprojgen",
    srcs = ["xcodeprojgen.py"],
    python_version = "PY3",
    srcs_version = "PY3",
    visibility = ["//visibility:public"],
)