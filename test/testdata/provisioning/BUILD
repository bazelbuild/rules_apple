load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load(
    "//test/testdata/provisioning:unencoded_provisioning_profile.bzl",
    "unencoded_provisioning_profile",
)

package(
    default_visibility = [
        "//test:__subpackages__",
    ],
)

licenses(["notice"])

bzl_library(
    name = "unencoded_provisioning_profile",
    srcs = ["unencoded_provisioning_profile.bzl"],
    visibility = ["//visibility:private"],
)

alias(
    name = "integration_testing_ios.mobileprovision",
    actual = "integration_testing_unencoded_ios.mobileprovision",
)

unencoded_provisioning_profile(
    name = "integration_testing_unencoded_ios_no_get_task_allow.mobileprovision",
    entitlements_string_lists = {
        "keychain-access-groups": ["FOOBARBAZ1.*"],
    },
    get_task_allow = "None",
)

alias(
    name = "integration_testing_ios_no_get_task_allow.mobileprovision",
    actual = "integration_testing_unencoded_ios_no_get_task_allow.mobileprovision",
)

unencoded_provisioning_profile(
    name = "integration_testing_unencoded_ios_keychain_access_groups.mobileprovision",
    entitlements_string_lists = {
        "keychain-access-groups": ["FOOBARBAZ1.*"],
    },
)

alias(
    name = "integration_testing_ios_keychain_access_groups.mobileprovision",
    actual = "integration_testing_unencoded_ios_keychain_access_groups.mobileprovision",
)

unencoded_provisioning_profile(
    name = "integration_testing_unencoded_ios_pass_type_identifiers.mobileprovision",
    entitlements_string_lists = {
        "com.apple.developer.pass-type-identifiers": ["FOOBARBAZ1.*"],
    },
)

alias(
    name = "integration_testing_ios_pass_type_identifiers.mobileprovision",
    actual = "integration_testing_unencoded_ios_pass_type_identifiers.mobileprovision",
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
