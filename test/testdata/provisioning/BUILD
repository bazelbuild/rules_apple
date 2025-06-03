package(
    default_visibility = [
        "//test:__subpackages__",
    ],
)

licenses(["notice"])

alias(
    name = "integration_testing_ios.mobileprovision",
    actual = "integration_testing_unencoded_ios.mobileprovision",
)

alias(
    name = "integration_testing_macos.provisionprofile",
    actual = "integration_testing_unencoded_macos.provisionprofile",
)

alias(
    name = "integration_testing_tvos.mobileprovision",
    actual = "integration_testing_unencoded_tvos.mobileprovision",
)

alias(
    name = "integration_testing_visionos.mobileprovision",
    actual = "integration_testing_unencoded_visionos.mobileprovision",
)

exports_files(
    [
        "integration_testing_unencoded_ios.mobileprovision",
        "integration_testing_unencoded_macos.provisionprofile",
        "integration_testing_unencoded_tvos.mobileprovision",
        "integration_testing_unencoded_visionos.mobileprovision",
    ],
    visibility = [
        "//test:__subpackages__",
    ],
)
