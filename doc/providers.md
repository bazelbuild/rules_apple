<!-- Generated with Stardoc, Do Not Edit! -->

# Providers

Defines providers and related types used throughout the rules in this repository.

Most users will not need to use these providers to simply create and build Apple
targets, but if you want to write your own custom rules that interact with these
rules, then you will use these providers to communicate between them.

These providers are part of the public API of the bundling rules. Other rules
that want to propagate information to the bundling rules or that want to
consume the bundling rules as their own inputs should use these to handle the
relevant information that they need.

<a id="#AppleBinaryInfo"></a>

## AppleBinaryInfo

<pre>
AppleBinaryInfo(<a href="#AppleBinaryInfo-binary">binary</a>, <a href="#AppleBinaryInfo-product_type">product_type</a>)
</pre>


Provides information about an Apple binary target.

This provider propagates general information about an Apple binary that is not
specific to any particular binary type.


**FIELDS**


| Name  | Description |
| :------------- | :------------- |
| <a id="AppleBinaryInfo-binary"></a>binary |  <code>File</code>. The binary (executable, dynamic library, etc.) file that the target represents.    |
| <a id="AppleBinaryInfo-product_type"></a>product_type |  <code>string</code>. The dot-separated product type identifier associated with the binary (for example, <code>com.apple.product-type.tool</code>).    |


<a id="#AppleBundleInfo"></a>

## AppleBundleInfo

<pre>
AppleBundleInfo(<a href="#AppleBundleInfo-archive">archive</a>, <a href="#AppleBundleInfo-archive_root">archive_root</a>, <a href="#AppleBundleInfo-binary">binary</a>, <a href="#AppleBundleInfo-bundle_extension">bundle_extension</a>, <a href="#AppleBundleInfo-bundle_id">bundle_id</a>, <a href="#AppleBundleInfo-bundle_name">bundle_name</a>,
                <a href="#AppleBundleInfo-executable_name">executable_name</a>, <a href="#AppleBundleInfo-entitlements">entitlements</a>, <a href="#AppleBundleInfo-extension_safe">extension_safe</a>, <a href="#AppleBundleInfo-infoplist">infoplist</a>,
                <a href="#AppleBundleInfo-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#AppleBundleInfo-minimum_os_version">minimum_os_version</a>, <a href="#AppleBundleInfo-platform_type">platform_type</a>, <a href="#AppleBundleInfo-product_type">product_type</a>,
                <a href="#AppleBundleInfo-uses_swift">uses_swift</a>)
</pre>


Provides information about an Apple bundle target.

This provider propagates general information about an Apple bundle that is not
specific to any particular bundle type.
It is propagated by most bundling rulesâapplications, extensions, frameworks, test bundles, and so forth.


**FIELDS**


