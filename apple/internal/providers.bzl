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

AppleFrameworkBundleInfo, new_appleframeworkbundleinfo = provider(
    doc = """
Denotes a target is an Apple framework bundle.

This provider does not reference 3rd party or precompiled frameworks.
Propagated by Apple framework rules: `ios_framework`, and `tvos_framework`.
""",
    fields = {},
    init = _make_banned_init("AppleFrameworkBundleInfo"),
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
