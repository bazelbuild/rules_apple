# Copyright 2023 The Bazel Authors. All rights reserved.
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

These providers are part of the public API of the bundling rules. The symbols are re-exported in
public space to allow for writing rules that can reference the contents of these providers, but the
initialization via each provider's "raw initializer" is gated to the internal rules implementation.

Public initializers must be defined in apple:providers.bzl instead of apple/internal:providers.bzl.
These should build from the raw initializer where possible, but not export it, to allow for a safe
boundary with well-defined public APIs for broader usage.
"""

visibility([
    "//apple/...",
    "//test/...",
])

def _make_banned_init(provider_name):
    """Generates a lambda with a fail(...) for providers that can't be publicly initialized."""
    return lambda *kwargs: fail("""
%s is not a provider that is intended to be publicly initialized.

Please file an issue with the Apple BUILD rules if you would like a public API for this provider.
""" % provider_name)

AppleBaseBundleIdInfo, new_applebasebundleidinfo = provider(
    doc = "Provides the base bundle ID prefix for an Apple rule.",
    fields = {
        "base_bundle_id": """
`String`. The bundle ID prefix, composed from an organization ID and an optional variant name.
""",
    },
    init = _make_banned_init("AppleBaseBundleIdInfo"),
)

AppleBinaryInfo, new_applebinaryinfo = provider(
    doc = """
Provides information about an Apple binary target.

This provider propagates general information about an Apple binary that is not
specific to any particular binary type.
""",
    fields = {
        "binary": """
`File`. The binary (executable, dynamic library, etc.) file that the target represents.
""",
        "product_type": """
`String`. The dot-separated product type identifier associated with the binary (for example,
`com.apple.product-type.tool`).
""",
    },
    init = _make_banned_init("AppleBinaryInfo"),
)

AppleBundleInfo, new_applebundleinfo = provider(
    doc = """
This provider propagates general information about an Apple bundle that is not
specific to any particular bundle type. It is propagated by most bundling
rules (applications, extensions, frameworks, test bundles, and so forth).
""",
    fields = {
        "archive": "`File`. The archive that contains the built bundle.",
        "archive_root": """
`String`. The file system path (relative to the workspace root) where the signed
bundle was constructed (before archiving). Other rules **should not** depend on
this field; it is intended to support IDEs that want to read that path from the
provider to avoid performance issues from unzipping the output archive.
""",
        "binary": """
`File`. The binary (executable, dynamic library, etc.) that was bundled. The
physical file is identical to the one inside the bundle except that it is
always unsigned, so note that it is _not_ a path to the binary inside your
output bundle. The primary purpose of this field is to provide a way to access
the binary directly at analysis time; for example, for code coverage.
""",
        "bundle_extension": """
`String`. The bundle extension.
""",
        "bundle_id": """
`String`. The bundle identifier (i.e., `CFBundleIdentifier` in
`Info.plist`) of the bundle.
""",
        "bundle_name": """
`String`. The name of the bundle, without the extension.
""",
        "entitlements": "`File`. Entitlements file used to codesign, if any.",
        "extension_safe": """
`Boolean`. True if the target propagating this provider was
compiled and linked with -application-extension, restricting it to
extension-safe APIs only.
""",
        "infoplist": """
`File`. The complete (binary-formatted) `Info.plist` file for the bundle.
""",
        "minimum_os_version": """
`String`. The minimum OS version (as a dotted version
number like "9.0") that this bundle was built to support.
""",
        "platform_type": """
`String`. The platform type for the bundle (i.e. `ios` for iOS bundles).
""",
        "product_type": """
`String`. The dot-separated product type identifier associated
with the bundle (for example, `com.apple.product-type.application`).
""",
        "uses_swift": """
Boolean. True if Swift is used by the target propagating this
provider. This does not consider embedded bundles; for example, an
Objective-C application containing a Swift extension would have this field
set to true for the extension but false for the application.
""",
    },
    init = _make_banned_init("AppleBundleInfo"),
)

