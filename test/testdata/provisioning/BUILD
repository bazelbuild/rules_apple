package(
    default_visibility = [
        "//test:__subpackages__",
    ],
)

licenses(["notice"])

exports_files(
    [
        "integration_testing_ios.mobileprovision",
        "integration_testing_macos.provisionprofile",
        "integration_testing_tvos.mobileprovision",
        "integration_testing_visionos.mobileprovision",
    ],
    visibility = [
        "//test:__subpackages__",
    ],
)

filegroup(
    name = "integration_testing_profiles",
    srcs = [
        "BUILD",
        "integration_testing_ios.mobileprovision",
        "integration_testing_macos.provisionprofile",
        "integration_testing_tvos.mobileprovision",
        "integration_testing_visionos.mobileprovision",
    ],
)
