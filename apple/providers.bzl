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

These providers are part of the public API of the bundling rules. Other rules
that want to propagate information to the bundling rules or that want to
consume the bundling rules as their own inputs should use these to handle the
relevant information that they need.
"""

AppleBundleInfo = provider(
    doc = """
Provides information about an Apple bundle target.

This provider propagates general information about an Apple bundle that is not
specific to any particular bundle type.
It is propagated by most bundling rules—applications, extensions, frameworks, test bundles, and so forth.
""",
    fields = {
        "archive": "`File`. The archive that contains the built application.",
        "archive_root": """
`string`. The file system path (relative to the workspace root)
where the signed bundle was constructed (before archiving). Other rules
*should not* depend on this field; it is intended to support IDEs that
want to read that path from the provider to avoid unzipping the output
archive.
""",
        "binary": """
`File`. The binary (executable, dynamic library, etc.) that was bundled. The
physical file is identical to the one inside the bundle except that it is
always unsigned, so note that it is _not_ a path to the binary inside your
output bundle. The primary purpose of this field is to provide a way to access
the binary directly at analysis time; for example, for code coverage.
""",
        "bundle_extension": """
`string`. The bundle extension.
""",
        "bundle_id": """
`string`. The bundle identifier (i.e., `CFBundleIdentifier` in
`Info.plist`) of the bundle.
""",
        "bundle_name": """
`string`. The name of the bundle, without the extension.
""",
        "executable_name": """
`string`. The name of the executable that was bundled.
""",
        "entitlements": "`File`. Entitlements file used to codesign, if any.",
        "extension_safe": """
Boolean. True if the target propagating this provider was
compiled and linked with -application-extension, restricting it to
extension-safe APIs only.
""",
        "infoplist": """
`File`. The complete (binary-formatted) `Info.plist` file for the bundle.
""",
        "minimum_deployment_os_version": """
`string`. The minimum deployment OS version (as a dotted version
number like "9.0") that this bundle was built to support. This is different from
`minimum_os_version`, which is effective at compile time. Ensure version
specific APIs are guarded with `available` clauses.
""",
        "minimum_os_version": """
`string`. The minimum OS version (as a dotted version
number like "9.0") that this bundle was built to support.
""",
        "platform_type": """
`string`. The platform type for the bundle (i.e. `ios` for iOS bundles).
""",
        "product_type": """
`string`. The dot-separated product type identifier associated
with the bundle (for example, `com.apple.product-type.application`).
""",
        "uses_swift": """
Boolean. True if Swift is used by the target propagating this
provider. This does not consider embedded bundles; for example, an
Objective-C application containing a Swift extension would have this field
set to true for the extension but false for the application.
""",
    },
)

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
        "product_type": """
`string`. The dot-separated product type identifier associated with the binary (for example,
`com.apple.product-type.tool`).
""",
    },
)

AppleBundleVersionInfo = provider(
    doc = "Provides versioning information for an Apple bundle.",
    fields = {
        "version_file": """
A `File` containing JSON-formatted text describing the version
number information propagated by the target. It contains two keys:
`build_version`, which corresponds to `CFBundleVersion`; and
`short_version_string`, which corresponds to `CFBundleShortVersionString`.
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

AppleFrameworkImportInfo = provider(
    doc = "Provider that propagates information about framework import targets.",
    fields = {
        "framework_imports": """
Depset of Files that represent framework imports that need to be bundled in the top level
application bundle under the Frameworks directory.
""",
        "dsym_imports": """
Depset of Files that represent dSYM imports that need to be processed to
provide .symbols files for packaging into the .ipa file if requested in the
build with --define=apple.package_symbols=(yes|true|1).
""",
        "build_archs": """
Depset of strings that represent binary architectures reported from the current build.
""",
        "debug_info_binaries": """
Depset of Files that represent framework binaries and dSYM binaries that
provide debug info.
""",
    },
)

def merge_apple_framework_import_info(apple_framework_import_infos):
    """
    Merges multiple `AppleFrameworkImportInfo` into one.

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

AppleResourceInfo = provider(
    doc = "Provider that propagates buckets of resources that are differentiated by type.",
    # @unsorted-dict-items
    fields = {
        "alternate_icons": "Alternate icons to be included in the App bundle.",
        "asset_catalogs": "Resources that need to be embedded into Assets.car.",
        "datamodels": "Datamodel files.",
        "infoplists": """Plist files to be merged and processed. Plist files that should not be
merged into the root Info.plist should be propagated in `plists`. Because of this, infoplists should
only be bucketed with the `bucketize_typed` method.""",
        "metals": """Metal Shading Language source files to be compiled into a single .metallib file