AppleDsymBundleInfo, new_appledsymbundleinfo = provider(
    doc = "Provides information for an Apple dSYM bundle.",
    fields = {
        "direct_dsyms": """
`List` containing `File` references to each of the dSYM bundles that act as direct dependencies of
the given target if any were generated.
""",
        "transitive_dsyms": """
`depset` containing `File` references to each of the dSYM bundles that act as transitive
dependencies of the given target if any were generated.
""",
    },
    init = _make_banned_init("AppleDsymBundleInfo"),
)

AppleExtraOutputsInfo, new_appleextraoutputsinfo = provider(
    doc = """
Provides information about extra outputs that should be produced from the build.

This provider propagates supplemental files that should be produced as outputs
even if the bundle they are associated with is not a direct output of the rule.
For example, an application that contains an extension will build both targets
but only the application will be a rule output. However, if dSYM bundles are
also being generated, we do want to produce the dSYMs for *both* application and
extension as outputs of the build, not just the dSYMs of the explicit target
being built (the application).
""",
    fields = {
        "files": """
`depset` of `File`s. These files will be propagated from embedded bundles (such
as frameworks and extensions) to the top-level bundle (such as an application)
to ensure that they are explicitly produced as outputs of the build.
""",
    },
    init = _make_banned_init("AppleExtraOutputsInfo"),
)

AppleFrameworkBundleInfo, new_appleframeworkbundleinfo = provider(
    doc = """
Denotes a target is an Apple framework bundle.

This provider does not reference 3rd party or precompiled frameworks.
Propagated by Apple framework rules: `ios_framework`, and `tvos_framework`.
""",
    fields = {},
    init = _make_banned_init("AppleFrameworkBundleInfo"),
)

AppleFrameworkImportInfo, new_appleframeworkimportinfo = provider(
    doc = """
Provider that propagates information about 3rd party imported framework targets.

Propagated by framework and XCFramework import rules: `apple_dynamic_framework_import`,
`apple_dynamic_xcframework_import`, `apple_static_framework_import`, and
`apple_static_xcframework_import`
""",
    fields = {
        "framework_imports": """
`depset` of `File`s that represent framework imports that need to be bundled in the top level
application bundle under the Frameworks directory.
""",
        "build_archs": """
`depset` of `String`s that represent binary architectures reported from the current build.
""",
    },
    init = _make_banned_init("AppleFrameworkBundleInfo"),
)

def merge_apple_framework_import_info(apple_framework_import_infos):
    """Merges multiple `AppleFrameworkImportInfo` into one.

    Args:
        apple_framework_import_infos: List of `AppleFrameworkImportInfo` to be merged.

    Returns:
        A new `AppleFrameworkImportInfo` provider based on the contents of the providers supplied by
        `apple_framework_import_infos`.
    """
    transitive_sets = []
    build_archs = []

    for framework_info in apple_framework_import_infos:
        if hasattr(framework_info, "framework_imports"):
            transitive_sets.append(framework_info.framework_imports)
        build_archs.append(framework_info.build_archs)

    return new_appleframeworkimportinfo(
        framework_imports = depset(transitive = transitive_sets),
        build_archs = depset(transitive = build_archs),
    )

ApplePlatformInfo, new_appleplatforminfo = provider(
    doc = "Provides information for the currently selected Apple platforms.",
    fields = {
        "target_os": """
`String` representing the selected Apple OS.
""",
        "target_arch": """
`String` representing the selected target architecture or cpu type.
""",
        "target_environment": """
`String` representing the selected target environment (e.g. "device", "simulator").
""",
    },
    init = _make_banned_init("ApplePlatformInfo"),
)

AppleResourceBundleInfo, new_appleresourcebundleinfo = provider(
    doc = """
Denotes that a target is an Apple resource bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an Apple resource bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is an Apple resource bundle should use this provider to describe that
requirement.
""",
    fields = {},
    init = _make_banned_init("AppleResourceBundleInfo"),
)