| Name  | Description |
| :------------- | :------------- |
| <a id="AppleBundleInfo-archive"></a>archive |  <code>File</code>. The archive that contains the built application.    |
| <a id="AppleBundleInfo-archive_root"></a>archive_root |  <code>string</code>. The file system path (relative to the workspace root) where the signed bundle was constructed (before archiving). Other rules *should not* depend on this field; it is intended to support IDEs that want to read that path from the provider to avoid unzipping the output archive.    |
| <a id="AppleBundleInfo-binary"></a>binary |  <code>File</code>. The binary (executable, dynamic library, etc.) that was bundled. The physical file is identical to the one inside the bundle except that it is always unsigned, so note that it is _not_ a path to the binary inside your output bundle. The primary purpose of this field is to provide a way to access the binary directly at analysis time; for example, for code coverage.    |
| <a id="AppleBundleInfo-bundle_extension"></a>bundle_extension |  <code>string</code>. The bundle extension.    |
| <a id="AppleBundleInfo-bundle_id"></a>bundle_id |  <code>string</code>. The bundle identifier (i.e., <code>CFBundleIdentifier</code> in <code>Info.plist</code>) of the bundle.    |
| <a id="AppleBundleInfo-bundle_name"></a>bundle_name |  <code>string</code>. The name of the bundle, without the extension.    |
| <a id="AppleBundleInfo-executable_name"></a>executable_name |  <code>string</code>. The name of the executable that was bundled.    |
| <a id="AppleBundleInfo-entitlements"></a>entitlements |  <code>File</code>. Entitlements file used to codesign, if any.    |
| <a id="AppleBundleInfo-extension_safe"></a>extension_safe |  Boolean. True if the target propagating this provider was compiled and linked with -application-extension, restricting it to extension-safe APIs only.    |
| <a id="AppleBundleInfo-infoplist"></a>infoplist |  <code>File</code>. The complete (binary-formatted) <code>Info.plist</code> file for the bundle.    |
| <a id="AppleBundleInfo-minimum_deployment_os_version"></a>minimum_deployment_os_version |  <code>string</code>. The minimum deployment OS version (as a dotted version number like "9.0") that this bundle was built to support. This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.    |
| <a id="AppleBundleInfo-minimum_os_version"></a>minimum_os_version |  <code>string</code>. The minimum OS version (as a dotted version number like "9.0") that this bundle was built to support.    |
| <a id="AppleBundleInfo-platform_type"></a>platform_type |  <code>string</code>. The platform type for the bundle (i.e. <code>ios</code> for iOS bundles).    |
| <a id="AppleBundleInfo-product_type"></a>product_type |  <code>string</code>. The dot-separated product type identifier associated with the bundle (for example, <code>com.apple.product-type.application</code>).    |
| <a id="AppleBundleInfo-uses_swift"></a>uses_swift |  Boolean. True if Swift is used by the target propagating this provider. This does not consider embedded bundles; for example, an Objective-C application containing a Swift extension would have this field set to true for the extension but false for the application.    |


<a id="#AppleBundleVersionInfo"></a>

## AppleBundleVersionInfo

<pre>
AppleBundleVersionInfo(<a href="#AppleBundleVersionInfo-version_file">version_file</a>)
</pre>

Provides versioning information for an Apple bundle.

**FIELDS**


| Name  | Description |
| :------------- | :------------- |
| <a id="AppleBundleVersionInfo-version_file"></a>version_file |  A <code>File</code> containing JSON-formatted text describing the version number information propagated by the target. It contains two keys: <code>build_version</code>, which corresponds to <code>CFBundleVersion</code>; and <code>short_version_string</code>, which corresponds to <code>CFBundleShortVersionString</code>.    |


<a id="#AppleExtraOutputsInfo"></a>

## AppleExtraOutputsInfo

<pre>
AppleExtraOutputsInfo(<a href="#AppleExtraOutputsInfo-files">files</a>)
</pre>


Provides information about extra outputs that should be produced from the build.

This provider propagates supplemental files that should be produced as outputs
even if the bundle they are associated with is not a direct output of the rule.
For example, an application that contains an extension will build both targets
but only the application will be a rule output. However, if dSYM bundles are
also being generated, we do want to produce the dSYMs for *both* application and
extension as outputs of the build, not just the dSYMs of the explicit target
being built (the application).


**FIELDS**


| Name  | Description |
| :------------- | :------------- |
| <a id="AppleExtraOutputsInfo-files"></a>files |  <code>depset</code> of <code>File</code>s. These files will be propagated from embedded bundles (such as frameworks and extensions) to the top-level bundle (such as an application) to ensure that they are explicitly produced as outputs of the build.    |


<a id="#AppleFrameworkImportInfo"></a>

## AppleFrameworkImportInfo

<pre>
AppleFrameworkImportInfo(<a href="#AppleFrameworkImportInfo-framework_imports">framework_imports</a>, <a href="#AppleFrameworkImportInfo-dsym_imports">dsym_imports</a>, <a href="#AppleFrameworkImportInfo-build_archs">build_archs</a>, <a href="#AppleFrameworkImportInfo-debug_info_binaries">debug_info_binaries</a>)
</pre>

Provider that propagates information about framework import targets.

**FIELDS**


