# Copyright 2025 The Bazel Authors. All rights reserved.
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

"""Enhanced security feature support methods."""

load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

visibility([
    "@build_bazel_rules_apple//apple/internal/...",
])

# The name of the secure feature that's required for opting into any set of enhanced security
# features on Xcode 26.0 or later.
#
# TODO: b/449684779 - Use this for a mandatory check for the Xcode 26 opt-in feature, since that
# should always be set if any entitlements are required.
_REQUIRED_XCODE_26_OPT_IN = "apple.xcode_26_minimum_opt_in"

# A map of all of the secure features that requires crosstool support and the entitlements that they
# enable. If a secure feature does not enable any entitlements, it should be mapped to an empty
# object.
_ENTITLEMENTS_FROM_SECURE_FEATURES = {
    # A subset of "secure features" will not be mapped to any crosstool features, but they do still
    # provide required entitlements for Xcode 26 and later. These are prefixed with "apple." to
    # separate them from the crosstool namespace.
    "apple.additional_runtime_platform_restrictions": {
        "com.apple.security.hardened-process.platform-restrictions": True,
    },
    "apple.read_only_platform_memory": {
        "com.apple.security.hardened-process.dyld-ro": True,
    },
    "c_bounds_safety": {},
    "c_typed_allocator_support": {
        "com.apple.security.hardened-process.hardened-heap": True,
    },
    "cpp_bounds_safe_buffers": {},
    "cpp_typed_allocator_support": {
        "com.apple.security.hardened-process.hardened-heap": True,
    },
    "libcxx_hardened_mode": {},
    "pointer_authentication": {},
    "security_compiler_warnings": {},
    "trivial_auto_var_init": {},
    "typed_allocator_support": {
        "com.apple.security.hardened-process.hardened-heap": True,
    },
    "warn_unsafe_buffer_usage": {},
    _REQUIRED_XCODE_26_OPT_IN: {
        "com.apple.security.hardened-process": True,
        "com.apple.security.hardened-process.enhanced-security-version": 1,
    },
}

# All of the possible values for `--features` reserved for Apple Enhanced Security.
_SUPPORTED_SECURE_FEATURES = set(list(_ENTITLEMENTS_FROM_SECURE_FEATURES.keys()))

# User-disabled versions of the above.
_POSSIBLE_DISABLED_SECURE_FEATURES = set([
    "-{}".format(x)
    for x in list(_ENTITLEMENTS_FROM_SECURE_FEATURES.keys())
])

_NONE_TYPE = type(None)

def _environment_arch_specific_features(
        *,
        environment_arch,
        features):
    arch_features = list(features)

    # If pointer_authentication is requested, remove it if the environment architecture is Intel,
    # since it's not supported on Intel at all. Further, we choose to remove it for standard arm64
    # at this time, mirroring xcbuild/swift-build behavior, even though Clang allows it.
    if "pointer_authentication" in features and not environment_arch.endswith("arm64e"):
        arch_features.remove("pointer_authentication")
    return arch_features

def _crosstool_features_from_secure_features(*, features, name, secure_features):
    # If this rule does not allow for enhanced security features to be specified as an attribute,
    # which is interpreted as "secure_features" being exactly "None", return the features as-is,
    # allowing any secure features that might be in "features" to remain as-is.
    if type(secure_features) == _NONE_TYPE:
        return features

    requested_secure_features = set(secure_features)

    # Check that all of the requested secure features are supported.
    unsupported_secure_features = requested_secure_features - _SUPPORTED_SECURE_FEATURES
    if unsupported_secure_features:
        fail("""
Unsupported secure_features requested:
{unsupported_features}

Please remove these from this target's "secure_features" attribute.

The full list of supported secure_features is:
{all_supported_features}
        """.format(
            unsupported_features = str(list(unsupported_secure_features)),
            all_supported_features = str(list(_SUPPORTED_SECURE_FEATURES)),
        ))

    # Start building the set of features to build with, starting from the set of features already
    # requested by the user.
    requested_features = set(features)

    # Remove any secure features from "features" that were not explicitly requested at the top level
    # from "secure_features". This is what prevents a command line --features or raw features on the
    # rule or package from applying to top level targets that can have "secure_features" specified.
    secure_features_not_requested = _SUPPORTED_SECURE_FEATURES - requested_secure_features
    requested_features -= secure_features_not_requested

    # Amend the list of requested features to include the secure_features within the list of
    # features to build with, if they're not already present. Since we deal with sets, this is a
    # no-op if they're already present.
    requested_features |= requested_secure_features

    # Check that no disabled secure features are present in the list of requested features, since
    # that would confilict with the top level target's declaration of "secure_features".
    for disabled_secure_feature in _POSSIBLE_DISABLED_SECURE_FEATURES:
        if (disabled_secure_feature in requested_features and
            disabled_secure_feature.removeprefix("-") in requested_secure_features):
            fail(
                """
Attempted to disable the secure feature `{disabled_secure_feature}` but it is explicitly enabled \
in the target's "secure_features" attribute at `{name}`.

Either remove the secure feature from the "secure_features" attribute to disable it, or remove the \
`--features=-{disabled_secure_feature}` from the command line to keep it enabled.
""".format(
                    disabled_secure_feature = disabled_secure_feature.removeprefix("-"),
                    name = name,
                ),
            )

    # If we don't need to make any changes, return the features as-is.
    if requested_features == set(features):
        return features

    # Return the full, sorted list of requested crosstool-relevant features.
    return sorted(list(requested_features))