AppleResourceInfo, new_appleresourceinfo = provider(
    doc = "Provider that propagates buckets of resources that are differentiated by type.",
    # @unsorted-dict-items
    fields = {
        "asset_catalogs": "Resources that need to be embedded into Assets.car.",
        "datamodels": "Datamodel files.",
        "framework": "Apple framework bundle from `ios_framework` and `tvos_framework` targets.",
        "infoplists": """Plist files to be merged and processed. Plist files that should not be
merged into the root Info.plist should be propagated in `plists`. Because of this, infoplists should
only be bucketed with the `bucketize_typed` method.""",
        "mlmodels": "Core ML model files that should be processed and bundled at the top level.",
        "plists": "Resource Plist files that should not be merged into Info.plist",
        "pngs": "PNG images which are not bundled in an .xcassets folder.",
        "processed": "Typed resources that have already been processed.",
        "storyboards": "Storyboard files.",
        "strings": "Localization strings files.",
        "texture_atlases": "Texture atlas files.",
        "unprocessed": "Generic resources not mapped to the other types.",
        "xibs": "XIB Interface files.",
        "owners": """`depset` of (resource, owner) pairs.""",
        "processed_origins": """`depset` of (processed resource, resource list) pairs.""",
        "unowned_resources": """`depset` of unowned resources.""",
    },
    init = _make_banned_init("AppleResourceInfo"),
)

AppleSharedCapabilityInfo, new_applesharedcapabilityinfo = provider(
    doc = "Provides information on a mergeable set of shared capabilities.",
    fields = {
        "base_bundle_id": """
`String`. The bundle ID prefix, composed from an organization ID and an optional variant name.
""",
    },
    init = _make_banned_init("AppleSharedCapabilityInfo"),
)

AppleStaticXcframeworkBundleInfo, new_applestaticxcframeworkbundleinfo = provider(
    doc = """
Denotes that a target is a static library XCFramework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an XCFramework bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is an XCFramework should use this provider to describe that
requirement.
""",
    fields = {},
    init = _make_banned_init("AppleStaticXcframeworkBundleInfo"),
)

AppleTestInfo, new_appletestinfo = provider(
    doc = """
Provider that test targets propagate to be used for IDE integration.

This includes information regarding test source files, transitive include paths,
transitive module maps, and transitive Swift modules. Test source files are
considered to be all of which belong to the first-level dependencies on the test
target.
""",
    fields = {
        "includes": """
`depset` of `String`s representing transitive include paths which are needed by
IDEs to be used for indexing the test sources.
""",
        "module_maps": """
`depset` of `File`s representing module maps which are needed by IDEs to be used
for indexing the test sources.
""",
        "module_name": """
`String` representing the module name used by the test's sources. This is only
set if the test only contains a single top-level Swift dependency. This may be
used by an IDE to identify the Swift module (if any) used by the test's sources.
""",
        "non_arc_sources": """
`depset` of `File`s containing non-ARC sources from the test's immediate
deps.
""",
        "sources": """
`depset` of `File`s containing sources and headers from the test's immediate deps.
""",
        "swift_modules": """
`depset` of `File`s representing transitive swift modules which are needed by
IDEs to be used for indexing the test sources.
""",
        "test_bundle": "The artifact representing the XCTest bundle for the test target.",
        "test_host": """
The artifact representing the test host for the test target, if the test requires a test host.
""",
        "deps": """
`depset` of `String`s representing the labels of all immediate deps of the test.
Only source files from these deps will be present in `sources`. This may be used
by IDEs to differentiate a test target's transitive module maps from its direct
module maps, as including the direct module maps may break indexing for the
source files of the immediate deps.
""",
    },
    init = _make_banned_init("AppleTestInfo"),
)

AppleXcframeworkBundleInfo, new_applexcframeworkbundleinfo = provider(
    doc = """
Denotes that a target is an XCFramework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an XCFramework bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is an XCFramework should use this provider to describe that
requirement.
""",
    fields = {},
    init = _make_banned_init("AppleXcframeworkBundleInfo"),
)

