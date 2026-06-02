"""Helpers for defining macros for Apple rules uniformly."""

load(
    "//apple:providers.bzl",
    "AppleBundleInfo",
    "IosFrameworkBundleInfo",
    "MacosFrameworkBundleInfo",
    "TvosFrameworkBundleInfo",
    "VisionosFrameworkBundleInfo",
    "WatchosFrameworkBundleInfo",
)
load(
    "//apple/internal:bundling_support.bzl",
    "bundle_id_suffix_default",
)
load(
    "//apple/internal:rule_attrs.bzl",
    "rule_attrs",
)
load(
    "//apple/internal:transition_support.bzl",
    "transition_support",
)

_APPLE_TEST_BUNDLE_ATTRS_BY_PLATFORM = {
    "ios": struct(
        allowed_families = ["iphone", "ipad"],
        framework_providers = [[AppleBundleInfo, IosFrameworkBundleInfo]],
        include_additional_contents = False,
        profile_extension = ".mobileprovision",
    ),
    "macos": struct(
        allowed_families = ["mac"],
        framework_providers = [[AppleBundleInfo, MacosFrameworkBundleInfo]],
        include_additional_contents = True,
        profile_extension = ".provisionprofile",
    ),
    "tvos": struct(
        allowed_families = ["tv"],
        framework_providers = [[AppleBundleInfo, TvosFrameworkBundleInfo]],
        include_additional_contents = False,
        profile_extension = ".mobileprovision",
    ),
    "visionos": struct(
        allowed_families = ["vision"],
        framework_providers = [[AppleBundleInfo, VisionosFrameworkBundleInfo]],
        include_additional_contents = False,
        profile_extension = ".mobileprovision",
    ),
    "watchos": struct(
        allowed_families = ["watch"],
        framework_providers = [[AppleBundleInfo, WatchosFrameworkBundleInfo]],
        include_additional_contents = False,
        profile_extension = ".mobileprovision",
    ),
}

def _apple_test_bundle_attrs(platform):
    platform_attrs = _APPLE_TEST_BUNDLE_ATTRS_BY_PLATFORM.get(platform)
    if platform_attrs == None:
        fail("Unknown Apple test bundle attrs platform '{}'".format(platform))

    binary_linking_attrs = rule_attrs.binary_linking_attrs(
        deps_cfg = transition_support.apple_platform_split_transition,
        is_test_supporting_rule = True,
        requires_legacy_cc_toolchain = True,
    )
    common_bundle_attrs = rule_attrs.common_bundle_attrs(
        deps_cfg = transition_support.apple_platform_split_transition,
    )
    device_family_attrs = rule_attrs.device_family_attrs(
        allowed_families = platform_attrs.allowed_families,
        is_mandatory = False,
    )
    infoplist_attrs = rule_attrs.infoplist_attrs(
        default_infoplist = rule_attrs.defaults.test_bundle_infoplist,
    )
    signing_attrs = rule_attrs.signing_attrs(
        default_bundle_id_suffix = bundle_id_suffix_default.bundle_name,
        supports_capabilities = False,
        profile_extension = platform_attrs.profile_extension,
    )

    attrs = {
        "additional_linker_inputs": binary_linking_attrs["additional_linker_inputs"],
        "base_bundle_id": signing_attrs["base_bundle_id"],
        "bundle_id": signing_attrs["bundle_id"],
        "bundle_id_suffix": signing_attrs["bundle_id_suffix"],
        "bundle_name": attr.string(
            configurable = False,
            doc = """
The desired name of the test bundle (without the extension). If this attribute is not set, then the
name of the target will be used instead.
""",
        ),
        "deps": binary_linking_attrs["deps"],
        "families": device_family_attrs["families"],
        "frameworks": attr.label_list(
            providers = platform_attrs.framework_providers,
            doc = "A list of framework targets that this target depends on.",
        ),
        "infoplists": infoplist_attrs["infoplists"],
        "linkopts": binary_linking_attrs["linkopts"],
        "provisioning_profile": signing_attrs["provisioning_profile"],
        "resources": common_bundle_attrs["resources"],
        "stamp": binary_linking_attrs["stamp"],
    }

    if platform_attrs.include_additional_contents:
        attrs |= {
            "additional_contents": attr.label_keyed_string_dict(
                allow_files = True,
                doc = """
Files that should be copied into specific subdirectories of the Contents folder in the bundle. The
keys of this dictionary are labels pointing to single files, filegroups, or targets; the
corresponding value is the name of the subdirectory of Contents where they should be placed.

The relative directory structure of filegroup contents is preserved when they are copied into the
desired Contents subdirectory.
""",
            ),
        }

    return attrs

def _create_apple_macro_rule(
        *,
        doc,
        implementation,
        inherit_attrs,
        attrs = None,
        default_runner = None,
        platform_attrs = None):
    attrs = attrs or {}
    if platform_attrs != None:
        attrs |= _apple_test_bundle_attrs(platform_attrs)
    return macro(
        implementation = implementation,
        inherit_attrs = inherit_attrs,
        attrs = attrs | {
            "runner": attr.label(
                default = default_runner,
                mandatory = bool(default_runner == None),
                doc = "A single runner target to use for the test target.",
            ),
        },
        doc = doc,
    )

def _create_apple_macro_suite_rule(
        *,
        doc,
        implementation,
        inherit_attrs,
        attrs = None,
        platform_attrs = None):
    attrs = attrs or {}
    if platform_attrs != None:
        attrs |= _apple_test_bundle_attrs(platform_attrs)
    return macro(
        implementation = implementation,
        inherit_attrs = inherit_attrs,
        attrs = attrs | {
            "runner": None,
            "runners": attr.label_list(
                configurable = False,
                mandatory = True,
                doc = "A list of runner targets to use for the test targets.",
            ),
        },
        doc = doc,
    )

macro_factory = struct(
    create_apple_test_macro = _create_apple_macro_rule,
    create_apple_test_suite_macro = _create_apple_macro_suite_rule,
)
