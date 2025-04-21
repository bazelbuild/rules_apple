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
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

def make_banned_init(*, preferred_public_factory = None, provider_name):
    """Generates a lambda with a fail(...) for providers to dictate preferred initializer patterns.

    Args:
        preferred_public_factory: Optional. An `apple_provider` prefixed public factory method for
            users of the provider to call instead, if one exists.
        provider_name: The name of the provider to reference in error messaging.

    Returns:
        A lambda with a fail(...) for providers that can't be publicly initialized, or which must
        recommend an alternative public interface.
    """
    if preferred_public_factory:
        return lambda: fail("""
{provider} is a provider that must be initialized through apple_provider.{preferred_public_factory}
""".format(
            provider = provider_name,
            preferred_public_factory = preferred_public_factory,
        ))
    return lambda: fail("""
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
    init = make_banned_init(provider_name = "AppleBaseBundleIdInfo"),
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
        "bundle_id": """
`String`. The bundle identifier of the binary as reflected in its embedded Info.plist, which will be
applied if one was declared with the `bundle_id` attribute.
""",
        "product_type": """
`String`. The dot-separated product type identifier associated with the binary (for example,
`com.apple.product-type.tool`).
""",
    },
    init = make_banned_init(provider_name = "AppleBinaryInfo"),
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
        "archs": """
`List` of `String`s. The architectures that the bundle supports (i.e. `arm64` for Apple Silicon
simulators and device builds).
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
        "device_families": """
`List` of `String`s. Device families supported by the target being built (i.e. `["iphone", "ipad"]`
for iOS bundles that support iPhones and iPad target devices).
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
        "target_environment": """
`String`. The environment that the bundle was built for, (i.e. `device` for iOS device builds,
`simulator` for iOS simulator builds).
""",
        "uses_swift": """
Boolean. True if Swift is used by the target propagating this
provider. This does not consider embedded bundles; for example, an
Objective-C application containing a Swift extension would have this field
set to true for the extension but false for the application.
""",
    },
    init = make_banned_init(provider_name = "AppleBundleInfo"),
)

AppleBundleArchiveSupportInfo, new_applebundlearchivesupportinfo = provider(
    doc = "Provides supporting files to be embedded within an xcarchive bundle.",
    fields = {
        "bundle_files": """
Required. A List of tuples of the format (parent_dir, files) where `parent_dir` is a String
indicating the parent directory structure from the root of the archive to the desired output
directory and `files` is a `depset` of `File`s referencing the files to be placed there.
""",
        "bundle_zips": """
Required. A List of tuples of the format (parent_dir, files) where `parent_dir` is a String
indicating the parent directory structure from the root of the archive to the desired output
directory and `files` is a `depset` of `File`s referencing the ZIP files to be extracted there.
""",
    },
    init = make_banned_init(provider_name = "AppleBundleArchiveSupportInfo"),
)

AppleBundleVersionInfo, new_applebundleversioninfo = provider(
    doc = "Provides versioning information for an Apple bundle.",
    fields = {
        "version_file": """
Required. A `File` containing JSON-formatted text describing the version number information
propagated by the target.

It contains two keys:

*   `build_version`, which corresponds to `CFBundleVersion`.

*   `short_version_string`, which corresponds to `CFBundleShortVersionString`.
""",
    },
    init = make_banned_init(
        provider_name = "AppleBundleVersionInfo",
        preferred_public_factory = "make_apple_bundle_version_info(...)",
    ),
)

def make_apple_bundle_version_info(*, version_file):
    """Creates a new instance of the `AppleBundleVersionInfo` provider.

    Args:
        version_file: Required. See the docs on `AppleBundleVersionInfo`.

    Returns:
        A new `AppleBundleVersionInfo` provider based on the supplied arguments.
    """
    if type(version_file) != "File":
        fail("""
Error: Expected "version_file" to be of type "File".

Received unexpected type "{actual_type}".
""".format(actual_type = type(version_file)))

    return new_applebundleversioninfo(version_file = version_file)

AppleCodesigningDossierInfo, new_applecodesigningdossierinfo = provider(
    doc = "Provides information around the use of a code signing dossier.",
    fields = {
        "dossier": """
A `File` reference to the code signing dossier zip that acts as a direct dependency of the given
target if one was generated.
""",
    },
    init = make_banned_init(provider_name = "AppleCodesigningDossierInfo"),
)

AppleDebugOutputsInfo, new_appledebugoutputsinfo = provider(
    """
Holds debug outputs of an Apple binary rule.

This provider is DEPRECATED. Preferably use `AppleDsymBundleInfo` instead.

""",
    fields = {"outputs_map": """
A dictionary of: `{ [ARCH]: { "dsym_binary": File, "linkmap": File }`. Where `ARCH` is any Apple
architecture such as "arm64" or "armv7".
"""},
    init = make_banned_init(provider_name = "AppleDebugOutputsInfo"),
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
    init = make_banned_init(provider_name = "AppleDsymBundleInfo"),
)

AppleExecutableBinaryInfo, new_appleexecutablebinaryinfo = provider(
    doc = """
Contains the executable binary output that was built using
`link_multi_arch_binary` with the `executable` binary type.
""",
    fields = {
        "binary": """\
The executable binary artifact output by `link_multi_arch_binary`.
""",
        "cc_info": """\
A `CcInfo` which contains information about the transitive dependencies linked
into the binary.
""",
    },
    init = make_banned_init(provider_name = "AppleExecutableBinaryInfo"),
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
    init = make_banned_init(provider_name = "AppleExtraOutputsInfo"),
)

AppleFrameworkBundleInfo, new_appleframeworkbundleinfo = provider(
    doc = """
Denotes a target is an Apple framework bundle.

This provider does not reference 3rd party or precompiled frameworks.
Propagated by Apple framework rules: `ios_framework`, and `tvos_framework`.
""",
    fields = {},
    init = make_banned_init(provider_name = "AppleFrameworkBundleInfo"),
)

AppleFrameworkImportInfo, new_appleframeworkimportinfo = provider(
    doc = """
Provider that propagates information about 3rd party imported framework targets.

Propagated by framework and XCFramework import rules: `apple_dynamic_framework_import`,
`apple_dynamic_xcframework_import`, `apple_static_framework_import`, and
`apple_static_xcframework_import`
""",
    fields = {
        "binary_imports": """
`depset` of `File`s that represent framework binary files that need to be bundled in the top level
bundle under the Frameworks directory.
""",
        "bundling_imports": """
`depset` of `File`s that represent framework imports that need to be bundled in the top level bundle
under the Frameworks directory.
""",
        "build_archs": """
`depset` of `String`s that represent binary architectures reported from the current build.
""",
        "signature_files": """
`depset` of `Files`s that represent signature xml plists that need to be bundled in the Signatures
subfolder of the archive (IPA or xcarchive).
""",
    },
    init = make_banned_init(provider_name = "AppleFrameworkImportInfo"),
)

def merge_apple_framework_import_info(apple_framework_import_infos):
    """Merges multiple `AppleFrameworkImportInfo` into one.

    Args:
        apple_framework_import_infos: List of `AppleFrameworkImportInfo` to be merged.

    Returns:
        A new `AppleFrameworkImportInfo` provider based on the contents of the providers supplied by
        `apple_framework_import_infos`.
    """
    transitive_binary_imports = []
    transitive_bundling_imports = []
    transitive_signature_files = []
    build_archs = []

    for framework_info in apple_framework_import_infos:
        if framework_info.binary_imports:
            transitive_binary_imports.append(framework_info.binary_imports)
        if framework_info.bundling_imports:
            transitive_bundling_imports.append(framework_info.bundling_imports)
        if framework_info.signature_files:
            transitive_signature_files.append(framework_info.signature_files)
        build_archs.append(framework_info.build_archs)

    return new_appleframeworkimportinfo(
        binary_imports = depset(transitive = transitive_binary_imports),
        bundling_imports = depset(transitive = transitive_bundling_imports),
        build_archs = depset(transitive = build_archs),
        signature_files = depset(transitive = transitive_signature_files),
    )

ApplePlatformInfo, new_appleplatforminfo = provider(
    doc = "Provides information for the currently selected Apple platforms.",
    fields = {
        "target_arch": """
`String` representing the selected target architecture or cpu type.
""",
        "target_build_config": """
'configuration' representing the selected target's build configuration.
""",
        "target_environment": """
`String` representing the selected target environment (e.g. "device", "simulator").
""",
        "target_os": """
`String` representing the selected Apple OS.
""",
    },
    init = make_banned_init(provider_name = "ApplePlatformInfo"),
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
    init = make_banned_init(provider_name = "AppleResourceBundleInfo"),
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
    init = make_banned_init(provider_name = "AppleResourceInfo"),
)

AppleResourceLocalesInfo, new_appleresourcelocalesinfo = provider(
    doc = """
Provides an allow list of locales to be included in the bundle.
Locales not in this list will be excluded from the bundle.
""",
    fields = {
        "locales_to_include": """
`StringList`. List of [Unicode Locale Identifier](https://unicode.org/reports/tr35/#Identifiers)
strings in `<language_id>[_<region_subtag>]` format (ex: `[en, pt_PT]`)
""",
    },
    init = make_banned_init(provider_name = "AppleResourceLocalesInfo"),
)

AppleSharedCapabilityInfo, new_applesharedcapabilityinfo = provider(
    doc = "Provides information on a mergeable set of shared capabilities.",
    fields = {
        "base_bundle_id": """
`String`. The bundle ID prefix, composed from an organization ID and an optional variant name.
""",
    },
    init = make_banned_init(provider_name = "AppleSharedCapabilityInfo"),
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
    init = make_banned_init(provider_name = "AppleStaticXcframeworkBundleInfo"),
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
    init = make_banned_init(provider_name = "AppleTestInfo"),
)

AppleTestRunnerInfo, new_appletestrunnerinfo = provider(
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
    init = make_banned_init(
        provider_name = "AppleTestRunnerInfo",
        preferred_public_factory = "make_apple_test_runner_info(...)",
    ),
)

def make_apple_test_runner_info(**kwargs):
    """Creates a new instance of the AppleTestRunnerInfo provider.

    Args:
        **kwargs: A set of keyword arguments expected to match the fields of `AppleTestRunnerInfo`.
            See the documentation for `AppleTestRunnerInfo` for what these must be.

    Returns:
        A new `AppleTestRunnerInfo` provider based on the supplied arguments.
    """
    if "test_runner_template" not in kwargs or not kwargs["test_runner_template"]:
        fail("""
Error: Could not find the required argument "test_runner_template" needed to build an
AppleTestRunner provider.

Received the following arguments for make_apple_test_runner_info: {kwargs}
""".format(kwargs = ", ".join(kwargs.keys())))

    return new_appletestrunnerinfo(**kwargs)

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
    init = make_banned_init(provider_name = "AppleXcframeworkBundleInfo"),
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
    init = make_banned_init(provider_name = "IosApplicationBundleInfo"),
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
    init = make_banned_init(provider_name = "IosAppClipBundleInfo"),
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
    init = make_banned_init(provider_name = "IosExtensionBundleInfo"),
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
    init = make_banned_init(provider_name = "IosFrameworkBundleInfo"),
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
    init = make_banned_init(provider_name = "IosStaticFrameworkBundleInfo"),
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
    init = make_banned_init(provider_name = "IosImessageApplicationBundleInfo"),
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
    init = make_banned_init(provider_name = "IosImessageExtensionBundleInfo"),
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
    init = make_banned_init(provider_name = "IosXcTestBundleInfo"),
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
    init = make_banned_init(provider_name = "MacosApplicationBundleInfo"),
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
    init = make_banned_init(provider_name = "MacosBundleBundleInfo"),
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
    init = make_banned_init(provider_name = "MacosExtensionBundleInfo"),
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
    init = make_banned_init(provider_name = "MacosKernelExtensionBundleInfo"),
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
    init = make_banned_init(provider_name = "MacosSpotlightImporterBundleInfo"),
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
    init = make_banned_init(provider_name = "MacosXPCServiceBundleInfo"),
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
    init = make_banned_init(provider_name = "MacosXcTestBundleInfo"),
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
    init = make_banned_init(provider_name = "TvosApplicationBundleInfo"),
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
    init = make_banned_init(provider_name = "TvosExtensionBundleInfo"),
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
    init = make_banned_init(provider_name = "TvosFrameworkBundleInfo"),
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
    init = make_banned_init(provider_name = "TvosStaticFrameworkBundleInfo"),
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
    init = make_banned_init(provider_name = "TvosXcTestBundleInfo"),
)

VisionosApplicationBundleInfo, new_visionosapplicationbundleinfo = provider(
    doc = """
Denotes that a target is a visionOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a visionOS application
bundle (and not some other Apple bundle). Rule authors who wish to require that a
dependency is a visionOS application should use this provider to describe that
requirement.
""",
    fields = {},
    init = make_banned_init(provider_name = "VisionosApplicationBundleInfo"),
)

VisionosXcTestBundleInfo, new_visionosxctestbundleinfo = provider(
    doc = """
Denotes a target that is a visionOS .xctest bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a visionOS .xctest bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a visionOS .xctest bundle  should use this provider to describe
that requirement.
""",
    fields = {},
    init = make_banned_init(provider_name = "VisionosXcTestBundleInfo"),
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
    init = make_banned_init(provider_name = "WatchosApplicationBundleInfo"),
)

WatchosExtensionBundleInfo, new_watchosextensionbundleinfo = provider(
    doc = """
Denotes that a target is a watchOS extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a watchOS extension bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a watchOS extension should use this provider to describe that
requirement.
""",
    fields = {},
    init = make_banned_init(provider_name = "WatchosExtensionBundleInfo"),
)

WatchosFrameworkBundleInfo, new_watchosframeworkbundleinfo = provider(
    doc = """
Denotes that a target is a watchOS dynamic framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a watchOS framework bundle
(and not some other Apple bundle). Rule authors who wish to
require that a dependency is a watchOS framework should use this
provider to describe that requirement.
""",
    fields = {},
    init = make_banned_init(provider_name = "WatchosFrameworkBundleInfo"),
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
    init = make_banned_init(provider_name = "WatchosXcTestBundleInfo"),
)