IosApplicationBundleInfo, new_iosapplicationbundleinfo = provider(
    doc = """
Denotes that a target is an iOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS application bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is an iOS application should use this provider to describe that
requirement.
""",
    fields = {},
    init = _make_banned_init("IosApplicationBundleInfo"),
)

IosAppClipBundleInfo, new_iosappclipbundleinfo = provider(
    doc = """
Denotes that a target is an iOS app clip.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS app clip bundle (and
not some other Apple bundle). Rule authors who wish to require that a dependency
is an iOS app clip should use this provider to describe that requirement.
""",
    fields = {},
    init = _make_banned_init("IosAppClipBundleInfo"),
)

IosExtensionBundleInfo, new_iosextensionbundleinfo = provider(
    doc = """
Denotes that a target is an iOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is an iOS application extension should use this
provider to describe that requirement.
""",
    fields = {},
    init = _make_banned_init("IosExtensionBundleInfo"),
)

IosFrameworkBundleInfo, new_iosframeworkbundleinfo = provider(
    doc = """
Denotes that a target is an iOS dynamic framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS dynamic framework
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an iOS dynamic framework should use this provider to describe
that requirement.
""",
    fields = {},
    init = _make_banned_init("IosFrameworkBundleInfo"),
)

IosStaticFrameworkBundleInfo, new_iosstaticframeworkbundleinfo = provider(
    doc = """
Denotes that a target is an iOS static framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS static framework
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an iOS static framework should use this provider to describe
that requirement.
""",
    fields = {},
    init = _make_banned_init("IosStaticFrameworkBundleInfo"),
)

IosImessageApplicationBundleInfo, new_iosimessageapplicationbundleinfo = provider(
    doc = """
Denotes that a target is an iOS iMessage application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS iMessage application
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an iOS iMessage application should use this provider to describe
that requirement.
""",
    fields = {},
    init = _make_banned_init("IosImessageApplicationBundleInfo"),
)

IosImessageExtensionBundleInfo, new_iosimessageextensionbundleinfo = provider(
    doc = """
Denotes that a target is an iOS iMessage extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS iMessage extension
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an iOS iMessage extension should use this provider to describe
that requirement.
""",
    fields = {},
    init = _make_banned_init("IosImessageExtensionBundleInfo"),
)

IosXcTestBundleInfo, new_iosxctestbundleinfo = provider(
    doc = """
Denotes a target that is an iOS .xctest bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS .xctest bundle (and
not some other Apple bundle). Rule authors who wish to require that a dependency
is an iOS .xctest bundle should use this provider to describe that requirement.
""",
    fields = {},
    init = _make_banned_init("IosXcTestBundleInfo"),
)

MacosApplicationBundleInfo, new_macosapplicationbundleinfo = provider(
    doc = """
Denotes that a target is a macOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS application bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS application should use this provider to describe that
requirement.
""",
    fields = {},
    init = _make_banned_init("MacosApplicationBundleInfo"),
)

MacosBundleBundleInfo, new_macosbundlebundleinfo = provider(
    doc = """
Denotes that a target is a macOS loadable bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS loadable bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS loadable bundle should use this provider to describe that
requirement.
""",
    fields = {},
    init = _make_banned_init("MacosBundleBundleInfo"),
)

MacosExtensionBundleInfo, new_macosextensionbundleinfo = provider(
    doc = """
Denotes that a target is a macOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is a macOS application extension should use this
provider to describe that requirement.
""",
    fields = {},
    init = _make_banned_init("MacosExtensionBundleInfo"),
)

MacosKernelExtensionBundleInfo, new_macoskernelextensionbundleinfo = provider(
    doc = """
Denotes that a target is a macOS kernel extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS kernel extension
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS kernel extension should use this provider to describe that
requirement.
""",
    fields = {},
    init = _make_banned_init("MacosKernelExtensionBundleInfo"),
)