| Name  | Description |
| :------------- | :------------- |
| <a id="AppleFrameworkImportInfo-framework_imports"></a>framework_imports |  Depset of Files that represent framework imports that need to be bundled in the top level application bundle under the Frameworks directory.    |
| <a id="AppleFrameworkImportInfo-dsym_imports"></a>dsym_imports |  Depset of Files that represent dSYM imports that need to be processed to provide .symbols files for packaging into the .ipa file if requested in the build with --define=apple.package_symbols=(yes|true|1).    |
| <a id="AppleFrameworkImportInfo-build_archs"></a>build_archs |  Depset of strings that represent binary architectures reported from the current build.    |
| <a id="AppleFrameworkImportInfo-debug_info_binaries"></a>debug_info_binaries |  Depset of Files that represent framework binaries and dSYM binaries that provide debug info.    |


<a id="#AppleResourceBundleInfo"></a>

## AppleResourceBundleInfo

<pre>
AppleResourceBundleInfo()
</pre>


Denotes that a target is an Apple resource bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an Apple resource bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is an Apple resource bundle should use this provider to describe that
requirement.


**FIELDS**



<a id="#AppleResourceInfo"></a>

## AppleResourceInfo

<pre>
AppleResourceInfo(<a href="#AppleResourceInfo-alternate_icons">alternate_icons</a>, <a href="#AppleResourceInfo-asset_catalogs">asset_catalogs</a>, <a href="#AppleResourceInfo-datamodels">datamodels</a>, <a href="#AppleResourceInfo-infoplists">infoplists</a>, <a href="#AppleResourceInfo-metals">metals</a>, <a href="#AppleResourceInfo-mlmodels">mlmodels</a>, <a href="#AppleResourceInfo-plists">plists</a>,
                  <a href="#AppleResourceInfo-pngs">pngs</a>, <a href="#AppleResourceInfo-processed">processed</a>, <a href="#AppleResourceInfo-storyboards">storyboards</a>, <a href="#AppleResourceInfo-strings">strings</a>, <a href="#AppleResourceInfo-texture_atlases">texture_atlases</a>, <a href="#AppleResourceInfo-unprocessed">unprocessed</a>, <a href="#AppleResourceInfo-xibs">xibs</a>, <a href="#AppleResourceInfo-owners">owners</a>,
                  <a href="#AppleResourceInfo-processed_origins">processed_origins</a>, <a href="#AppleResourceInfo-unowned_resources">unowned_resources</a>)
</pre>

Provider that propagates buckets of resources that are differentiated by type.

**FIELDS**


| Name  | Description |
| :------------- | :------------- |
| <a id="AppleResourceInfo-alternate_icons"></a>alternate_icons |  Alternate icons to be included in the App bundle.    |
| <a id="AppleResourceInfo-asset_catalogs"></a>asset_catalogs |  Resources that need to be embedded into Assets.car.    |
| <a id="AppleResourceInfo-datamodels"></a>datamodels |  Datamodel files.    |
| <a id="AppleResourceInfo-infoplists"></a>infoplists |  Plist files to be merged and processed. Plist files that should not be merged into the root Info.plist should be propagated in <code>plists</code>. Because of this, infoplists should only be bucketed with the <code>bucketize_typed</code> method.    |
| <a id="AppleResourceInfo-metals"></a>metals |  Metal Shading Language source files to be compiled into a single .metallib file and bundled at the top level.    |
| <a id="AppleResourceInfo-mlmodels"></a>mlmodels |  Core ML model files that should be processed and bundled at the top level.    |
| <a id="AppleResourceInfo-plists"></a>plists |  Resource Plist files that should not be merged into Info.plist    |
| <a id="AppleResourceInfo-pngs"></a>pngs |  PNG images which are not bundled in an .xcassets folder.    |
| <a id="AppleResourceInfo-processed"></a>processed |  Typed resources that have already been processed.    |
| <a id="AppleResourceInfo-storyboards"></a>storyboards |  Storyboard files.    |
| <a id="AppleResourceInfo-strings"></a>strings |  Localization strings files.    |
| <a id="AppleResourceInfo-texture_atlases"></a>texture_atlases |  Texture atlas files.    |
| <a id="AppleResourceInfo-unprocessed"></a>unprocessed |  Generic resources not mapped to the other types.    |
| <a id="AppleResourceInfo-xibs"></a>xibs |  XIB Interface files.    |
| <a id="AppleResourceInfo-owners"></a>owners |  Depset of (resource, owner) pairs.    |
| <a id="AppleResourceInfo-processed_origins"></a>processed_origins |  Depset of (processed resource, resource list) pairs.    |
| <a id="AppleResourceInfo-unowned_resources"></a>unowned_resources |  Depset of unowned resources.    |


