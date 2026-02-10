load("@rules_python//python:py_binary.bzl", "py_binary")
load("//apple/testing/simulator_pool:create_simulator_pool.bzl", "create_simulator_pool")

exports_files(["create_simulator_pool.template.sh"])

create_simulator_pool(
    name = "create_simulator_pool",
    device_type = "iPhone 15 Pro",
    os_version = "18.3",
    pool_size = 3,
    server_port = 50051,
)

py_binary(
    name = "create_simulator_pool_tool",
    srcs = [
        "create_simulator_pool_tool.py",
    ],
    python_version = "PY3",
    srcs_version = "PY3",
    deps = [
        "//apple/testing/default_runner:simulator_utils",
    ],
)

py_binary(
    name = "simulator_pool_server",
    srcs = [
        "simulator_pool_server.py",
    ],
    python_version = "PY3",
    srcs_version = "PY3",
    deps = [
        "//apple/testing/default_runner:simulator_utils",
    ],
)

py_binary(
    name = "simulator_pool_client",
    srcs = [
        "simulator_pool_client.py",
    ],
    python_version = "PY3",
    srcs_version = "PY3",
    visibility = ["//visibility:public"],
)
