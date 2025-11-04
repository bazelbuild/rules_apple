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

visibility([
    "//apple/internal/...",
])

# TODO: b/449684779 - Stand up a solution for allowing arm64e as a target arch in a transition when
# building for devices. Simulators don't have adequate support yet (FB20484613), so consider
# fail-ing or warning until that's resolved.

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

_NONE_TYPE = type(None)

def _crosstool_features_from_secure_features(*, features, secure_features):
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

    # TODO: b/449684779 - See if we can do anything to account for `-` prefixed features here before
    # the entitlements check because those are supposed to be features disabled by the bazel
    # invocation. One approach is to consider fail(...)-ing if any `-` prefixed features are
    # requested with `secure_features`, because that incoming configuration on the bazel invocation
    # would invalidate what is requested from the target definition.

    # Remove any secure features from "features" that were not explicitly requested at the top level
    # from "secure_features". This is what prevents a command line --features or raw features on the
    # rule or package from applying to top level targets that can have "secure_features" specified.
    secure_features_not_requested = _SUPPORTED_SECURE_FEATURES - requested_secure_features
    requested_features -= secure_features_not_requested

    # Amend the list of requested features to include the secure_features within the list of
    # features to build with, if they're not already present. Since we deal with sets, this is a
    # no-op if they're already present.
    requested_features |= requested_secure_features

    # If we don't need to make any changes, return the features as-is.
    if requested_features == set(features):
        return features

    # Return the full, sorted list of requested crosstool-relevant features.
    return sorted(list(requested_features))

def _entitlements_from_secure_features(*, secure_features, xcode_version):
    if not secure_features:
        return []

    # Check that we're building with Xcode 26.0 or later. If not, return an empty list to signal
    # that no entitlements are supported or needed for this build.
    if not xcode_version >= apple_common.dotted_version("26.0"):
        return []

    # TODO: b/449684779 - Check via cc_common.is_enabled(...) for each of the crosstool features to
    # see if they're set via the build configuration, assuming that they might be set outside of the
    # configuration as seen by the transition. As I understand it, this should be able to determine
    # if the features are actually enabled for the build, or if there was an effort made to
    # explicitly disable them, which can't be fully determined at transition time.

    # Build a set of all of the entitlements that are required by the requested secure features.
    required_entitlements = dict()
    for feature in secure_features:
        required_entitlements |= _ENTITLEMENTS_FROM_SECURE_FEATURES[feature]

    # TODO: b/449684779 - Add a mandatory check for the Xcode 26 opt-in feature, since that should
    # always be set if any entitlements are required.

    return required_entitlements

secure_features_support = struct(
    crosstool_features_from_secure_features = _crosstool_features_from_secure_features,
    entitlements_from_secure_features = _entitlements_from_secure_features,
)
