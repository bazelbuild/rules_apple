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

"""Defines providers and related types used throughout the bundling rules.

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
    _AppleBundleArchiveSupportInfo = "AppleBundleArchiveSupportInfo",
    _AppleBundleInfo = "AppleBundleInfo",
    _AppleBundleVersionInfo = "AppleBundleVersionInfo",
    _AppleCodesigningDossierInfo = "AppleCodesigningDossierInfo",
    _AppleDebugOutputsInfo = "AppleDebugOutputsInfo",
    _AppleDsymBundleInfo = "AppleDsymBundleInfo",
    _AppleExecutableBinaryInfo = "AppleExecutableBinaryInfo",
    _AppleExtraOutputsInfo = "AppleExtraOutputsInfo",
    _AppleFrameworkBundleInfo = "AppleFrameworkBundleInfo",
    _AppleFrameworkImportInfo = "AppleFrameworkImportInfo",
    _ApplePlatformInfo = "ApplePlatformInfo",
    _AppleResourceBundleInfo = "AppleResourceBundleInfo",
    _AppleResourceInfo = "AppleResourceInfo",
    _AppleResourceLocalesInfo = "AppleResourceLocalesInfo",
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
    _VisionosApplicationBundleInfo = "VisionosApplicationBundleInfo",
    _VisionosXcTestBundleInfo = "VisionosXcTestBundleInfo",
    _WatchosApplicationBundleInfo = "WatchosApplicationBundleInfo",
    _WatchosExtensionBundleInfo = "WatchosExtensionBundleInfo",
    _WatchosXcTestBundleInfo = "WatchosXcTestBundleInfo",
    _make_apple_bundle_version_info = "make_apple_bundle_version_info",
    _make_apple_test_runner_info = "make_apple_test_runner_info",
    _merge_apple_framework_import_info = "merge_apple_framework_import_info",
)
load(
    "@build_bazel_rules_apple//apple/internal:resources.bzl",
    "resources",
)

visibility("public")

AppleBaseBundleIdInfo = _AppleBaseBundleIdInfo
AppleBundleArchiveSupportInfo = _AppleBundleArchiveSupportInfo
AppleBundleInfo = _AppleBundleInfo
AppleBinaryInfo = _AppleBinaryInfo
AppleBundleVersionInfo = _AppleBundleVersionInfo
AppleCodesigningDossierInfo = _AppleCodesigningDossierInfo
AppleDebugOutputsInfo = _AppleDebugOutputsInfo
AppleDsymBundleInfo = _AppleDsymBundleInfo
AppleExecutableBinaryInfo = _AppleExecutableBinaryInfo
AppleExtraOutputsInfo = _AppleExtraOutputsInfo
AppleFrameworkBundleInfo = _AppleFrameworkBundleInfo
AppleFrameworkImportInfo = _AppleFrameworkImportInfo
ApplePlatformInfo = _ApplePlatformInfo
AppleResourceBundleInfo = _AppleResourceBundleInfo
AppleResourceInfo = _AppleResourceInfo
AppleResourceLocalesInfo = _AppleResourceLocalesInfo
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
VisionosApplicationBundleInfo = _VisionosApplicationBundleInfo
VisionosXcTestBundleInfo = _VisionosXcTestBundleInfo
WatchosApplicationBundleInfo = _WatchosApplicationBundleInfo
WatchosExtensionBundleInfo = _WatchosExtensionBundleInfo
WatchosXcTestBundleInfo = _WatchosXcTestBundleInfo

def _merge_apple_resource_info(providers):
    """Merges multiple `AppleResourceInfo` providers into one.

    Args:
        providers: List of `AppleResourceInfo` providers to be merged.

    Returns:
        A new `AppleResourceInfo` provider based on the contents of the providers supplied by
        `providers`.
    """
    return resources.merge_providers(providers = providers)

apple_provider = struct(
    make_apple_bundle_version_info = _make_apple_bundle_version_info,
    make_apple_test_runner_info = _make_apple_test_runner_info,
    merge_apple_framework_import_info = _merge_apple_framework_import_info,
    merge_apple_resource_info = _merge_apple_resource_info,
)