def _entitlements_from_secure_features(
        *,
        secure_features,
        xcode_version):
    if not secure_features:
        return {}

    # Check that we're building with Xcode 26.0 or later. If not, return an empty list to signal
    # that no entitlements are supported or needed for this build.
    if not xcode_version >= apple_common.dotted_version("26.0"):
        return {}

    # Build a set of all of the entitlements that are required by the requested secure features.
    required_entitlements = dict()
    for feature_name in secure_features:
        required_entitlements |= _ENTITLEMENTS_FROM_SECURE_FEATURES[feature_name]

    # TODO: b/449684779 - Add a mandatory check for the Xcode 26 opt-in feature, since that should
    # always be set if any entitlements are required.

    return required_entitlements

def _environment_archs_from_secure_features(
        *,
        environment_archs,
        require_pointer_authentication_attribute,
        secure_features):
    # TODO: b/449684779 - Migrate users to secure_features behind an allowlist when it's ready for
    # onboarding. Remove this "require_pointer_authentication_attribute" check once
    # pointer_authentication is onboarded.
    if not require_pointer_authentication_attribute:
        return environment_archs

    # Make sure the arm64e environment archs are first, for the benefit of the rule-level
    # transition, which always picks the first architecture in the list. That way, we can pass
    # forward the pointer_authentication feature.
    arm64e_archs = []
    other_archs = []
    for environment_arch in environment_archs:
        if environment_arch.endswith("arm64e"):
            arm64e_archs.append(environment_arch)
        else:
            other_archs.append(environment_arch)
    if "pointer_authentication" not in secure_features:
        return other_archs
    return arm64e_archs + other_archs

def _validate_secure_features_support(
        *,
        cc_toolchain_info,
        feature_configuration,
        platform_info,
        rule_label,
        secure_features):
    # If the feature is an Apple crosstool feature (i.e. NOT prefixed with "apple."), check that the
    # feature is explicitly enabled in the current configuration.
    crosstool_secure_features = [
        feature_name
        for feature_name in secure_features
        if not feature_name.startswith("apple.")
    ]
    for feature_name in crosstool_secure_features:
        if feature_name == "pointer_authentication" and platform_info.target_arch != "arm64e":
            # Pointer authentication is only applied to arm64e, so the check will fail for any other
            # architecture since we're dropping that feature for non-arm64e at this time.
            continue

        if not (
            cc_common.is_enabled(
                feature_configuration = feature_configuration,
                feature_name = feature_name,
            )
        ):
            fail(
                """
Attempted to enable the secure feature `{feature_name}` for the target at `{rule_label}` with the \
target triple '{target_triple}', but it appears to be disabled.

Check that the selected toolchain supports `{feature_name}` and that your invocation is not \
attempting to explicitly disable the feature via minus prefixed feature names, such as \
`--features=-{feature_name}`, and that the rule is not attempting to disable the feature via the \
`features` attribute by assigning a `-{feature_name}` value.
                """.format(
                    target_triple = cc_toolchain_info.target_gnu_system_name,
                    feature_name = feature_name,
                    rule_label = str(rule_label),
                ),
            )

secure_features_support = struct(
    crosstool_features_from_secure_features = _crosstool_features_from_secure_features,
    entitlements_from_secure_features = _entitlements_from_secure_features,
    environment_arch_specific_features = _environment_arch_specific_features,
    environment_archs_from_secure_features = _environment_archs_from_secure_features,
    validate_secure_features_support = _validate_secure_features_support,
)