and bundled at the top level.""",
        "mlmodels": "Core ML model files that should be processed and bundled at the top level.",
        "plists": "Resource Plist files that should not be merged into Info.plist",
        "pngs": "PNG images which are not bundled in an .xcassets folder.",
        "processed": "Typed resources that have already been processed.",
        "storyboards": "Storyboard files.",
        "strings": "Localization strings files.",
        "texture_atlases": "Texture atlas files.",
        "unprocessed": "Generic resources not mapped to the other types.",
        "xibs": "XIB Interface files.",
        "owners": """Depset of (resource, owner) pairs.""",
        "processed_origins": """Depset of (processed resource, resource list) pairs.""",
        "unowned_resources": """Depset of unowned resources.""",
    },
)

AppleResourceBundleInfo = provider(
    doc = """
Denotes that a target is an Apple resource bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an Apple resource bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is an Apple resource bundle should use this provider to describe that
requirement.
""",
    fields = {},
)

AppleSupportToolchainInfo = provider(
    doc = """
Propagates information about an Apple toolchain to internal bundling rules that use the toolchain.

This provider exists as an internal detail for the rules to reference common, executable tools and
files used as script templates for the purposes of executing Apple actions. Defined by the
`apple_support_toolchain` rule.
""",
    fields = {
        "dsym_info_plist_template": """\
A `File` referencing a plist template for dSYM bundles.
""",
        "process_and_sign_template": """\
A `File` referencing a template for a shell script to process and sign.
""",
        "resolved_alticonstool": """\
A `struct` from `ctx.resolve_tools` referencing a tool to insert alternate icons entries in the app
bundle's `Info.plist`.
""",
        "resolved_bundletool": """\
A `struct` from `ctx.resolve_tools` referencing a tool to create an Apple bundle by taking a list of
files/ZIPs and destinations paths to build the directory structure for those files.
""",
        "resolved_bundletool_experimental": """\
A `struct` from `ctx.resolve_tools` referencing an experimental tool to create an Apple bundle by
combining the bundling, post-processing, and signing steps into a single action that eliminates the
archiving step.
""",
        "resolved_clangrttool": """\
A `struct` from `ctx.resolve_tools` referencing a tool to find all Clang runtime libs linked to a
binary.
""",
        "resolved_codesigningtool": """\
A `struct` from `ctx.resolve_tools` referencing a tool to select the appropriate signing identity
for Apple apps and Apple executable bundles.
""",
        "resolved_dossier_codesigningtool": """\
A `struct` from `ctx.resolve_tools` referencing a tool to generate codesigning dossiers.
""",
        "resolved_imported_dynamic_framework_processor": """\
A `struct` from `ctx.resolve_tools` referencing a tool to process an imported dynamic framework
such that the given framework only contains the same slices as the app binary, every file belonging
to the dynamic framework is copied to a temporary location, and the dynamic framework is codesigned
and zipped as a cacheable artifact.
""",
        "resolved_plisttool": """\
A `struct` from `ctx.resolve_tools` referencing a tool to perform plist operations such as variable
substitution, merging, and conversion of plist files to binary format.
""",
        "resolved_provisioning_profile_tool": """\
A `struct` from `ctx.resolve_tools` referencing a tool that extracts entitlements from a
provisioning profile.
""",
        "resolved_swift_stdlib_tool": """\
A `struct` from `ctx.resolve_tools` referencing a tool that copies and lipos Swift stdlibs required
for the target to run.
""",
        "resolved_xctoolrunner": """\
A `struct` from `ctx.resolve_tools` referencing a tool that acts as a wrapper for xcrun actions.
""",
    },
)

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
`depset` of `string`s representing transitive include paths which are needed by
IDEs to be used for indexing the test sources.
""",
        "module_maps": """
`depset` of `File`s representing module maps which are needed by IDEs to be used
for indexing the test sources.
""",
        "module_name": """
`string` representing the module name used by the test's sources. This is only
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
`depset` of `string`s representing the labels of all immediate deps of the test.
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

AppleStaticXcframeworkBundleInfo = provider(
    doc = """
Denotes that a target is a static library XCFramework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an XCFramework bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is an XCFramework should use this provider to describe that
requirement.
""",
    fields = {},
)

AppleXcframeworkBundleInfo = provider(
    doc = """
Denotes that a target is an XCFramework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an XCFramework bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is an XCFramework should use this provider to describe that
requirement.
""",
    fields = {},
)

IosApplicationBundleInfo = provider(
    doc = """
Denotes that a target is an iOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS application bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is an iOS application should use this provider to describe that
requirement.
""",
    fields = {},
)

IosAppClipBundleInfo = provider(
    doc = """
Denotes that a target is an iOS app clip.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS app clip bundle (and
not some other Apple bundle). Rule authors who wish to require that a dependency
is an iOS app clip should use this provider to describe that requirement.
""",
    fields = {},
)

IosExtensionBundleInfo = provider(
    doc = """