<a id="#AppleStaticXcframeworkBundleInfo"></a>

## AppleStaticXcframeworkBundleInfo

<pre>
AppleStaticXcframeworkBundleInfo()
</pre>


Denotes that a target is a static library XCFramework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an XCFramework bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is an XCFramework should use this provider to describe that
requirement.


**FIELDS**



<a id="#AppleSupportToolchainInfo"></a>

## AppleSupportToolchainInfo

<pre>
AppleSupportToolchainInfo(<a href="#AppleSupportToolchainInfo-dsym_info_plist_template">dsym_info_plist_template</a>, <a href="#AppleSupportToolchainInfo-process_and_sign_template">process_and_sign_template</a>,
                          <a href="#AppleSupportToolchainInfo-resolved_alticonstool">resolved_alticonstool</a>, <a href="#AppleSupportToolchainInfo-resolved_bundletool">resolved_bundletool</a>,
                          <a href="#AppleSupportToolchainInfo-resolved_bundletool_experimental">resolved_bundletool_experimental</a>, <a href="#AppleSupportToolchainInfo-resolved_clangrttool">resolved_clangrttool</a>,
                          <a href="#AppleSupportToolchainInfo-resolved_codesigningtool">resolved_codesigningtool</a>, <a href="#AppleSupportToolchainInfo-resolved_dossier_codesigningtool">resolved_dossier_codesigningtool</a>,
                          <a href="#AppleSupportToolchainInfo-resolved_imported_dynamic_framework_processor">resolved_imported_dynamic_framework_processor</a>, <a href="#AppleSupportToolchainInfo-resolved_plisttool">resolved_plisttool</a>,
                          <a href="#AppleSupportToolchainInfo-resolved_provisioning_profile_tool">resolved_provisioning_profile_tool</a>, <a href="#AppleSupportToolchainInfo-resolved_swift_stdlib_tool">resolved_swift_stdlib_tool</a>,
                          <a href="#AppleSupportToolchainInfo-resolved_xctoolrunner">resolved_xctoolrunner</a>)
</pre>


Propagates information about an Apple toolchain to internal bundling rules that use the toolchain.

This provider exists as an internal detail for the rules to reference common, executable tools and
files used as script templates for the purposes of executing Apple actions. Defined by the
`apple_support_toolchain` rule.


**FIELDS**