MacosQuickLookPluginBundleInfo, new_macosquicklookpluginbundleinfo = provider(
    doc = """
Denotes that a target is a macOS Quick Look Generator bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS Quick Look generator
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is a macOS Quick Look generator should use this provider to describe
that requirement.
""",
    fields = {},
    init = _make_banned_init("MacosQuickLookPluginBundleInfo"),
)

MacosSpotlightImporterBundleInfo, new_macosspotlightimporterbundleinfo = provider(
    doc = """
Denotes that a target is a macOS Spotlight Importer bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS Spotlight importer
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS Spotlight importer should use this provider to describe that
requirement.
""",
    fields = {},
    init = _make_banned_init("MacosSpotlightImporterBundleInfo"),
)

MacosXPCServiceBundleInfo, new_macosxpcservicebundleinfo = provider(
    doc = """
Denotes that a target is a macOS XPC Service bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS XPC service
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS XPC service should use this provider to describe that
requirement.
""",
    fields = {},
    init = _make_banned_init("MacosXPCServiceBundleInfo"),
)

MacosXcTestBundleInfo, new_macosxctestbundleinfo = provider(
    doc = """
Denotes a target that is a macOS .xctest bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS .xctest bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS .xctest bundle should use this provider to describe that
requirement.
""",
    fields = {},
    init = _make_banned_init("MacosXcTestBundleInfo"),
)

TvosApplicationBundleInfo, new_tvosapplicationbundleinfo = provider(
    doc = """
Denotes that a target is a tvOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a tvOS application bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a tvOS application should use this provider to describe that
requirement.
""",
    fields = {},
    init = _make_banned_init("TvosApplicationBundleInfo"),
)

TvosExtensionBundleInfo, new_tvosextensionbundleinfo = provider(
    doc = """
Denotes that a target is a tvOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a tvOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is a tvOS application extension should use this
provider to describe that requirement.
""",
    fields = {},
    init = _make_banned_init("TvosExtensionBundleInfo"),
)

TvosFrameworkBundleInfo, new_tvosframeworkbundleinfo = provider(
    doc = """
Denotes that a target is a tvOS dynamic framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a tvOS dynamic framework
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is a tvOS dynamic framework should use this provider to describe
that requirement.
""",
    fields = {},
    init = _make_banned_init("TvosFrameworkBundleInfo"),
)

TvosStaticFrameworkBundleInfo, new_tvosstaticframeworkbundleinfo = provider(
    doc = """
Denotes that a target is a tvOS static framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a tvOS static framework
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is a tvOS static framework should use this provider to describe
that requirement.
""",
    fields = {},
    init = _make_banned_init("TvosStaticFrameworkBundleInfo"),
)

TvosXcTestBundleInfo, new_tvosxctestbundleinfo = provider(
    doc = """
Denotes a target that is a tvOS .xctest bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a tvOS .xctest bundle (and
not some other Apple bundle). Rule authors who wish to require that a dependency
is a tvOS .xctest bundle should use this provider to describe that requirement.
""",
    fields = {},
    init = _make_banned_init("TvosXcTestBundleInfo"),
)

WatchosApplicationBundleInfo, new_watchosapplicationbundleinfo = provider(
    doc = """
Denotes that a target is a watchOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a watchOS application
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is a watchOS application should use this provider to describe that
requirement.
""",
    fields = {},
    init = _make_banned_init("WatchosApplicationBundleInfo"),
)

WatchosExtensionBundleInfo, new_watchosextensionbundleinfo = provider(
    doc = """
Denotes that a target is a watchOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a watchOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is a watchOS application extension should use this
provider to describe that requirement.
""",
    fields = {},
    init = _make_banned_init("WatchosExtensionBundleInfo"),
)

WatchosXcTestBundleInfo, new_watchosxctestbundleinfo = provider(
    doc = """
Denotes a target that is a watchOS .xctest bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a watchOS .xctest bundle (and
not some other Apple bundle). Rule authors who wish to require that a dependency
is a watchOS .xctest bundle should use this provider to describe that requirement.
""",
    fields = {},
    init = _make_banned_init("WatchosXcTestBundleInfo"),
)
