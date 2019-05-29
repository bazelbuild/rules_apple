# This file exists to override the @bazel_tools function_transition_whitelist
# since it will only be available to be consumed by clients starting on Bazel
# 0.27.

# TODO(b/133755914): Delete this BUILD file and use
# @bazel_tools//tools/whitelists/function_trasition_whitelist from
# transition-using rules instead.

licenses(["notice"])

package_group(
    name = "function_transition_whitelist",
    packages = ["//test/..."],
)
