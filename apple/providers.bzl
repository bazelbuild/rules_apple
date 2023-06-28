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

"""# Providers

Defines providers and related types used throughout the rules in this repository.

Most users will not need to use these providers to simply create and build Apple
targets, but if you want to write your own custom rules that interact with these
rules, then you will use these providers to communicate between them.

These providers are part of the public API of the bundling rules. Other rules that want to propagate
information to the bundling rules or that want to consume the bundling rules as their own inputs
should use these to handle the relevant information that they need.

Public initializers must be defined in apple:providers.bzl instead of apple/internal:providers.bzl.
These should build from the "raw initializer" where possible, but not export it, to allow for a safe
boundary with well-defined public APIs for broader usage.
"""

load(
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    _AppleBaseBundleIdInfo = "AppleBaseBundleIdInfo",
    _AppleBinaryInfo = "AppleBinaryInfo",
    _AppleBundleInfo = "AppleBundleInfo",
    _AppleBundleVersionInfo = "AppleBundleVersionInfo",
    _AppleDsymBundleInfo = "AppleDsymBundleInfo",
    _AppleExtraOutputsInfo = "AppleExtraOutputsInfo",
    _AppleFrameworkBundleInfo = "AppleFrameworkBundleInfo",
    _AppleFrameworkImportInfo = "AppleFrameworkImportInfo",
    _ApplePlatformInfo = "ApplePlatformInfo",
    _AppleResourceBundleInfo = "AppleResourceBundleInfo",
    _AppleResourceInfo = "AppleResourceInfo",
    _AppleSharedCapabilityInfo = "AppleSharedCapabilityInfo",
    _AppleStaticXcframeworkBundleInfo = "AppleStaticXcframeworkBundleInfo",
    _AppleTestInfo = "AppleTestInfo",
    _AppleTestRunnerInfo = "AppleTestRunnerInfo",
    _AppleXcframeworkBundleInfo = "AppleXcframeworkBundleInfo",
    _IosAppClipBundleInfo = "IosAppClipBundleInfo",
    _IosApplicationBundleInfo = "IosApplicationBundleInfo",
    _IosExtensionBundleInfo = "IosExtensionBundleInfo",
    _IosFrameworkBundleInfo = "IosFrameworkBundleInfo",
    _IosImessageApplicationBundleInfo = "IosImessageApplicationBundleInfo",
    _IosImessageExtensionBundleInfo = "IosImessageExtensionBundleInfo",
    _IosStaticFrameworkBundleInfo = "IosStaticFrameworkBundleInfo",
    _IosXcTestBundleInfo = "IosXcTestBundleInfo",
    _MacosApplicationBundleInfo = "MacosApplicationBundleInfo",
    _MacosBundleBundleInfo = "MacosBundleBundleInfo",
    _MacosExtensionBundleInfo = "MacosExtensionBundleInfo",
    _MacosKernelExtensionBundleInfo = "MacosKernelExtensionBundleInfo",
    _MacosQuickLookPluginBundleInfo = "MacosQuickLookPluginBundleInfo",
    _MacosSpotlightImporterBundleInfo = "MacosSpotlightImporterBundleInfo",
    _MacosXPCServiceBundleInfo = "MacosXPCServiceBundleInfo",
    _MacosXcTestBundleInfo = "MacosXcTestBundleInfo",
    _TvosApplicationBundleInfo = "TvosApplicationBundleInfo",
    _TvosExtensionBundleInfo = "TvosExtensionBundleInfo",
    _TvosFrameworkBundleInfo = "TvosFrameworkBundleInfo",
    _TvosStaticFrameworkBundleInfo = "TvosStaticFrameworkBundleInfo",
    _TvosXcTestBundleInfo = "TvosXcTestBundleInfo",
    _WatchosApplicationBundleInfo = "WatchosApplicationBundleInfo",
    _WatchosExtensionBundleInfo = "WatchosExtensionBundleInfo",
    _WatchosXcTestBundleInfo = "WatchosXcTestBundleInfo",
    _make_apple_bundle_version_info = "make_apple_bundle_version_info",
    _make_apple_test_runner_info = "make_apple_test_runner_info",
    _merge_apple_framework_import_info = "merge_apple_framework_import_info",
)