| Name  | Description |
| :------------- | :------------- |
| <a id="AppleSupportToolchainInfo-dsym_info_plist_template"></a>dsym_info_plist_template |  A <code>File</code> referencing a plist template for dSYM bundles.    |
| <a id="AppleSupportToolchainInfo-process_and_sign_template"></a>process_and_sign_template |  A <code>File</code> referencing a template for a shell script to process and sign.    |
| <a id="AppleSupportToolchainInfo-resolved_alticonstool"></a>resolved_alticonstool |  A <code>struct</code> from <code>ctx.resolve_tools</code> referencing a tool to insert alternate icons entries in the app bundle's <code>Info.plist</code>.    |
| <a id="AppleSupportToolchainInfo-resolved_bundletool"></a>resolved_bundletool |  A <code>struct</code> from <code>ctx.resolve_tools</code> referencing a tool to create an Apple bundle by taking a list of files/ZIPs and destinations paths to build the directory structure for those files.    |
| <a id="AppleSupportToolchainInfo-resolved_bundletool_experimental"></a>resolved_bundletool_experimental |  A <code>struct</code> from <code>ctx.resolve_tools</code> referencing an experimental tool to create an Apple bundle by combining the bundling, post-processing, and signing steps into a single action that eliminates the archiving step.    |
| <a id="AppleSupportToolchainInfo-resolved_clangrttool"></a>resolved_clangrttool |  A <code>struct</code> from <code>ctx.resolve_tools</code> referencing a tool to find all Clang runtime libs linked to a binary.    |
| <a id="AppleSupportToolchainInfo-resolved_codesigningtool"></a>resolved_codesigningtool |  A <code>struct</code> from <code>ctx.resolve_tools</code> referencing a tool to select the appropriate signing identity for Apple apps and Apple executable bundles.    |
| <a id="AppleSupportToolchainInfo-resolved_dossier_codesigningtool"></a>resolved_dossier_codesigningtool |  A <code>struct</code> from <code>ctx.resolve_tools</code> referencing a tool to generate codesigning dossiers.    |
| <a id="AppleSupportToolchainInfo-resolved_imported_dynamic_framework_processor"></a>resolved_imported_dynamic_framework_processor |  A <code>struct</code> from <code>ctx.resolve_tools</code> referencing a tool to process an imported dynamic framework such that the given framework only contains the same slices as the app binary, every file belonging to the dynamic framework is copied to a temporary location, and the dynamic framework is codesigned and zipped as a cacheable artifact.    |
| <a id="AppleSupportToolchainInfo-resolved_plisttool"></a>resolved_plisttool |  A <code>struct</code> from <code>ctx.resolve_tools</code> referencing a tool to perform plist operations such as variable substitution, merging, and conversion of plist files to binary format.    |
| <a id="AppleSupportToolchainInfo-resolved_provisioning_profile_tool"></a>resolved_provisioning_profile_tool |  A <code>struct</code> from <code>ctx.resolve_tools</code> referencing a tool that extracts entitlements from a provisioning profile.    |
| <a id="AppleSupportToolchainInfo-resolved_swift_stdlib_tool"></a>resolved_swift_stdlib_tool |  A <code>struct</code> from <code>ctx.resolve_tools</code> referencing a tool that copies and lipos Swift stdlibs required for the target to run.    |
| <a id="AppleSupportToolchainInfo-resolved_xctoolrunner"></a>resolved_xctoolrunner |  A <code>struct</code> from <code>ctx.resolve_tools</code> referencing a tool that acts as a wrapper for xcrun actions.    |


<a id="#AppleTestInfo"></a>

## AppleTestInfo

<pre>
AppleTestInfo(<a href="#AppleTestInfo-includes">includes</a>, <a href="#AppleTestInfo-module_maps">module_maps</a>, <a href="#AppleTestInfo-module_name">module_name</a>, <a href="#AppleTestInfo-non_arc_sources">non_arc_sources</a>, <a href="#AppleTestInfo-sources">sources</a>, <a href="#AppleTestInfo-swift_modules">swift_modules</a>,
              <a href="#AppleTestInfo-test_bundle">test_bundle</a>, <a href="#AppleTestInfo-test_host">test_host</a>, <a href="#AppleTestInfo-deps">deps</a>)
</pre>


Provider that test targets propagate to be used for IDE integration.

This includes information regarding test source files, transitive include paths,
transitive module maps, and transitive Swift modules. Test source files are
considered to be all of which belong to the first-level dependencies on the test
target.


**FIELDS**


