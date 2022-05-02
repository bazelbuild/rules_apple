<!-- Generated with Stardoc: http://skydoc.bazel.build -->

# Bazel rules for creating watchOS applications and bundles.

<a id="watchos_application"></a>

## watchos_application

<pre>
watchos_application(<a href="#watchos_application-name">name</a>, <a href="#watchos_application-app_icons">app_icons</a>, <a href="#watchos_application-bundle_id">bundle_id</a>, <a href="#watchos_application-bundle_name">bundle_name</a>, <a href="#watchos_application-deps">deps</a>, <a href="#watchos_application-entitlements">entitlements</a>,
                    <a href="#watchos_application-entitlements_validation">entitlements_validation</a>, <a href="#watchos_application-executable_name">executable_name</a>, <a href="#watchos_application-extension">extension</a>, <a href="#watchos_application-infoplists">infoplists</a>,
                    <a href="#watchos_application-ipa_post_processor">ipa_post_processor</a>, <a href="#watchos_application-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#watchos_application-minimum_os_version">minimum_os_version</a>,
                    <a href="#watchos_application-platform_type">platform_type</a>, <a href="#watchos_application-provisioning_profile">provisioning_profile</a>, <a href="#watchos_application-resources">resources</a>, <a href="#watchos_application-storyboards">storyboards</a>, <a href="#watchos_application-strings">strings</a>, <a href="#watchos_application-version">version</a>)
</pre>

Builds and bundles an watchOS Application.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="watchos_application-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="watchos_application-app_icons"></a>app_icons |  Files that comprise the app icons for the application. Each file must have a containing directory named <code>*..xcassets/*..appiconset</code> and there may be only one such <code>..appiconset</code> directory in the list.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_application-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target.   | String | required |  |
| <a id="watchos_application-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="watchos_application-deps"></a>deps |  A list of targets whose resources will be included in the final application. Since a watchOS application does not contain any code of its own, any code in the dependent libraries will be ignored.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_application-entitlements"></a>entitlements |  The entitlements file required for device builds of this target. If absent, the default entitlements from the provisioning profile will be used.<br><br>The following variables are substituted in the entitlements file: <code>$(CFBundleIdentifier)</code> with the bundle ID of the application and <code>$(AppIdentifierPrefix)</code> with the value of the <code>ApplicationIdentifierPrefix</code> key from the target's provisioning profile.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="watchos_application-entitlements_validation"></a>entitlements_validation |  An [<code>entitlements_validation_mode</code>](/doc/types.md#entitlements-validation-mode) to control the validation of the requested entitlements against the provisioning profile to ensure they are supported.   | String | optional | "loose" |
| <a id="watchos_application-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="watchos_application-extension"></a>extension |  The <code>watchos_extension</code> that is bundled with the watch application.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="watchos_application-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="watchos_application-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="watchos_application-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="watchos_application-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="watchos_application-platform_type"></a>platform_type |  -   | String | optional | "watchos" |
| <a id="watchos_application-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.mobileprovision</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="watchos_application-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_application-storyboards"></a>storyboards |  A list of <code>.storyboard</code> files, often localizable. These files are compiled and placed in the root of the final application bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_application-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_application-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-versioning.md#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="watchos_build_test"></a>

## watchos_build_test

<pre>
watchos_build_test(<a href="#watchos_build_test-name">name</a>, <a href="#watchos_build_test-minimum_os_version">minimum_os_version</a>, <a href="#watchos_build_test-platform_type">platform_type</a>, <a href="#watchos_build_test-targets">targets</a>)
</pre>

Test rule to check that the given library targets (Swift, Objective-C, C++)
build for watchOS.

Typical usage:

```starlark
watchos_build_test(
    name = "my_build_test",
    minimum_os_version = "6.0",
    targets = [
        "//some/package:my_library",
    ],
)
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="watchos_build_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="watchos_build_test-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version that will be used as the deployment target when building the targets, represented as a dotted version number (for example, <code>"9.0"</code>).   | String | optional | "" |
| <a id="watchos_build_test-platform_type"></a>platform_type |  -   | String | optional | "watchos" |
| <a id="watchos_build_test-targets"></a>targets |  The targets to check for successful build.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |


<a id="watchos_dynamic_framework"></a>

## watchos_dynamic_framework

<pre>
watchos_dynamic_framework(<a href="#watchos_dynamic_framework-name">name</a>, <a href="#watchos_dynamic_framework-additional_linker_inputs">additional_linker_inputs</a>, <a href="#watchos_dynamic_framework-bundle_id">bundle_id</a>, <a href="#watchos_dynamic_framework-bundle_name">bundle_name</a>, <a href="#watchos_dynamic_framework-codesign_inputs">codesign_inputs</a>,
                          <a href="#watchos_dynamic_framework-codesignopts">codesignopts</a>, <a href="#watchos_dynamic_framework-deps">deps</a>, <a href="#watchos_dynamic_framework-executable_name">executable_name</a>, <a href="#watchos_dynamic_framework-exported_symbols_lists">exported_symbols_lists</a>, <a href="#watchos_dynamic_framework-extension_safe">extension_safe</a>,
                          <a href="#watchos_dynamic_framework-frameworks">frameworks</a>, <a href="#watchos_dynamic_framework-infoplists">infoplists</a>, <a href="#watchos_dynamic_framework-ipa_post_processor">ipa_post_processor</a>, <a href="#watchos_dynamic_framework-linkopts">linkopts</a>,
                          <a href="#watchos_dynamic_framework-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#watchos_dynamic_framework-minimum_os_version">minimum_os_version</a>, <a href="#watchos_dynamic_framework-platform_type">platform_type</a>,
                          <a href="#watchos_dynamic_framework-provisioning_profile">provisioning_profile</a>, <a href="#watchos_dynamic_framework-resources">resources</a>, <a href="#watchos_dynamic_framework-stamp">stamp</a>, <a href="#watchos_dynamic_framework-strings">strings</a>, <a href="#watchos_dynamic_framework-version">version</a>)
</pre>

Builds and bundles a watchOS dynamic framework that is consumable by Xcode.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="watchos_dynamic_framework-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="watchos_dynamic_framework-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_dynamic_framework-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target.   | String | required |  |
| <a id="watchos_dynamic_framework-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="watchos_dynamic_framework-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_dynamic_framework-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="watchos_dynamic_framework-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_dynamic_framework-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="watchos_dynamic_framework-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_dynamic_framework-extension_safe"></a>extension_safe |  If true, compiles and links this framework with <code>-application-extension</code>, restricting the binary to use only extension-safe APIs.   | Boolean | optional | False |
| <a id="watchos_dynamic_framework-frameworks"></a>frameworks |  A list of framework targets (see [<code>ios_framework</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-ios.md#ios_framework)) that this target depends on.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_dynamic_framework-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="watchos_dynamic_framework-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="watchos_dynamic_framework-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="watchos_dynamic_framework-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="watchos_dynamic_framework-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="watchos_dynamic_framework-platform_type"></a>platform_type |  -   | String | optional | "watchos" |
| <a id="watchos_dynamic_framework-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.mobileprovision</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="watchos_dynamic_framework-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_dynamic_framework-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="watchos_dynamic_framework-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_dynamic_framework-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-versioning.md#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="watchos_extension"></a>

## watchos_extension

<pre>
watchos_extension(<a href="#watchos_extension-name">name</a>, <a href="#watchos_extension-additional_linker_inputs">additional_linker_inputs</a>, <a href="#watchos_extension-bundle_id">bundle_id</a>, <a href="#watchos_extension-bundle_name">bundle_name</a>, <a href="#watchos_extension-codesign_inputs">codesign_inputs</a>,
                  <a href="#watchos_extension-codesignopts">codesignopts</a>, <a href="#watchos_extension-deps">deps</a>, <a href="#watchos_extension-entitlements">entitlements</a>, <a href="#watchos_extension-entitlements_validation">entitlements_validation</a>, <a href="#watchos_extension-executable_name">executable_name</a>,
                  <a href="#watchos_extension-exported_symbols_lists">exported_symbols_lists</a>, <a href="#watchos_extension-extensions">extensions</a>, <a href="#watchos_extension-infoplists">infoplists</a>, <a href="#watchos_extension-ipa_post_processor">ipa_post_processor</a>, <a href="#watchos_extension-linkopts">linkopts</a>,
                  <a href="#watchos_extension-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#watchos_extension-minimum_os_version">minimum_os_version</a>, <a href="#watchos_extension-platform_type">platform_type</a>,
                  <a href="#watchos_extension-provisioning_profile">provisioning_profile</a>, <a href="#watchos_extension-resources">resources</a>, <a href="#watchos_extension-stamp">stamp</a>, <a href="#watchos_extension-strings">strings</a>, <a href="#watchos_extension-version">version</a>)
</pre>

Builds and bundles an watchOS Extension.

**This rule only supports watchOS 2.0 and higher.**
Apple no longer supports or accepts submissions of apps written for watchOS 1.x,
so these bundling rules do not support that version of the platform.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="watchos_extension-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="watchos_extension-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_extension-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target.   | String | required |  |
| <a id="watchos_extension-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="watchos_extension-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_extension-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="watchos_extension-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_extension-entitlements"></a>entitlements |  The entitlements file required for device builds of this target. If absent, the default entitlements from the provisioning profile will be used.<br><br>The following variables are substituted in the entitlements file: <code>$(CFBundleIdentifier)</code> with the bundle ID of the application and <code>$(AppIdentifierPrefix)</code> with the value of the <code>ApplicationIdentifierPrefix</code> key from the target's provisioning profile.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="watchos_extension-entitlements_validation"></a>entitlements_validation |  An [<code>entitlements_validation_mode</code>](/doc/types.md#entitlements-validation-mode) to control the validation of the requested entitlements against the provisioning profile to ensure they are supported.   | String | optional | "loose" |
| <a id="watchos_extension-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="watchos_extension-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_extension-extensions"></a>extensions |  A list of watchOS application extensions to include in the final watch extension bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_extension-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="watchos_extension-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="watchos_extension-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="watchos_extension-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="watchos_extension-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="watchos_extension-platform_type"></a>platform_type |  -   | String | optional | "watchos" |
| <a id="watchos_extension-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.mobileprovision</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="watchos_extension-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_extension-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="watchos_extension-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_extension-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-versioning.md#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="watchos_static_framework"></a>

## watchos_static_framework

<pre>
watchos_static_framework(<a href="#watchos_static_framework-name">name</a>, <a href="#watchos_static_framework-additional_linker_inputs">additional_linker_inputs</a>, <a href="#watchos_static_framework-avoid_deps">avoid_deps</a>, <a href="#watchos_static_framework-bundle_name">bundle_name</a>, <a href="#watchos_static_framework-codesign_inputs">codesign_inputs</a>,
                         <a href="#watchos_static_framework-codesignopts">codesignopts</a>, <a href="#watchos_static_framework-deps">deps</a>, <a href="#watchos_static_framework-exclude_resources">exclude_resources</a>, <a href="#watchos_static_framework-executable_name">executable_name</a>,
                         <a href="#watchos_static_framework-exported_symbols_lists">exported_symbols_lists</a>, <a href="#watchos_static_framework-hdrs">hdrs</a>, <a href="#watchos_static_framework-ipa_post_processor">ipa_post_processor</a>, <a href="#watchos_static_framework-linkopts">linkopts</a>,
                         <a href="#watchos_static_framework-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#watchos_static_framework-minimum_os_version">minimum_os_version</a>, <a href="#watchos_static_framework-platform_type">platform_type</a>, <a href="#watchos_static_framework-resources">resources</a>,
                         <a href="#watchos_static_framework-stamp">stamp</a>, <a href="#watchos_static_framework-strings">strings</a>, <a href="#watchos_static_framework-umbrella_header">umbrella_header</a>, <a href="#watchos_static_framework-version">version</a>)
</pre>

Builds and bundles a watchOS Static Framework.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="watchos_static_framework-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="watchos_static_framework-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_static_framework-avoid_deps"></a>avoid_deps |  A list of library targets on which this framework depends in order to compile, but the transitive closure of which will not be linked into the framework's binary.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_static_framework-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="watchos_static_framework-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_static_framework-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="watchos_static_framework-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_static_framework-exclude_resources"></a>exclude_resources |  Indicates whether resources should be excluded from the bundle. This can be used to avoid unnecessarily bundling resources if the static framework is being distributed in a different fashion, such as a Cocoapod.   | Boolean | optional | False |
| <a id="watchos_static_framework-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="watchos_static_framework-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_static_framework-hdrs"></a>hdrs |  A list of <code>.h</code> files that will be publicly exposed by this framework. These headers should have framework-relative imports, and if non-empty, an umbrella header named <code>%{bundle_name}.h</code> will also be generated that imports all of the headers listed here.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_static_framework-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="watchos_static_framework-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="watchos_static_framework-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="watchos_static_framework-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="watchos_static_framework-platform_type"></a>platform_type |  -   | String | optional | "watchos" |
| <a id="watchos_static_framework-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_static_framework-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="watchos_static_framework-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_static_framework-umbrella_header"></a>umbrella_header |  An optional single .h file to use as the umbrella header for this framework. Usually, this header will have the same name as this target, so that clients can load the header using the #import &lt;MyFramework/MyFramework.h&gt; format. If this attribute is not specified (the common use case), an umbrella header will be generated under the same name as this target.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="watchos_static_framework-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-versioning.md#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="watchos_ui_test"></a>

## watchos_ui_test

<pre>
watchos_ui_test(<a href="#watchos_ui_test-name">name</a>, <a href="#watchos_ui_test-data">data</a>, <a href="#watchos_ui_test-deps">deps</a>, <a href="#watchos_ui_test-env">env</a>, <a href="#watchos_ui_test-platform_type">platform_type</a>, <a href="#watchos_ui_test-runner">runner</a>, <a href="#watchos_ui_test-test_host">test_host</a>)
</pre>

watchOS UI Test rule.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="watchos_ui_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="watchos_ui_test-data"></a>data |  Files to be made available to the test during its execution.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_ui_test-deps"></a>deps |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="watchos_ui_test-env"></a>env |  Dictionary of environment variables that should be set during the test execution.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="watchos_ui_test-platform_type"></a>platform_type |  -   | String | optional | "watchos" |
| <a id="watchos_ui_test-runner"></a>runner |  The runner target that will provide the logic on how to run the tests. Needs to provide the AppleTestRunnerInfo provider.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="watchos_ui_test-test_host"></a>test_host |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="watchos_unit_test"></a>

## watchos_unit_test

<pre>
watchos_unit_test(<a href="#watchos_unit_test-name">name</a>, <a href="#watchos_unit_test-data">data</a>, <a href="#watchos_unit_test-deps">deps</a>, <a href="#watchos_unit_test-env">env</a>, <a href="#watchos_unit_test-platform_type">platform_type</a>, <a href="#watchos_unit_test-runner">runner</a>, <a href="#watchos_unit_test-test_host">test_host</a>)
</pre>

watchOS Unit Test rule.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="watchos_unit_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="watchos_unit_test-data"></a>data |  Files to be made available to the test during its execution.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="watchos_unit_test-deps"></a>deps |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="watchos_unit_test-env"></a>env |  Dictionary of environment variables that should be set during the test execution.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="watchos_unit_test-platform_type"></a>platform_type |  -   | String | optional | "watchos" |
| <a id="watchos_unit_test-runner"></a>runner |  The runner target that will provide the logic on how to run the tests. Needs to provide the AppleTestRunnerInfo provider.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="watchos_unit_test-test_host"></a>test_host |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