Denotes that a target is an iOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is an iOS application extension should use this
provider to describe that requirement.
""",
    fields = {},
)

IosFrameworkBundleInfo = provider(
    doc = """
Denotes that a target is an iOS dynamic framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS dynamic framework
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an iOS dynamic framework should use this provider to describe
that requirement.
""",
    fields = {},
)

IosStaticFrameworkBundleInfo = provider(
    doc = """
Denotes that a target is an iOS static framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS static framework
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an iOS static framework should use this provider to describe
that requirement.
""",
    fields = {},
)

IosImessageApplicationBundleInfo = provider(
    doc = """
Denotes that a target is an iOS iMessage application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS iMessage application
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an iOS iMessage application should use this provider to describe
that requirement.
""",
    fields = {},
)

IosImessageExtensionBundleInfo = provider(
    doc = """
Denotes that a target is an iOS iMessage extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS iMessage extension
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an iOS iMessage extension should use this provider to describe
that requirement.
""",
    fields = {},
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

IosXcTestBundleInfo = provider(
    doc = """
Denotes a target that is an iOS .xctest bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS .xctest bundle (and
not some other Apple bundle). Rule authors who wish to require that a dependency
is an iOS .xctest bundle should use this provider to describe that requirement.
""",
    fields = {},
)

MacosApplicationBundleInfo = provider(
    doc = """
Denotes that a target is a macOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS application bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS application should use this provider to describe that
requirement.
""",
    fields = {},
)

MacosBundleBundleInfo = provider(
    doc = """
Denotes that a target is a macOS loadable bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS loadable bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS loadable bundle should use this provider to describe that
requirement.
""",
    fields = {},
)

MacosExtensionBundleInfo = provider(
    doc = """
Denotes that a target is a macOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is a macOS application extension should use this
provider to describe that requirement.
""",
    fields = {},
)

MacosKernelExtensionBundleInfo = provider(
    doc = """
Denotes that a target is a macOS kernel extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS kernel extension
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS kernel extension should use this provider to describe that
requirement.
""",
    fields = {},
)

MacosQuickLookPluginBundleInfo = provider(
    doc = """
Denotes that a target is a macOS Quick Look Generator bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS Quick Look generator
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is a macOS Quick Look generator should use this provider to describe
that requirement.
""",
    fields = {},
)

MacosSpotlightImporterBundleInfo = provider(
    doc = """
Denotes that a target is a macOS Spotlight Importer bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS Spotlight importer
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS Spotlight importer should use this provider to describe that
requirement.
""",
    fields = {},
)

MacosXPCServiceBundleInfo = provider(
    doc = """
Denotes that a target is a macOS XPC Service bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS XPC service
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS XPC service should use this provider to describe that
requirement.
""",
    fields = {},
)

MacosXcTestBundleInfo = provider(
    doc = """
Denotes a target that is a macOS .xctest bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS .xctest bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS .xctest bundle should use this provider to describe that
requirement.
""",
    fields = {},
)

TvosApplicationBundleInfo = provider(
    doc = """
Denotes that a target is a tvOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a tvOS application bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a tvOS application should use this provider to describe that
requirement.
""",
    fields = {},
)

TvosExtensionBundleInfo = provider(
    doc = """
Denotes that a target is a tvOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a tvOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is a tvOS application extension should use this
provider to describe that requirement.
""",
    fields = {},
)

TvosFrameworkBundleInfo = provider(
    doc = """
Denotes that a target is a tvOS dynamic framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a tvOS dynamic framework
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is a tvOS dynamic framework should use this provider to describe
that requirement.
""",
    fields = {},
)

TvosStaticFrameworkBundleInfo = provider(
    doc = """
Denotes that a target is an tvOS static framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a tvOS static framework
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is a tvOS static framework should use this provider to describe
that requirement.
""",
    fields = {},
)

TvosXcTestBundleInfo = provider(
    doc = """
Denotes a target that is a tvOS .xctest bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a tvOS .xctest bundle (and
not some other Apple bundle). Rule authors who wish to require that a dependency
is a tvOS .xctest bundle should use this provider to describe that requirement.
""",
    fields = {},
)

WatchosApplicationBundleInfo = provider(
    doc = """
Denotes that a target is a watchOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a watchOS application
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is a watchOS application should use this provider to describe that
requirement.
""",
    fields = {},
)

WatchosExtensionBundleInfo = provider(
    doc = """
Denotes that a target is a watchOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a watchOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is a watchOS application extension should use this
provider to describe that requirement.
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

WatchosXcTestBundleInfo = provider(
    doc = """
Denotes a target that is a watchOS .xctest bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a watchOS .xctest bundle (and
not some other Apple bundle). Rule authors who wish to require that a dependency
is a watchOS .xctest bundle should use this provider to describe that requirement.
""",
    fields = {},
)