| Name  | Description |
| :------------- | :------------- |
| <a id="AppleTestInfo-includes"></a>includes |  <code>depset</code> of <code>string</code>s representing transitive include paths which are needed by IDEs to be used for indexing the test sources.    |
| <a id="AppleTestInfo-module_maps"></a>module_maps |  <code>depset</code> of <code>File</code>s representing module maps which are needed by IDEs to be used for indexing the test sources.    |
| <a id="AppleTestInfo-module_name"></a>module_name |  <code>string</code> representing the module name used by the test's sources. This is only set if the test only contains a single top-level Swift dependency. This may be used by an IDE to identify the Swift module (if any) used by the test's sources.    |
| <a id="AppleTestInfo-non_arc_sources"></a>non_arc_sources |  <code>depset</code> of <code>File</code>s containing non-ARC sources from the test's immediate deps.    |
| <a id="AppleTestInfo-sources"></a>sources |  <code>depset</code> of <code>File</code>s containing sources and headers from the test's immediate deps.    |
| <a id="AppleTestInfo-swift_modules"></a>swift_modules |  <code>depset</code> of <code>File</code>s representing transitive swift modules which are needed by IDEs to be used for indexing the test sources.    |
| <a id="AppleTestInfo-test_bundle"></a>test_bundle |  The artifact representing the XCTest bundle for the test target.    |
| <a id="AppleTestInfo-test_host"></a>test_host |  The artifact representing the test host for the test target, if the test requires a test host.    |
| <a id="AppleTestInfo-deps"></a>deps |  <code>depset</code> of <code>string</code>s representing the labels of all immediate deps of the test. Only source files from these deps will be present in <code>sources</code>. This may be used by IDEs to differentiate a test target's transitive module maps from its direct module maps, as including the direct module maps may break indexing for the source files of the immediate deps.    |


<a id="#AppleTestRunnerInfo"></a>

## AppleTestRunnerInfo

<pre>
AppleTestRunnerInfo(<a href="#AppleTestRunnerInfo-execution_requirements">execution_requirements</a>, <a href="#AppleTestRunnerInfo-execution_environment">execution_environment</a>, <a href="#AppleTestRunnerInfo-test_environment">test_environment</a>,
                    <a href="#AppleTestRunnerInfo-test_runner_template">test_runner_template</a>)
</pre>


Provider that runner targets must propagate.

In addition to the fields, all the runfiles that the runner target declares will be added to the
test rules runfiles.


**FIELDS**


| Name  | Description |
| :------------- | :------------- |
| <a id="AppleTestRunnerInfo-execution_requirements"></a>execution_requirements |  Optional dictionary that represents the specific hardware requirements for this test.    |
| <a id="AppleTestRunnerInfo-execution_environment"></a>execution_environment |  Optional dictionary with the environment variables that are to be set in the test action, and are not propagated into the XCTest invocation. These values will _not_ be added into the %(test_env)s substitution, but will be set in the test action.    |
| <a id="AppleTestRunnerInfo-test_environment"></a>test_environment |  Optional dictionary with the environment variables that are to be propagated into the XCTest invocation. These values will be included in the %(test_env)s substitution and will _not_ be set in the test action.    |
| <a id="AppleTestRunnerInfo-test_runner_template"></a>test_runner_template |  Required template file that contains the specific mechanism with which the tests will be run. The *_ui_test and *_unit_test rules will substitute the following values:     * %(test_host_path)s:   Path to the app being tested.     * %(test_bundle_path)s: Path to the test bundle that contains the tests.     * %(test_env)s:         Environment variables for the XCTest invocation (e.g FOO=BAR,BAZ=QUX).     * %(test_type)s:        The test type, whether it is unit or UI.    |


<a id="#AppleXcframeworkBundleInfo"></a>

## AppleXcframeworkBundleInfo

<pre>
AppleXcframeworkBundleInfo()
</pre>


Denotes that a target is an XCFramework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an XCFramework bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is an XCFramework should use this provider to describe that
requirement.


**FIELDS**



<a id="#IosAppClipBundleInfo"></a>

## IosAppClipBundleInfo

<pre>
IosAppClipBundleInfo()
</pre>


Denotes that a target is an iOS app clip.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS app clip bundle (and
not some other Apple bundle). Rule authors who wish to require that a dependency
is an iOS app clip should use this provider to describe that requirement.


**FIELDS**



<a id="#IosApplicationBundleInfo"></a>

## IosApplicationBundleInfo

<pre>
IosApplicationBundleInfo()
</pre>


Denotes that a target is an iOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS application bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is an iOS application should use this provider to describe that
requirement.


**FIELDS**



<a id="#IosExtensionBundleInfo"></a>

## IosExtensionBundleInfo