AppleBaseBundleIdInfo = _AppleBaseBundleIdInfo
AppleBundleInfo = _AppleBundleInfo
AppleBinaryInfo = _AppleBinaryInfo
AppleBundleVersionInfo = _AppleBundleVersionInfo
AppleDsymBundleInfo = _AppleDsymBundleInfo
AppleExtraOutputsInfo = _AppleExtraOutputsInfo
AppleFrameworkBundleInfo = _AppleFrameworkBundleInfo
AppleFrameworkImportInfo = _AppleFrameworkImportInfo
ApplePlatformInfo = _ApplePlatformInfo
AppleResourceBundleInfo = _AppleResourceBundleInfo
AppleResourceInfo = _AppleResourceInfo
AppleSharedCapabilityInfo = _AppleSharedCapabilityInfo
AppleStaticXcframeworkBundleInfo = _AppleStaticXcframeworkBundleInfo
AppleTestInfo = _AppleTestInfo
AppleTestRunnerInfo = _AppleTestRunnerInfo
AppleXcframeworkBundleInfo = _AppleXcframeworkBundleInfo
IosAppClipBundleInfo = _IosAppClipBundleInfo
IosApplicationBundleInfo = _IosApplicationBundleInfo
IosExtensionBundleInfo = _IosExtensionBundleInfo
IosFrameworkBundleInfo = _IosFrameworkBundleInfo
IosImessageApplicationBundleInfo = _IosImessageApplicationBundleInfo
IosImessageExtensionBundleInfo = _IosImessageExtensionBundleInfo
IosStaticFrameworkBundleInfo = _IosStaticFrameworkBundleInfo
IosXcTestBundleInfo = _IosXcTestBundleInfo
MacosApplicationBundleInfo = _MacosApplicationBundleInfo
MacosBundleBundleInfo = _MacosBundleBundleInfo
MacosExtensionBundleInfo = _MacosExtensionBundleInfo
MacosKernelExtensionBundleInfo = _MacosKernelExtensionBundleInfo
MacosQuickLookPluginBundleInfo = _MacosQuickLookPluginBundleInfo
MacosSpotlightImporterBundleInfo = _MacosSpotlightImporterBundleInfo
MacosXPCServiceBundleInfo = _MacosXPCServiceBundleInfo
MacosXcTestBundleInfo = _MacosXcTestBundleInfo
TvosApplicationBundleInfo = _TvosApplicationBundleInfo
TvosExtensionBundleInfo = _TvosExtensionBundleInfo
TvosFrameworkBundleInfo = _TvosFrameworkBundleInfo
TvosStaticFrameworkBundleInfo = _TvosStaticFrameworkBundleInfo
TvosXcTestBundleInfo = _TvosXcTestBundleInfo
WatchosApplicationBundleInfo = _WatchosApplicationBundleInfo
WatchosExtensionBundleInfo = _WatchosExtensionBundleInfo
WatchosXcTestBundleInfo = _WatchosXcTestBundleInfo

apple_provider = struct(
    make_apple_bundle_version_info = _make_apple_bundle_version_info,
    make_apple_test_runner_info = _make_apple_test_runner_info,
    merge_apple_framework_import_info = _merge_apple_framework_import_info,
)

AppleBinaryInfoplistInfo = provider(
    doc = """
Provides information about the Info.plist that was linked into an Apple binary
target.
""",
    fields = {
        "infoplist": """
`File`. The complete (binary-formatted) `Info.plist` embedded in the binary.
""",
    },
)

AppleProvisioningProfileInfo = provider(
    doc = "Provides information about a provisioning profile.",
    fields = {
        "provisioning_profile": """
`File`. The provisioning profile.
""",
        "profile_name": """\
string. The profile name (e.g. "iOS Team Provisioning Profile: com.example.app").
""",
        "team_id": """\
`string`. The Team ID the profile is associated with (e.g. "A12B3CDEFG"), or `None` if it's not
known at analysis time.
""",
    },
)

IosStickerPackExtensionBundleInfo = provider(
    doc = """
Denotes that a target is an iOS Sticker Pack extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS Sticker Pack extension
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an iOS Sticker Pack extension should use this provider to describe
that requirement.
""",
    fields = {},
)

WatchosFrameworkBundleInfo = provider(
    doc = """
Denotes that a target is watchOS dynamic framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a watchOS dynamic framework
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is a watchOS dynamic framework should use this provider to describe
that requirement.
""",
    fields = {},
)

WatchosStaticFrameworkBundleInfo = provider(
    doc = """
Denotes that a target is an watchOS static framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a watchOS static framework
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is a watchOS static framework should use this provider to describe
that requirement.
""",
    fields = {},
)

MacosFrameworkBundleInfo = provider(
    doc = """
Denotes that a target is an macOS dynamic framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an macOS dynamic framework
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an macOS dynamic framework should use this provider to describe
that requirement.
""",
    fields = {},
)

MacosStaticFrameworkBundleInfo = provider(
    doc = """
Denotes that a target is an macOS static framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an macOS static framework
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an macOS static framework should use this provider to describe
that requirement.
""",
    fields = {},
)
