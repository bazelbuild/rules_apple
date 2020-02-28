load(
    "//apple:apple.bzl",
    "apple_dynamic_framework_import",
    "apple_static_framework_import",
)

# Public only because these are used by the integration tests from generated
# workspaces. Please no not depend on them as they can change at any time.
package(default_visibility = ["//visibility:public"])

licenses(["notice"])

# To update the binaries and headers for these framework imports, please run
# `update_frameworks.sh` script in this directory.

apple_dynamic_framework_import(
    name = "iOSDynamicFramework",
    framework_imports = glob(["iOSDynamicFramework.framework/**"]),
)

apple_static_framework_import(
    name = "iOSStaticFramework",
    framework_imports = glob(["iOSStaticFramework.framework/**"]),
)

filegroup(
    name = "swift_sources",
    srcs = glob(["*.swift"]),
)

filegroup(
    name = "ios_frameworks",
    srcs = glob(
        [
            "iOSDynamicFramework.framework/**",
            "iOSStaticFramework.framework/**",
        ],
    ) + [
        "BUILD",
    ],
)