<pre>
IosExtensionBundleInfo()
</pre>


Denotes that a target is an iOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is an iOS application extension should use this
provider to describe that requirement.


**FIELDS**



<a id="#IosFrameworkBundleInfo"></a>

## IosFrameworkBundleInfo

<pre>
IosFrameworkBundleInfo()
</pre>


Denotes that a target is an iOS dynamic framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS dynamic framework
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an iOS dynamic framework should use this provider to describe
that requirement.


**FIELDS**



<a id="#IosImessageApplicationBundleInfo"></a>

## IosImessageApplicationBundleInfo

<pre>
IosImessageApplicationBundleInfo()
</pre>


Denotes that a target is an iOS iMessage application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS iMessage application
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an iOS iMessage application should use this provider to describe
that requirement.


**FIELDS**



<a id="#IosImessageExtensionBundleInfo"></a>

## IosImessageExtensionBundleInfo

<pre>
IosImessageExtensionBundleInfo()
</pre>


Denotes that a target is an iOS iMessage extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS iMessage extension
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an iOS iMessage extension should use this provider to describe
that requirement.


**FIELDS**



<a id="#IosStaticFrameworkBundleInfo"></a>

## IosStaticFrameworkBundleInfo

<pre>
IosStaticFrameworkBundleInfo()
</pre>


Denotes that a target is an iOS static framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS static framework
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an iOS static framework should use this provider to describe
that requirement.


**FIELDS**



<a id="#IosStickerPackExtensionBundleInfo"></a>

## IosStickerPackExtensionBundleInfo

<pre>
IosStickerPackExtensionBundleInfo()
</pre>


Denotes that a target is an iOS Sticker Pack extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS Sticker Pack extension
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an iOS Sticker Pack extension should use this provider to describe
that requirement.


**FIELDS**



<a id="#IosXcTestBundleInfo"></a>

## IosXcTestBundleInfo

<pre>
IosXcTestBundleInfo()
</pre>


Denotes a target that is an iOS .xctest bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS .xctest bundle (and
not some other Apple bundle). Rule authors who wish to require that a dependency
is an iOS .xctest bundle should use this provider to describe that requirement.


**FIELDS**



<a id="#MacosApplicationBundleInfo"></a>

## MacosApplicationBundleInfo

<pre>
MacosApplicationBundleInfo()
</pre>


Denotes that a target is a macOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS application bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS application should use this provider to describe that
requirement.


**FIELDS**



<a id="#MacosBundleBundleInfo"></a>

## MacosBundleBundleInfo

<pre>
MacosBundleBundleInfo()
</pre>


Denotes that a target is a macOS loadable bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS loadable bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS loadable bundle should use this provider to describe that
requirement.


**FIELDS**



<a id="#MacosExtensionBundleInfo"></a>

## MacosExtensionBundleInfo

<pre>
MacosExtensionBundleInfo()
</pre>


Denotes that a target is a macOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is a macOS application extension should use this
provider to describe that requirement.


**FIELDS**



<a id="#MacosKernelExtensionBundleInfo"></a>

## MacosKernelExtensionBundleInfo

<pre>
MacosKernelExtensionBundleInfo()
</pre>


Denotes that a target is a macOS kernel extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS kernel extension
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS kernel extension should use this provider to describe that
requirement.


**FIELDS**



<a id="#MacosQuickLookPluginBundleInfo"></a>

## MacosQuickLookPluginBundleInfo

<pre>
MacosQuickLookPluginBundleInfo()
</pre>


Denotes that a target is a macOS Quick Look Generator bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS Quick Look generator
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is a macOS Quick Look generator should use this provider to describe
that requirement.


**FIELDS**



<a id="#MacosSpotlightImporterBundleInfo"></a>

## MacosSpotlightImporterBundleInfo

<pre>
MacosSpotlightImporterBundleInfo()
</pre>


Denotes that a target is a macOS Spotlight Importer bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS Spotlight importer
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS Spotlight importer should use this provider to describe that
requirement.


**FIELDS**



<a id="#MacosXPCServiceBundleInfo"></a>

