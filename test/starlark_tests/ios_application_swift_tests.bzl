# Copyright 2026 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Swift-specific `ios_application` bundling tests."""

load(
    "//apple/build_settings:build_settings.bzl",
    "build_settings_labels",
)
load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
)

visibility("private")

def ios_application_swift_test_suite(name):
    """Test suite for ios_application Swift bundling.

    Args:
      name: the base name to be used in things created by this macro
    """

    archive_contents_test(
        name = "{}_simulator_build_has_swift_libs_in_frameworks_dir_only_test".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libswiftCore.dylib",
        ],
        not_contains = [
            "$ARCHIVE_ROOT/SwiftSupport/iphonesimulator/libswiftCore.dylib",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_swift_dep",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_device_build_has_swift_libs_in_frameworks_and_support_dirs_test".format(name),
        build_type = "device",
        contains = [
            "$ARCHIVE_ROOT/SwiftSupport/iphoneos/libswiftCore.dylib",
            "$BUNDLE_ROOT/Frameworks/libswiftCore.dylib",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:ipa_with_app_with_swift_dep",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_device_build_can_disable_swift_support_dir_test".format(name),
        build_type = "device",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libswiftCore.dylib",
        ],
        build_settings = {
            build_settings_labels.package_swift_support: "False",
        },
        not_contains = [
            "$ARCHIVE_ROOT/SwiftSupport/iphoneos/libswiftCore.dylib",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_swift_dep",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_simulator_build_has_swift_libs_through_indirect_deps_test".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libswiftCore.dylib",
        ],
        not_contains = [
            "$ARCHIVE_ROOT/SwiftSupport/iphonesimulator/libswiftCore.dylib",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_indirect_swift_dep",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_device_build_has_swift_libs_through_indirect_deps_test".format(name),
        build_type = "device",
        contains = [
            "$ARCHIVE_ROOT/SwiftSupport/iphoneos/libswiftCore.dylib",
            "$BUNDLE_ROOT/Frameworks/libswiftCore.dylib",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:ipa_with_app_with_indirect_swift_dep",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_swift_builds_with_asan_simulator_test".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.asan_iossim_dynamic.dylib",
        ],
        sanitizer = "asan",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_swift_dep",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_swift_builds_with_asan_device_test".format(name),
        build_type = "device",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.asan_ios_dynamic.dylib",
        ],
        sanitizer = "asan",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_swift_dep",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_swift_builds_with_tsan_simulator_test".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.tsan_iossim_dynamic.dylib",
        ],
        sanitizer = "tsan",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_swift_dep",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_swift_builds_with_ubsan_simulator_test".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.ubsan_iossim_dynamic.dylib",
        ],
        sanitizer = "ubsan",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_swift_dep",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_swift_builds_with_ubsan_device_test".format(name),
        build_type = "device",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.ubsan_ios_dynamic.dylib",
        ],
        sanitizer = "ubsan",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_swift_dep",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_swift_builds_with_include_clang_rt_asan_simulator_test".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.asan_iossim_dynamic.dylib",
        ],
        target_features = ["include_clang_rt"],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_swift_dep_and_asan_linkopt",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_swift_builds_with_include_clang_rt_asan_device_test".format(name),
        build_type = "device",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.asan_ios_dynamic.dylib",
        ],
        target_features = ["include_clang_rt"],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_swift_dep_and_asan_linkopt",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_swift_builds_with_include_clang_rt_tsan_simulator_test".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.tsan_iossim_dynamic.dylib",
        ],
        target_features = ["include_clang_rt"],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_swift_dep_and_tsan_linkopt",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_swift_builds_with_include_clang_rt_ubsan_simulator_test".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.ubsan_iossim_dynamic.dylib",
        ],
        target_features = ["include_clang_rt"],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_swift_dep_and_ubsan_linkopt",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_swift_builds_with_include_clang_rt_ubsan_device_test".format(name),
        build_type = "device",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.ubsan_ios_dynamic.dylib",
        ],
        target_features = ["include_clang_rt"],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_swift_dep_and_ubsan_linkopt",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_swift_builds_with_include_main_thread_checker_simulator_test".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libMainThreadChecker.dylib",
        ],
        target_features = ["apple.include_main_thread_checker"],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_swift_dep",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_swift_builds_with_include_main_thread_checker_device_test".format(name),
        build_type = "device",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libMainThreadChecker.dylib",
        ],
        target_features = ["apple.include_main_thread_checker"],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_swift_dep",
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
