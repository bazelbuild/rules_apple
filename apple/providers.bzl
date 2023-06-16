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
    _AppleBundleInfo = "AppleBundleInfo",
    _AppleFrameworkBundleInfo = "AppleFrameworkBundleInfo",
    _ApplePlatformInfo = "ApplePlatformInfo",
    _AppleResourceBundleInfo = "AppleResourceBundleInfo",
    _AppleResourceInfo = "AppleResourceInfo",
    _AppleSharedCapabilityInfo = "AppleSharedCapabilityInfo",
    _AppleStaticXcframeworkBundleInfo = "AppleStaticXcframeworkBundleInfo",
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
)

AppleBaseBundleIdInfo = _AppleBaseBundleIdInfo

AppleBundleInfo = _AppleBundleInfo

AppleBinaryInfo = provider(
    doc = """
Provides information about an Apple binary target.

This provider propagates general information about an Apple binary that is not
specific to any particular binary type.
""",
    fields = {
        "binary": """
`File`. The binary (executable, dynamic library, etc.) file that the target represents.
""",
        "infoplist": """
`File`. The complete (binary-formatted) `Info.plist` embedded in the binary.
""",
        "product_type": """
`String`. The dot-separated product type identifier associated with the binary (for example,
`com.apple.product-type.tool`).
""",
    },
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

def _apple_bundle_version_info_init(
        *_,
        **kwargs):
    """Ensures that the short_version_string is set based on build_version, if it is unset."""

    if "short_version_string" in kwargs and kwargs["short_version_string"]:
        # Prevent setting short_version_string without build_version.
        if "build_version" not in kwargs or not kwargs["build_version"]:
            fail(
                """
Internal Error: short_version_string was assigned as {short_version_string} on
AppleBundleVersionInfo but no value for build_version was set. build_version is mandatory if
short_version_string is present.
""".format(
                    short_version_string = kwargs["short_version_string"],
                ),
            )
    elif "build_version" in kwargs and kwargs["build_version"]:
        kwargs["short_version_string"] = kwargs["build_version"]

    # TODO(b/281687115): Consider making all fields besides short_version_string mandatory when it
    # is feasible.
    return kwargs

AppleBundleVersionInfo, _ = provider(
    doc = "Provides versioning information for an Apple bundle.",
    fields = {
        "build_version": """
'String'. A version string for an Info.plist which corresponds to `CFBundleVersion`. Mandatory if
`short_version_string` is set.
""",
        "short_version_string": """
'String'. A version string for an Info.plist which corresponds to `CFBundleShortVersionString`.
""",
        "version_file": """
A `File` containing JSON-formatted text describing the version
number information propagated by the target.

It contains two keys:

*   `build_version`, which corresponds to `CFBundleVersion`.

*   `short_version_string`, which corresponds to `CFBundleShortVersionString`.
""",
    },
    init = _apple_bundle_version_info_init,
)

AppleDsymBundleInfo = provider(
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
)

AppleExtraOutputsInfo = provider(
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
)

AppleFrameworkBundleInfo = _AppleFrameworkBundleInfo

AppleFrameworkImportInfo = provider(
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
        "dsym_imports": """
Depset of Files that represent dSYM imports that need to be processed to
provide .symbols files for packaging into the .ipa file if requested in the
build with --define=apple.package_symbols=(yes|true|1).
""",
        "build_archs": """
`depset` of `String`s that represent binary architectures reported from the current build.
""",
        "debug_info_binaries": """
Depset of Files that represent framework binaries and dSYM binaries that
provide debug info.
""",
    },
)

def merge_apple_framework_import_info(apple_framework_import_infos):
    """Merges multiple `AppleFrameworkImportInfo` into one.

    Args:
        apple_framework_import_infos: List of `AppleFrameworkImportInfo` to be merged.

    Returns:
        Result of merging all the received framework infos.
    """
    transitive_debug_info_binaries = []
    transitive_dsyms = []
    transitive_sets = []
    build_archs = []

    for framework_info in apple_framework_import_infos:
        if hasattr(framework_info, "debug_info_binaries"):
            transitive_debug_info_binaries.append(framework_info.debug_info_binaries)
        if hasattr(framework_info, "dsym_imports"):
            transitive_dsyms.append(framework_info.dsym_imports)
        if hasattr(framework_info, "framework_imports"):
            transitive_sets.append(framework_info.framework_imports)
        build_archs.append(framework_info.build_archs)

    return AppleFrameworkImportInfo(
        debug_info_binaries = depset(transitive = transitive_debug_info_binaries),
        dsym_imports = depset(transitive = transitive_dsyms),
        framework_imports = depset(transitive = transitive_sets),
        build_archs = depset(transitive = build_archs),
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

ApplePlatformInfo = _ApplePlatformInfo

AppleResourceBundleInfo = _AppleResourceBundleInfo

AppleResourceInfo = _AppleResourceInfo

AppleSharedCapabilityInfo = _AppleSharedCapabilityInfo

AppleStaticXcframeworkBundleInfo = _AppleStaticXcframeworkBundleInfo

AppleTestInfo = provider(
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
)

AppleTestRunnerInfo = provider(
    doc = """
Provider that runner targets must propagate.

In addition to the fields, all the runfiles that the runner target declares will be added to the
test rules runfiles.
""",
    fields = {
        "execution_requirements": """
Optional dictionary that represents the specific hardware requirements for this test.
""",
        "execution_environment": """
Optional dictionary with the environment variables that are to be set in the test action, and are
not propagated into the XCTest invocation. These values will _not_ be added into the %(test_env)s
substitution, but will be set in the test action.
""",
        "test_environment": """
Optional dictionary with the environment variables that are to be propagated into the XCTest
invocation. These values will be included in the %(test_env)s substitution and will _not_ be set in
the test action.
""",
        "test_runner_template": """
Required template file that contains the specific mechanism with which the tests will be run. The
*_ui_test and *_unit_test rules will substitute the following values:
    * %(test_host_path)s:   Path to the app being tested.
    * %(test_bundle_path)s: Path to the test bundle that contains the tests.
    * %(test_env)s:         Environment variables for the XCTest invocation (e.g FOO=BAR,BAZ=QUX).
    * %(test_type)s:        The test type, whether it is unit or UI.
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