## MacosXPCServiceBundleInfo

<pre>
MacosXPCServiceBundleInfo()
</pre>


Denotes that a target is a macOS XPC Service bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS XPC service
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS XPC service should use this provider to describe that
requirement.


**FIELDS**



<a id="#MacosXcTestBundleInfo"></a>

## MacosXcTestBundleInfo

<pre>
MacosXcTestBundleInfo()
</pre>


Denotes a target that is a macOS .xctest bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS .xctest bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS .xctest bundle should use this provider to describe that
requirement.


**FIELDS**



<a id="#TvosApplicationBundleInfo"></a>

## TvosApplicationBundleInfo

<pre>
TvosApplicationBundleInfo()
</pre>


Denotes that a target is a tvOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a tvOS application bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a tvOS application should use this provider to describe that
requirement.


**FIELDS**



<a id="#TvosExtensionBundleInfo"></a>

## TvosExtensionBundleInfo

<pre>
TvosExtensionBundleInfo()
</pre>


Denotes that a target is a tvOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a tvOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is a tvOS application extension should use this
provider to describe that requirement.


**FIELDS**



<a id="#TvosFrameworkBundleInfo"></a>

## TvosFrameworkBundleInfo

<pre>
TvosFrameworkBundleInfo()
</pre>


Denotes that a target is a tvOS dynamic framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a tvOS dynamic framework
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is a tvOS dynamic framework should use this provider to describe
that requirement.


**FIELDS**



<a id="#TvosStaticFrameworkBundleInfo"></a>

## TvosStaticFrameworkBundleInfo

<pre>
TvosStaticFrameworkBundleInfo()
</pre>


Denotes that a target is an tvOS static framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a tvOS static framework
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is a tvOS static framework should use this provider to describe
that requirement.


**FIELDS**



<a id="#TvosXcTestBundleInfo"></a>

## TvosXcTestBundleInfo

<pre>
TvosXcTestBundleInfo()
</pre>


Denotes a target that is a tvOS .xctest bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a tvOS .xctest bundle (and
not some other Apple bundle). Rule authors who wish to require that a dependency
is a tvOS .xctest bundle should use this provider to describe that requirement.


**FIELDS**



<a id="#WatchosApplicationBundleInfo"></a>

## WatchosApplicationBundleInfo

<pre>
WatchosApplicationBundleInfo()
</pre>


Denotes that a target is a watchOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a watchOS application
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is a watchOS application should use this provider to describe that
requirement.


**FIELDS**



<a id="#WatchosExtensionBundleInfo"></a>

## WatchosExtensionBundleInfo

<pre>
WatchosExtensionBundleInfo()
</pre>


Denotes that a target is a watchOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a watchOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is a watchOS application extension should use this
provider to describe that requirement.


**FIELDS**



<a id="#WatchosStaticFrameworkBundleInfo"></a>

## WatchosStaticFrameworkBundleInfo

<pre>
WatchosStaticFrameworkBundleInfo()
</pre>


Denotes that a target is an watchOS static framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a watchOS static framework
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is a watchOS static framework should use this provider to describe
that requirement.


**FIELDS**



<a id="#WatchosXcTestBundleInfo"></a>

## WatchosXcTestBundleInfo

<pre>
WatchosXcTestBundleInfo()
</pre>


Denotes a target that is a watchOS .xctest bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a watchOS .xctest bundle (and
not some other Apple bundle). Rule authors who wish to require that a dependency
is a watchOS .xctest bundle should use this provider to describe that requirement.


**FIELDS**



<a id="#merge_apple_framework_import_info"></a>

## merge_apple_framework_import_info

<pre>
merge_apple_framework_import_info(<a href="#merge_apple_framework_import_info-apple_framework_import_infos">apple_framework_import_infos</a>)
</pre>

    Merges multiple `AppleFrameworkImportInfo` into one.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="merge_apple_framework_import_info-apple_framework_import_infos"></a>apple_framework_import_infos |  List of <code>AppleFrameworkImportInfo</code> to be merged.   |  none |


