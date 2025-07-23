# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""apple_bundle_version Starlark tests."""

load(
    "//test/starlark_tests/rules:analysis_failure_message_test.bzl",
    "analysis_failure_message_test",
)
load(
    "//test/starlark_tests/rules:analysis_target_actions_test.bzl",
    "analysis_target_actions_test",
)
load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
)
load(
    ":common.bzl",
    "common",
)

visibility("private")

def ios_application_resources_test_suite(name):
    """Test suite for apple_bundle_version.

    Args:
      name: the base name to be used in things created by this macro
    """

    # Tests that various nonlocalized resource types are bundled correctly with the application (at
    # the top-level, rather than inside an .lproj directory)and that they're built when the app
    # specifies that it's to be built exclusively for iPhone.
    archive_contents_test(
        name = "{}_non_localized_processed_resources_iphone_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        contains = [
            "$BUNDLE_ROOT/unversioned_datamodel.mom",
            "$BUNDLE_ROOT/versioned_datamodel.momd/v1.mom",
            "$BUNDLE_ROOT/versioned_datamodel.momd/v2.mom",
            "$BUNDLE_ROOT/versioned_datamodel.momd/VersionInfo.plist",
            "$BUNDLE_ROOT/mapping_model.cdm",
            "$BUNDLE_ROOT/storyboard_ios.storyboardc/",
            "$BUNDLE_ROOT/sample.png",
            "$BUNDLE_ROOT/view_ios.nib",
        ],
        is_binary_plist = [
            "$BUNDLE_ROOT/nonlocalized.strings",
            "$BUNDLE_ROOT/nonlocalized.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        tags = [name],
    )

    # Tests that various nonlocalized resource types are bundled correctly with the application
    # (at the top-level, rather than inside an .lproj directory) and that they're built when the app
    # specifies that it's to be built exclusively for iPad.
    archive_contents_test(
        name = "{}_non_localized_processed_resources_ipad_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        contains = [
            "$BUNDLE_ROOT/unversioned_datamodel.mom",
            "$BUNDLE_ROOT/versioned_datamodel.momd/v1.mom",
            "$BUNDLE_ROOT/versioned_datamodel.momd/v2.mom",
            "$BUNDLE_ROOT/versioned_datamodel.momd/VersionInfo.plist",
            "$BUNDLE_ROOT/mapping_model.cdm",
            "$BUNDLE_ROOT/storyboard_ios.storyboardc/",
            "$BUNDLE_ROOT/sample.png",
            "$BUNDLE_ROOT/view_ios.nib",
        ],
        is_binary_plist = [
            "$BUNDLE_ROOT/nonlocalized.strings",
            "$BUNDLE_ROOT/nonlocalized.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:ipad_only_app",
        tags = [name],
    )

    # Tests that various xib files can be used as launch_storyboards. As of Xcode 14.3.1, xibs
    # targeting the oldest supported iOS output a single binary nib supporting iPad and iPhones,
    # unlike past versions that could provide a "nib bundle" with separate binary nibs for iPad and
    # iPhone.
    archive_contents_test(
        name = "{}_xib_as_launchscreen_test".format(name),
        build_type = "device",
        contains = [
            "$BUNDLE_ROOT/launch_screen_ios.nib",
        ],
        not_contains = [
            "$BUNDLE_ROOT/launch_screen_ios~iphone.nib/runtime.nib",
            "$BUNDLE_ROOT/launch_screen_ios~ipad.nib/runtime.nib",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_launch_storyboard_as_xib",
        tags = [name],
    )

    # Tests that empty strings files can be processed.
    archive_contents_test(
        name = "{}_empty_strings_files_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        is_binary_plist = [
            "$BUNDLE_ROOT/empty.strings",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        tags = [name],
    )

    # Tests bundling a Resources folder as top level should fail with a nice message.
    analysis_failure_message_test(
        name = "{}_invalid_top_level_directory_fail_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_structured_resources_in_resources_folder",
        expected_error = "For ios bundles, the following top level directories are invalid (case-insensitive): resources",
        tags = [name],
    )

    # Tests bundling generated resources within structured resources should fail with a nice
    # message.
    analysis_failure_message_test(
        name = "{}_invalid_resources_in_structured_resources".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_processed_resources_in_structured_resources",
        expected_error = "Error: Found ignored resource providers for target " +
                         "//test/starlark_tests/resources:processed_resources_in_structured_resources. " +
                         "Check that there are no processed resource targets being referenced by " +
                         "structured_resources.",
        tags = [name],
    )

    # Tests that various localized resource types are bundled correctly with the
    # application (preserving their parent .lproj directory).
    archive_contents_test(
        name = "{}_localized_processed_resources_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        contains = [
            "$BUNDLE_ROOT/it.lproj/storyboard_ios.storyboardc/",
            "$BUNDLE_ROOT/it.lproj/view_ios.nib",
        ],
        is_binary_plist = [
            "$BUNDLE_ROOT/it.lproj/localized.strings",
            "$BUNDLE_ROOT/it.lproj/localized.plist",
        ],
        plist_test_file = "$BUNDLE_ROOT/Info.plist",
        plist_test_values = {
            "CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconFiles:0": "app_icon60x60",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        tags = [name],
    )

    # Tests that the app icons and launch images are bundled with the application
    # and that the partial Info.plist produced by actool is merged into the final
    # plist.
    archive_contents_test(
        name = "{}_app_icons_and_launch_images_plist_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_launch_images",
        contains = [
            "$BUNDLE_ROOT/app_icon60x60@2x.png",
            "$BUNDLE_ROOT/launch_image-700-568h@2x.png",
            "$BUNDLE_ROOT/launch_image-700-Portrait@2x~ipad.png",
        ],
        plist_test_file = "$CONTENT_ROOT/Info.plist",
        plist_test_values = {
            "CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconFiles:0": "app_icon60x60",
            "UILaunchImages:0:UILaunchImageName": "launch_image-700",
            "UILaunchImages:0:UILaunchImageOrientation": "Portrait",
            "UILaunchImages:0:UILaunchImageSize": "{320, 480}",
        },
        tags = [name],
    )

    # Tests the new icon composer bundles for Xcode 26.
    archive_contents_test(
        name = "{}_icon_composer_app_icons_plist_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_icon_bundle",
        contains = [
            "$BUNDLE_ROOT/Assets.car",
        ],
        plist_test_file = "$CONTENT_ROOT/Info.plist",
        plist_test_values = {
            "CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName": "app_icon",
        },
        tags = [
            name,
        ],
    )

    # Tests the new icon composer bundles for Xcode 26, along with a set of asset catalog icons.
    archive_contents_test(
        name = "{}_icon_composer_and_asset_catalog_app_icons_plist_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_icon_bundle_and_xcassets_app_icons",
        contains = [
            "$BUNDLE_ROOT/app_icon76x76@2x~ipad.png",
            "$BUNDLE_ROOT/app_icon60x60@2x.png",
        ],
        plist_test_file = "$CONTENT_ROOT/Info.plist",
        plist_test_values = {
            "CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconFiles:0": "app_icon60x60",
            "CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName": "app_icon",
        },
        tags = [
            name,
        ],
    )

    # Tests that icon composer icons must be provided when the minimum_os_version is 26.0 or higher.
    analysis_failure_message_test(
        name = "{}_legacy_app_icons_for_minimum_os_version_26_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_xcassets_for_ios_26",
        expected_error = """
Legacy .appiconset files should not be used on iOS/macOS/watchOS 26+.

These platforms prefer Icon Composer .icon bundles. .appiconset files are only needed for rendering icons in iOS/macOS/watchOS prior to 26.

Found the following legacy .appiconset files: """,
        tags = [
            name,
        ],
    )

    # TODO: b/433727264 - Create a new test with archive_contents_test once Xcode 26 beta 4 is
    # widely used by clients with the following target:
    # //test/starlark_tests/targets_under_test/ios:app_with_icon_bundle_only_for_low_minimum_os_version

    # Tests that an app with alternate app icons that also provides Icon Composer icon bundles will
    # fail if every icon bundle is not backed by a legacy .appiconset app icon.
    analysis_failure_message_test(
        name = "{}_alt_app_icons_with_incomplete_icon_bundle_coverage_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_alternate_app_icons_with_incomplete_icon_bundle_coverage",
        expected_error = """
Among the primary and alternate app icons provided, the following are missing resources to support Apple OSes prior to 26 and the new Apple OS 26 icon features for iOS/macOS/watchOS:

Found the following xcassets app icons by name missing Xcode 26 icon bundles:
app_icon-bazel
""",
        tags = [
            name,
        ],
    )

    # Tests that an app with alternate app icons that also provides Icon Composer icon bundles will
    # fail if every legacy .appiconset app icon is not backed by an Icon Composer icon bundle.
    analysis_failure_message_test(
        name = "{}_alt_app_icons_with_incomplete_xcassets_app_icons_coverage_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_alternate_app_icons_with_isolated_icon_bundles",
        expected_error = """
Among the primary and alternate app icons provided, the following are missing resources to support Apple OSes prior to 26 and the new Apple OS 26 icon features for iOS/macOS/watchOS:

Found the following icon bundles by name missing legacy xcassets app icons:
app_icon-dupe
""",
        tags = [
            name,
        ],
    )

    # Tests the new icon composer bundles for Xcode 26 with a set of asset catalog icons can be used
    # with alternate app icons.
    archive_contents_test(
        name = "{}_icon_composer_and_asset_catalog_app_icons_with_alternate_app_icons_plist_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_alternate_app_icons_with_full_icon_bundle_coverage",
        contains = [
            "$BUNDLE_ROOT/app_icon76x76@2x~ipad.png",
            "$BUNDLE_ROOT/app_icon60x60@2x.png",
            "$BUNDLE_ROOT/app_icon-bazel60x60@2x.png",
            "$BUNDLE_ROOT/app_icon-bazel76x76@2x~ipad.png",
        ],
        plist_test_file = "$CONTENT_ROOT/Info.plist",
        plist_test_values = {
            "CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconFiles:0": "app_icon60x60",
            "CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName": "app_icon",
            "CFBundleIcons:CFBundleAlternateIcons:app_icon-bazel:CFBundleIconFiles:0": "app_icon-bazel60x60",
        },
        tags = [
            name,
        ],
    )

    # Tests that icon composer icons will be flagged when building against Xcode 16 instead of 26.
    analysis_failure_message_test(
        name = "{}_test_xcode_16_with_icon_composer_icons_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_icon_bundle",
        expected_error = """
Found Icon Composer .icon bundles among the assigned app_icons. These are only supported on Xcode 26 or later.

Found the following: """,
        tags = [
            name,
        ],
    )

    # Tests that the launch storyboard is bundled with the application and that
    # the bundler inserts the correct key/value into Info.plist.
    archive_contents_test(
        name = "{}_launch_storyboard_test".format(name),
        build_type = "device",
        contains = [
            "$BUNDLE_ROOT/launch_screen_ios.storyboardc/",
        ],
        plist_test_file = "$CONTENT_ROOT/Info.plist",
        plist_test_values = {
            "UILaunchStoryboardName": "launch_screen_ios",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        tags = [name],
    )

    # Tests that when a launch storyboard is not bundled with the application that the bundler
    # inserts the correct key/value into Info.plist.
    archive_contents_test(
        name = "{}_default_launch_screen_test".format(name),
        build_type = "device",
        not_contains = [
            "$BUNDLE_ROOT/launch_screen_ios.storyboardc/",
        ],
        plist_test_file = "$CONTENT_ROOT/Info.plist",
        plist_test_values = {
            "UILaunchScreen": "*",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_default_launch_screen",
        tags = [name],
    )

    # Test that when alternate app icons are declared alongside the primary app icon, that they are
    # bundled in expected locations with the app, that they are embedded within the plist
    # referencing their file names, and that they are also bundled within the asset catalog for the
    # application.
    archive_contents_test(
        name = "{}_alt_app_icons_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_alternate_app_icons",
        contains = [
            "$BUNDLE_ROOT/app_icon60x60@2x.png",
            "$BUNDLE_ROOT/app_icon76x76@2x~ipad.png",
            "$BUNDLE_ROOT/app_icon-bazel60x60@2x.png",
            "$BUNDLE_ROOT/app_icon-bazel76x76@2x~ipad.png",
        ],
        plist_test_file = "$CONTENT_ROOT/Info.plist",
        plist_test_values = {
            "CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconFiles:0": "app_icon",
            "CFBundleIcons:CFBundleAlternateIcons:CFBundleIconFiles:0": "app_icon-bazel",
        },
        text_test_file = "$BUNDLE_ROOT/Assets.car",
        text_test_values = ["app_icon", "app_icon-bazel"],
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_alt_app_icons_missing_primary_icon_name_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_alternate_app_icons_without_primary",
        expected_error = """
Found multiple app icons among the asset catalogs with no primary_app_icon assigned.

If you intend to assign multiple app icons to this target, please declare which of these is intended
to be the primary app icon with the primary_app_icon attribute on the rule itself.

Target was assigned the following app icons: [
  third_party/bazel_rules/rules_apple/test/starlark_tests/resources/app_icons_with_alts_ios.xcassets/app_icon-bazel.appiconset,
  third_party/bazel_rules/rules_apple/test/starlark_tests/resources/app_icons_with_alts_ios.xcassets/app_icon.appiconset
]
""",
        tags = [name],
    )

    # Test that when the primary app icon has dark mode and tinted variants, that the legacy icons
    # are still bundled in expected locations with the app, that the legacy icons are embedded
    # within the plist referencing their file names, and that they are also bundled within the asset
    # catalog for the application.
    archive_contents_test(
        name = "{}_dark_and_tinted_app_icons_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_dark_and_tinted_app_icons",
        contains = [
            "$BUNDLE_ROOT/app_icon60x60@2x.png",
            "$BUNDLE_ROOT/app_icon76x76@2x~ipad.png",
        ],
        plist_test_file = "$CONTENT_ROOT/Info.plist",
        plist_test_values = {
            "CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconFiles:0": "app_icon",
        },
        text_test_file = "$BUNDLE_ROOT/Assets.car",
        text_test_values = [
            "Bazel_logo.png",
            "Bazel_dark_logo.png",
            "Bazel_tinted_logo.png",
            "UIAppearanceDark",
            "ISAppearanceTintable",
        ],
        tags = [
            name,
        ],
    )

    # Tests that apple_bundle_import files are bundled correctly with the application.
    archive_contents_test(
        name = "{}_apple_bundle_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        is_binary_plist = [
            "$BUNDLE_ROOT/basic.bundle/should_be_binary.strings",
            "$BUNDLE_ROOT/basic.bundle/should_be_binary.plist",
        ],
        contains = [
            "$BUNDLE_ROOT/basic.bundle/nested/should_be_nested.strings",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        tags = [name],
    )

    # Tests that apple_bundle_import files are bundled correctly with the
    # application if the files have an owner-relative path that begins with
    # something other than the bundle name (for example, "foo/Bar.bundle/..."
    # instead of "Bar.bundle/..."). The path inside the bundle should start from the
    # .bundle segment, not earlier.
    archive_contents_test(
        name = "{}_nested_apple_bundle_test".format(name),
        build_type = "simulator",
        compilation_mode = "opt",
        is_binary_plist = [
            "$BUNDLE_ROOT/nested.bundle/should_be_binary.strings",
        ],
        contains = [
            "$BUNDLE_ROOT/nested.bundle/nested/should_be_nested.strings",
        ],
        not_contains = [
            "$BUNDLE_ROOT/nested_bundle/nested.bundle/should_be_binary.strings",
            "$BUNDLE_ROOT/nested_bundle/nested.bundle/nested/should_be_nested.strings",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        tags = [name],
    )

    # Tests that apple_resource_bundle resources are compiled and bundled correctly
    # with the application. This test uses a bundle library with many types of
    # resources, both localized and nonlocalized, and also a nested bundle.
    archive_contents_test(
        name = "{}_apple_resource_bundle_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        plist_test_file = "$CONTENT_ROOT/bundle_library_ios.bundle/Info.plist",
        plist_test_values = {
            "CFBundleIdentifier": "org.bazel.bundle-library-ios",
            "CFBundleName": "bundle_library_ios.bundle",
            "CFBundlePackageType": "BNDL",
            "TargetName": "bundle_library_ios",
        },
        contains = [
            "$BUNDLE_ROOT/bundle_library_ios.bundle/basic.bundle/basic_bundle.txt",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/it.lproj/localized.strings",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/it.lproj/localized.txt",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/it.lproj/storyboard_ios.storyboardc/",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/it.lproj/view_ios.nib",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/mapping_model.cdm",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/nonlocalized_resource.txt",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/storyboard_ios.storyboardc/",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/unversioned_datamodel.mom",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/versioned_datamodel.momd/v1.mom",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/versioned_datamodel.momd/v2.mom",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/versioned_datamodel.momd/VersionInfo.plist",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/view_ios.nib",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/structured/nested.txt",
        ],
        is_binary_plist = [
            "$BUNDLE_ROOT/bundle_library_ios.bundle/structured/generated.strings",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/structured/should_be_binary.plist",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/structured/should_be_binary.strings",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        tags = [name],
    )

    # Tests that apple_resource_bundle resources are compiled and bundled correctly
    # with the application. This test uses a bundle library with many types of
    # resources, both localized and nonlocalized, and also a nested bundle.
    archive_contents_test(
        name = "{}_apple_resource_bundle_depending_on_AppleResourceInfo_and_DefaultInfo_rule_test".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/resource_bundle.bundle/custom_apple_resource_info.out",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        tags = [name],
    )

    # Tests that structured processed generated strings have correct values.
    archive_contents_test(
        name = "{}_generated_stromgs_test".format(name),
        build_type = "simulator",
        plist_test_file = "$CONTENT_ROOT/bundle_library_ios.bundle/structured/generated.strings",
        plist_test_values = {
            "generated_structured_string": "I like turtles too!",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        tags = [name],
    )

    # Tests that the Settings.bundle is bundled correctly with the application.
    archive_contents_test(
        name = "{}_settings_bundle_test".format(name),
        build_type = "simulator",
        compilation_mode = "opt",
        plist_test_file = "$BUNDLE_ROOT/Settings.bundle/it.lproj/Root.strings",
        plist_test_values = {
            "Foo": "Pippo",
        },
        is_not_binary_plist = [
            "$BUNDLE_ROOT/Settings.bundle/Root.plist",
            "$BUNDLE_ROOT/Settings.bundle/it.lproj/Root.strings",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        tags = [name],
    )

    # Tests that resources generated by a genrule, which produces a separate copy
    # for each split configuration, are properly deduped before being processed.
    archive_contents_test(
        name = "{}_deduplicate_generated_resources_test".format(name),
        build_type = "simulator",
        plist_test_file = "$CONTENT_ROOT/bundle_library_ios.bundle/generated.strings",
        plist_test_values = {
            "generated_string": "I like turtles!",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        tags = [name],
    )

    # Tests strings and plists aren't compiled in fastbuild.
    archive_contents_test(
        name = "{}_fastbuild_compilation_mode_on_strings_and_plist_files_test".format(name),
        build_type = "device",
        compilation_mode = "fastbuild",
        is_not_binary_plist = [
            "$BUNDLE_ROOT/nonlocalized.strings",
            "$BUNDLE_ROOT/nonlocalized.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        tags = [name],
    )

    # Tests strings and plists aren't compiled in dbg.
    archive_contents_test(
        name = "{}_dbg_compilation_mode_on_strings_and_plist_files_test".format(name),
        build_type = "device",
        compilation_mode = "dbg",
        is_not_binary_plist = [
            "$BUNDLE_ROOT/nonlocalized.strings",
            "$BUNDLE_ROOT/nonlocalized.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        tags = [name],
    )

    # Tests strings and plists are compiled in opt.
    archive_contents_test(
        name = "{}_opt_compilation_mode_on_strings_and_plist_files_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        is_binary_plist = [
            "$BUNDLE_ROOT/nonlocalized.strings",
            "$BUNDLE_ROOT/nonlocalized.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        tags = [name],
    )

    # This tests that 2 files which have the same target path into nested bundles
    # do not get deduplicated from the top-level bundle, as long as they are
    # different files.
    archive_contents_test(
        name = "{}_different_resource_with_same_target_path_is_not_deduped_main_app_test".format(name),
        build_type = "simulator",
        plist_test_file = "$BUNDLE_ROOT/nonlocalized.plist",
        plist_test_values = {
            "SomeKey": "Somevalue",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_fmwk",
        tags = [name],
    )
    archive_contents_test(
        name = "{}_different_resource_with_same_target_path_is_not_deduped_framework_test".format(name),
        build_type = "simulator",
        plist_test_file = "$BUNDLE_ROOT/Frameworks/fmwk.framework/nonlocalized.plist",
        plist_test_values = {
            "SomeKey": "Special framework version!",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_fmwk",
        tags = [name],
    )

    # Test that strings and plist library-defined resources have ths same outputs as if they were
    # app-defined.
    archive_contents_test(
        name = "{}_with_library_defined_strings_and_plists_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        is_binary_plist = [
            "$BUNDLE_ROOT/en.lproj/greetings.strings",
            "$BUNDLE_ROOT/fr.lproj/localized.strings",
            "$BUNDLE_ROOT/fr.lproj/localized.plist",
            "$BUNDLE_ROOT/it.lproj/localized.strings",
            "$BUNDLE_ROOT/it.lproj/localized.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_library_scoped_localized_assets",
        tags = [name],
    )

    # Test that having the same strings and plist library-defined resources referenced from two
    # different library targets will be deduplicated, and therefore will not cause issues with the
    # build.
    archive_contents_test(
        name = "{}_with_two_libraries_referencing_same_strings_and_plists_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        is_binary_plist = [
            "$BUNDLE_ROOT/en.lproj/greetings.strings",
            "$BUNDLE_ROOT/fr.lproj/localized.strings",
            "$BUNDLE_ROOT/fr.lproj/localized.plist",
            "$BUNDLE_ROOT/it.lproj/localized.strings",
            "$BUNDLE_ROOT/it.lproj/localized.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_duplicated_library_scoped_localized_assets",
        tags = [name],
    )

    # Test that having the same strings and plist library-defined resources referenced from a
    # library target and the top level target will be deduplicated, and therefore will not cause
    # issues with the build.
    archive_contents_test(
        name = "{}_with_top_level_and_library_scoped_localized_assets_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        is_binary_plist = [
            "$BUNDLE_ROOT/en.lproj/greetings.strings",
            "$BUNDLE_ROOT/fr.lproj/localized.strings",
            "$BUNDLE_ROOT/fr.lproj/localized.plist",
            "$BUNDLE_ROOT/it.lproj/localized.strings",
            "$BUNDLE_ROOT/it.lproj/localized.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_and_library_scoped_localized_assets",
        tags = [name],
    )

    # Test that raw PNG library-defined resources have ths same outputs as if they were app-defined.
    archive_contents_test(
        name = "{}_with_library_defined_launch_images_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_launch_images_from_library",
        contains = [
            "$BUNDLE_ROOT/launch_image-700-568h@2x.png",
            "$BUNDLE_ROOT/launch_image-700-Portrait@2x~ipad.png",
        ],
        tags = [name],
    )

    # Test that having the same raw PNG library-defined resources referenced from two different
    # library targets will be deduplicated, and therefore will not cause issues with the build.
    archive_contents_test(
        name = "{}_with_two_libraries_referencing_same_launch_images_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_duplicated_library_scoped_launch_images",
        contains = [
            "$BUNDLE_ROOT/launch_image-700-568h@2x.png",
            "$BUNDLE_ROOT/launch_image-700-Portrait@2x~ipad.png",
        ],
        tags = [name],
    )

    # Test that having the same library-defined raw PNG resources referenced from a library target
    # and the top level target will be deduplicated, and therefore will not cause issues with the
    # build.
    archive_contents_test(
        name = "{}_with_top_level_and_library_scoped_launch_images_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_and_library_scoped_launch_images",
        contains = [
            "$BUNDLE_ROOT/launch_image-700-568h@2x.png",
            "$BUNDLE_ROOT/launch_image-700-Portrait@2x~ipad.png",
        ],
        tags = [name],
    )

    # Tests that multiple references to a structured resource will be successfully deduplicated.
    archive_contents_test(
        name = "{}_with_multiple_refs_to_same_structured_resources_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_multiple_refs_to_same_structured_resources",
        is_binary_plist = [
            "$BUNDLE_ROOT/Another.plist",
        ],
        tags = [name],
    )

    # Tests that multiple resource bundles with shared resources have all resources accounted for.
    archive_contents_test(
        name = "{}_with_multiple_resource_bundles_with_shared_resources_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_multiple_resource_bundles_with_shared_resources",
        contains = [
            "$BUNDLE_ROOT/bundle_library_ios.bundle/basic.bundle/basic_bundle.txt",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/it.lproj/localized.strings",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/it.lproj/localized.txt",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/it.lproj/storyboard_ios.storyboardc/",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/it.lproj/view_ios.nib",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/mapping_model.cdm",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/nonlocalized_resource.txt",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/storyboard_ios.storyboardc/",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/unversioned_datamodel.mom",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/versioned_datamodel.momd/v1.mom",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/versioned_datamodel.momd/v2.mom",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/versioned_datamodel.momd/VersionInfo.plist",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/view_ios.nib",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/structured/nested.txt",
            "$BUNDLE_ROOT/bundle_library_apple.bundle/basic.bundle/basic_bundle.txt",
            "$BUNDLE_ROOT/bundle_library_apple.bundle/it.lproj/localized.strings",
            "$BUNDLE_ROOT/bundle_library_apple.bundle/it.lproj/localized.txt",
            "$BUNDLE_ROOT/bundle_library_apple.bundle/mapping_model.cdm",
            "$BUNDLE_ROOT/bundle_library_apple.bundle/nonlocalized_resource.txt",
            "$BUNDLE_ROOT/bundle_library_apple.bundle/unversioned_datamodel.mom",
            "$BUNDLE_ROOT/bundle_library_apple.bundle/versioned_datamodel.momd/v1.mom",
            "$BUNDLE_ROOT/bundle_library_apple.bundle/versioned_datamodel.momd/v2.mom",
            "$BUNDLE_ROOT/bundle_library_apple.bundle/versioned_datamodel.momd/VersionInfo.plist",
            "$BUNDLE_ROOT/bundle_library_apple.bundle/structured/nested.txt",
        ],
        is_binary_plist = [
            "$BUNDLE_ROOT/bundle_library_ios.bundle/structured/generated.strings",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/structured/should_be_binary.plist",
            "$BUNDLE_ROOT/bundle_library_ios.bundle/structured/should_be_binary.strings",
            "$BUNDLE_ROOT/bundle_library_apple.bundle/structured/generated.strings",
            "$BUNDLE_ROOT/bundle_library_apple.bundle/structured/should_be_binary.plist",
            "$BUNDLE_ROOT/bundle_library_apple.bundle/structured/should_be_binary.strings",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_with_resource_bundle_with_structured_resource_group_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_resource_bundle_with_structured_resource_group",
        contains = [
            "$BUNDLE_ROOT/resource_bundle_with_structured_resource_group.bundle/Another.plist",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_with_resource_group_with_resource_bundle".format(name),
        build_type = "device",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_resource_group_with_resource_bundle",
        contains = [
            "$BUNDLE_ROOT/resource_bundle.bundle/custom_apple_resource_info.out",
            "$BUNDLE_ROOT/resource_bundle.bundle/Info.plist",
        ],
        tags = [name],
    )

    # Tests xcasset tool is passed the correct arguments.
    analysis_target_actions_test(
        name = "{}_xcasset_actool_argv".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        target_mnemonic = "AssetCatalogCompile",
        expected_argv = [
            "xctoolrunner actool --compile",
            "--minimum-deployment-target " + common.min_os_ios.baseline,
            "--platform iphonesimulator",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_contains_resources_from_swift_library_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_swift_library_scoped_resources",
        contains = [
            # Verify that nonlocalized processed resources are present.
            "$BUNDLE_ROOT/Assets.car",
            "$BUNDLE_ROOT/unversioned_datamodel.mom",
            "$BUNDLE_ROOT/versioned_datamodel.momd/v1.mom",
            "$BUNDLE_ROOT/versioned_datamodel.momd/v2.mom",
            "$BUNDLE_ROOT/versioned_datamodel.momd/VersionInfo.plist",
            "$BUNDLE_ROOT/storyboard_ios.storyboardc/",
            "$BUNDLE_ROOT/nonlocalized.strings",
            "$BUNDLE_ROOT/view_ios.nib",
            # Verify nonlocalized unprocessed resources are present.
            "$BUNDLE_ROOT/nonlocalized_resource.txt",
            "$BUNDLE_ROOT/structured/nested.txt",
            # Verify localized resources are present.
            "$BUNDLE_ROOT/it.lproj/storyboard_ios.storyboardc/",
            "$BUNDLE_ROOT/it.lproj/localized.strings",
            "$BUNDLE_ROOT/it.lproj/view_ios.nib",
            # Verify localized unprocessed resources are present.
            "$BUNDLE_ROOT/it.lproj/localized.txt",
        ],
        # Verify that both image set names show up in the asset catalog. (The file
        # format is a black box to us, but we can at a minimum grep the name out
        # because it's visible in the raw bytes).
        text_test_file = "$BUNDLE_ROOT/Assets.car",
        text_test_values = ["star_iphone"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_contains_resources_from_transitive_swift_library_test".format(name),
        build_type = "simulator",
        contains = [
            # Verify that nonlocalized processed resources are present.
            "$BUNDLE_ROOT/Assets.car",
            "$BUNDLE_ROOT/unversioned_datamodel.mom",
            "$BUNDLE_ROOT/versioned_datamodel.momd/v1.mom",
            "$BUNDLE_ROOT/versioned_datamodel.momd/v2.mom",
            "$BUNDLE_ROOT/versioned_datamodel.momd/VersionInfo.plist",
            "$BUNDLE_ROOT/storyboard_ios.storyboardc/",
            "$BUNDLE_ROOT/nonlocalized.strings",
            "$BUNDLE_ROOT/view_ios.nib",
            # Verify nonlocalized unprocessed resources are present.
            "$BUNDLE_ROOT/nonlocalized_resource.txt",
            "$BUNDLE_ROOT/structured/nested.txt",
            # Verify localized resources are present.
            "$BUNDLE_ROOT/it.lproj/storyboard_ios.storyboardc/",
            "$BUNDLE_ROOT/it.lproj/localized.strings",
            "$BUNDLE_ROOT/it.lproj/view_ios.nib",
            # Verify localized unprocessed resources are present.
            "$BUNDLE_ROOT/it.lproj/localized.txt",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_transitive_swift_library_scoped_resources",
        tags = [name],
    )

    # Tests that swift_library targets have their intermediate compiled storyboards
    # distinguished by module so that multiple link actions don't try to generate
    # the same output.
    archive_contents_test(
        name = "{}_contains_compiled_storyboards_from_transitive_swift_library_test".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/storyboard_ios.storyboardc/",
            "$BUNDLE_ROOT/it.lproj/storyboard_ios.storyboardc/",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_transitive_swift_libraries_with_storyboards",
        tags = [name],
    )

    # Tests that multiple swift_library targets can propagate asset catalogs and
    # that they are all merged into a single Assets.car without conflicts.
    archive_contents_test(
        name = "{}_contains_merged_asset_catalog_from_transitive_swift_library_test".format(name),
        build_type = "simulator",
        contains = ["$BUNDLE_ROOT/Assets.car"],
        # Verify that both image set names show up in the asset catalog. (The file
        # format is a black box to us, but we can at a minimum grep the name out
        # because it's visible in the raw bytes).
        text_test_file = "$BUNDLE_ROOT/Assets.car",
        text_test_values = ["star_iphone", "star2_iphone"],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_transitive_swift_libraries_with_asset_catalogs",
        tags = [name],
    )

    # Test ios_application can compile multiple storyboards in bundle root from
    # multiple Swift libraries.
    archive_contents_test(
        name = "{}_can_compile_multiple_storyboards_in_bundle_root_from_multiple_swift_libraries_test".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/storyboard_ios.storyboardc",
            "$BUNDLE_ROOT/storyboard_ios_copy.storyboardc",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_multiple_storyboards_in_bundle_root_from_multiple_swift_libraries",
        tags = [name],
    )

    # Test that storyboard compilation actions with ibtool are registered for applications with
    # Swift library with resources, and transitive Swift library resources.
    analysis_target_actions_test(
        name = "{}_registers_action_for_storyboard_compilation_with_swift_library_scoped_resources".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_swift_library_scoped_resources",
        target_mnemonic = "StoryboardCompile",
        expected_argv = ["--module EasyToSearchForModuleName"],
        tags = [name],
    )
    analysis_target_actions_test(
        name = "{}_registers_action_for_storyboard_compilation_with_transitive_swift_library_scoped_resources".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_transitive_swift_library_scoped_resources",
        target_mnemonic = "StoryboardCompile",
        expected_argv = ["--module EasyToSearchForModuleName"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_opt_compilation_mode_on_apple_resource_locales_filter_test".format(name),
        build_type = "device",
        contains = [
            "$RESOURCE_ROOT/it.lproj/localized.strings",
        ],
        not_contains = [
            "$RESOURCE_ROOT/en.lproj/localized.strings",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:ios_locale_it",
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
