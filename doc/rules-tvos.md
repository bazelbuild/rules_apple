<!-- Generated with Stardoc, Do Not Edit! -->

# Bazel rules for creating tvOS applications and bundles.
<a id="#tvos_application"></a>

## tvos_application

<pre>
tvos_application(<a href="#tvos_application-name">name</a>, <a href="#tvos_application-additional_linker_inputs">additional_linker_inputs</a>, <a href="#tvos_application-app_icons">app_icons</a>, <a href="#tvos_application-bundle_id">bundle_id</a>, <a href="#tvos_application-bundle_name">bundle_name</a>, <a href="#tvos_application-codesign_inputs">codesign_inputs</a>,
                 <a href="#tvos_application-codesignopts">codesignopts</a>, <a href="#tvos_application-deps">deps</a>, <a href="#tvos_application-entitlements">entitlements</a>, <a href="#tvos_application-entitlements_validation">entitlements_validation</a>, <a href="#tvos_application-executable_name">executable_name</a>,
                 <a href="#tvos_application-exported_symbols_lists">exported_symbols_lists</a>, <a href="#tvos_application-extensions">extensions</a>, <a href="#tvos_application-frameworks">frameworks</a>, <a href="#tvos_application-infoplists">infoplists</a>, <a href="#tvos_application-ipa_post_processor">ipa_post_processor</a>,
                 <a href="#tvos_application-launch_images">launch_images</a>, <a href="#tvos_application-linkopts">linkopts</a>, <a href="#tvos_application-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#tvos_application-minimum_os_version">minimum_os_version</a>,
                 <a href="#tvos_application-platform_type">platform_type</a>, <a href="#tvos_application-provisioning_profile">provisioning_profile</a>, <a href="#tvos_application-resources">resources</a>, <a href="#tvos_application-settings_bundle">settings_bundle</a>, <a href="#tvos_application-stamp">stamp</a>, <a href="#tvos_application-strings">strings</a>,
                 <a href="#tvos_application-version">version</a>)
</pre>

Builds and bundles a tvOS Application.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="tvos_application-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="tvos_application-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_application-app_icons"></a>app_icons |  Files that comprise the app icons for the application. Each file must have a containing directory named <code>*..xcassets/*..appiconset</code> and there may be only one such <code>..appiconset</code> directory in the list.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_application-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target.   | String | required |  |
| <a id="tvos_application-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="tvos_application-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_application-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="tvos_application-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_application-entitlements"></a>entitlements |  The entitlements file required for device builds of this target. If absent, the default entitlements from the provisioning profile will be used.<br><br>The following variables are substituted in the entitlements file: <code>$(CFBundleIdentifier)</code> with the bundle ID of the application and <code>$(AppIdentifierPrefix)</code> with the value of the <code>ApplicationIdentifierPrefix</code> key from the target's provisioning profile.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="tvos_application-entitlements_validation"></a>entitlements_validation |  An [<code>entitlements_validation_mode</code>](/doc/types.md#entitlements-validation-mode) to control the validation of the requested entitlements against the provisioning profile to ensure they are supported.   | String | optional | "loose" |
| <a id="tvos_application-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="tvos_application-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_application-extensions"></a>extensions |  A list of tvOS extensions to include in the final application bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_application-frameworks"></a>frameworks |  A list of framework targets (see [<code>tvos_framework</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-tvos.md#tvos_framework)) that this target depends on.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_application-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="tvos_application-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="tvos_application-launch_images"></a>launch_images |  Files that comprise the launch images for the application. Each file must have a containing directory named <code>*.xcassets/*.launchimage</code> and there may be only one such <code>.launchimage</code> directory in the list.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_application-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="tvos_application-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="tvos_application-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="tvos_application-platform_type"></a>platform_type |  -   | String | optional | "tvos" |
| <a id="tvos_application-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.mobileprovision</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="tvos_application-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_application-settings_bundle"></a>settings_bundle |  A resource bundle (e.g. <code>apple_bundle_import</code>) target that contains the files that make up the application's settings bundle. These files will be copied into the root of the final application bundle in a directory named <code>Settings.bundle</code>.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="tvos_application-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="tvos_application-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_application-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="#tvos_build_test"></a>

## tvos_build_test

<pre>
tvos_build_test(<a href="#tvos_build_test-name">name</a>, <a href="#tvos_build_test-minimum_os_version">minimum_os_version</a>, <a href="#tvos_build_test-platform_type">platform_type</a>, <a href="#tvos_build_test-targets">targets</a>)
</pre>

Test rule to check that the given library targets (Swift, Objective-C, C++)
build for tvOS.

Typical usage:

```starlark
tvos_build_test(
    name = "my_build_test",
    minimum_os_version = "12.0",
    targets = [
        "//some/package:my_library",
    ],
)
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="tvos_build_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="tvos_build_test-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version that will be used as the deployment target when building the targets, represented as a dotted version number (for example, <code>"9.0"</code>).   | String | optional | "" |
| <a id="tvos_build_test-platform_type"></a>platform_type |  -   | String | optional | "tvos" |
| <a id="tvos_build_test-targets"></a>targets |  The targets to check for successful build.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |


<a id="#tvos_dynamic_framework"></a>

## tvos_dynamic_framework

<pre>
tvos_dynamic_framework(<a href="#tvos_dynamic_framework-name">name</a>, <a href="#tvos_dynamic_framework-additional_linker_inputs">additional_linker_inputs</a>, <a href="#tvos_dynamic_framework-bundle_id">bundle_id</a>, <a href="#tvos_dynamic_framework-bundle_name">bundle_name</a>, <a href="#tvos_dynamic_framework-codesign_inputs">codesign_inputs</a>,
                       <a href="#tvos_dynamic_framework-codesignopts">codesignopts</a>, <a href="#tvos_dynamic_framework-deps">deps</a>, <a href="#tvos_dynamic_framework-executable_name">executable_name</a>, <a href="#tvos_dynamic_framework-exported_symbols_lists">exported_symbols_lists</a>, <a href="#tvos_dynamic_framework-extension_safe">extension_safe</a>,
                       <a href="#tvos_dynamic_framework-frameworks">frameworks</a>, <a href="#tvos_dynamic_framework-hdrs">hdrs</a>, <a href="#tvos_dynamic_framework-infoplists">infoplists</a>, <a href="#tvos_dynamic_framework-ipa_post_processor">ipa_post_processor</a>, <a href="#tvos_dynamic_framework-linkopts">linkopts</a>,
                       <a href="#tvos_dynamic_framework-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#tvos_dynamic_framework-minimum_os_version">minimum_os_version</a>, <a href="#tvos_dynamic_framework-platform_type">platform_type</a>,
                       <a href="#tvos_dynamic_framework-provisioning_profile">provisioning_profile</a>, <a href="#tvos_dynamic_framework-resources">resources</a>, <a href="#tvos_dynamic_framework-stamp">stamp</a>, <a href="#tvos_dynamic_framework-strings">strings</a>, <a href="#tvos_dynamic_framework-version">version</a>)
</pre>

Builds and bundles a tvOS dynamic framework that is consumable by Xcode.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="tvos_dynamic_framework-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="tvos_dynamic_framework-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_dynamic_framework-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target.   | String | required |  |
| <a id="tvos_dynamic_framework-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="tvos_dynamic_framework-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_dynamic_framework-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="tvos_dynamic_framework-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_dynamic_framework-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="tvos_dynamic_framework-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_dynamic_framework-extension_safe"></a>extension_safe |  If true, compiles and links this framework with <code>-application-extension</code>, restricting the binary to use only extension-safe APIs.   | Boolean | optional | False |
| <a id="tvos_dynamic_framework-frameworks"></a>frameworks |  A list of framework targets (see [<code>tvos_framework</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-tvos.md#tvos_framework)) that this target depends on.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_dynamic_framework-hdrs"></a>hdrs |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_dynamic_framework-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="tvos_dynamic_framework-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="tvos_dynamic_framework-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="tvos_dynamic_framework-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="tvos_dynamic_framework-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="tvos_dynamic_framework-platform_type"></a>platform_type |  -   | String | optional | "tvos" |
| <a id="tvos_dynamic_framework-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.mobileprovision</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="tvos_dynamic_framework-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_dynamic_framework-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="tvos_dynamic_framework-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_dynamic_framework-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="#tvos_extension"></a>

## tvos_extension

<pre>
tvos_extension(<a href="#tvos_extension-name">name</a>, <a href="#tvos_extension-additional_linker_inputs">additional_linker_inputs</a>, <a href="#tvos_extension-bundle_id">bundle_id</a>, <a href="#tvos_extension-bundle_name">bundle_name</a>, <a href="#tvos_extension-codesign_inputs">codesign_inputs</a>,
               <a href="#tvos_extension-codesignopts">codesignopts</a>, <a href="#tvos_extension-deps">deps</a>, <a href="#tvos_extension-entitlements">entitlements</a>, <a href="#tvos_extension-entitlements_validation">entitlements_validation</a>, <a href="#tvos_extension-executable_name">executable_name</a>,
               <a href="#tvos_extension-exported_symbols_lists">exported_symbols_lists</a>, <a href="#tvos_extension-frameworks">frameworks</a>, <a href="#tvos_extension-infoplists">infoplists</a>, <a href="#tvos_extension-ipa_post_processor">ipa_post_processor</a>, <a href="#tvos_extension-linkopts">linkopts</a>,
               <a href="#tvos_extension-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#tvos_extension-minimum_os_version">minimum_os_version</a>, <a href="#tvos_extension-platform_type">platform_type</a>, <a href="#tvos_extension-provisioning_profile">provisioning_profile</a>,
               <a href="#tvos_extension-resources">resources</a>, <a href="#tvos_extension-stamp">stamp</a>, <a href="#tvos_extension-strings">strings</a>, <a href="#tvos_extension-version">version</a>)
</pre>

Builds and bundles a tvOS Extension.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="tvos_extension-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="tvos_extension-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_extension-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target.   | String | required |  |
| <a id="tvos_extension-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="tvos_extension-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_extension-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="tvos_extension-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_extension-entitlements"></a>entitlements |  The entitlements file required for device builds of this target. If absent, the default entitlements from the provisioning profile will be used.<br><br>The following variables are substituted in the entitlements file: <code>$(CFBundleIdentifier)</code> with the bundle ID of the application and <code>$(AppIdentifierPrefix)</code> with the value of the <code>ApplicationIdentifierPrefix</code> key from the target's provisioning profile.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="tvos_extension-entitlements_validation"></a>entitlements_validation |  An [<code>entitlements_validation_mode</code>](/doc/types.md#entitlements-validation-mode) to control the validation of the requested entitlements against the provisioning profile to ensure they are supported.   | String | optional | "loose" |
| <a id="tvos_extension-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="tvos_extension-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_extension-frameworks"></a>frameworks |  A list of framework targets (see [<code>tvos_framework</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-tvos.md#tvos_framework)) that this target depends on.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_extension-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="tvos_extension-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="tvos_extension-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="tvos_extension-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="tvos_extension-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="tvos_extension-platform_type"></a>platform_type |  -   | String | optional | "tvos" |
| <a id="tvos_extension-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.mobileprovision</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="tvos_extension-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_extension-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="tvos_extension-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_extension-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="#tvos_framework"></a>

## tvos_framework

<pre>
tvos_framework(<a href="#tvos_framework-name">name</a>, <a href="#tvos_framework-additional_linker_inputs">additional_linker_inputs</a>, <a href="#tvos_framework-bundle_id">bundle_id</a>, <a href="#tvos_framework-bundle_name">bundle_name</a>, <a href="#tvos_framework-codesign_inputs">codesign_inputs</a>,
               <a href="#tvos_framework-codesignopts">codesignopts</a>, <a href="#tvos_framework-deps">deps</a>, <a href="#tvos_framework-executable_name">executable_name</a>, <a href="#tvos_framework-exported_symbols_lists">exported_symbols_lists</a>, <a href="#tvos_framework-extension_safe">extension_safe</a>,
               <a href="#tvos_framework-frameworks">frameworks</a>, <a href="#tvos_framework-hdrs">hdrs</a>, <a href="#tvos_framework-infoplists">infoplists</a>, <a href="#tvos_framework-ipa_post_processor">ipa_post_processor</a>, <a href="#tvos_framework-linkopts">linkopts</a>,
               <a href="#tvos_framework-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#tvos_framework-minimum_os_version">minimum_os_version</a>, <a href="#tvos_framework-platform_type">platform_type</a>, <a href="#tvos_framework-provisioning_profile">provisioning_profile</a>,
               <a href="#tvos_framework-resources">resources</a>, <a href="#tvos_framework-stamp">stamp</a>, <a href="#tvos_framework-strings">strings</a>, <a href="#tvos_framework-version">version</a>)
</pre>


Builds and bundles a tvOS Dynamic Framework.

To use this framework for your app and extensions, list it in the frameworks attributes of those tvos_application and/or tvos_extension rules.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="tvos_framework-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="tvos_framework-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_framework-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target.   | String | required |  |
| <a id="tvos_framework-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="tvos_framework-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_framework-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="tvos_framework-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_framework-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="tvos_framework-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_framework-extension_safe"></a>extension_safe |  If true, compiles and links this framework with <code>-application-extension</code>, restricting the binary to use only extension-safe APIs.   | Boolean | optional | False |
| <a id="tvos_framework-frameworks"></a>frameworks |  A list of framework targets (see [<code>tvos_framework</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-tvos.md#tvos_framework)) that this target depends on.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_framework-hdrs"></a>hdrs |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_framework-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="tvos_framework-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="tvos_framework-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="tvos_framework-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="tvos_framework-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="tvos_framework-platform_type"></a>platform_type |  -   | String | optional | "tvos" |
| <a id="tvos_framework-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.mobileprovision</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="tvos_framework-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_framework-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="tvos_framework-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_framework-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="#tvos_static_framework"></a>

## tvos_static_framework

<pre>
tvos_static_framework(<a href="#tvos_static_framework-name">name</a>, <a href="#tvos_static_framework-additional_linker_inputs">additional_linker_inputs</a>, <a href="#tvos_static_framework-avoid_deps">avoid_deps</a>, <a href="#tvos_static_framework-bundle_name">bundle_name</a>, <a href="#tvos_static_framework-codesign_inputs">codesign_inputs</a>,
                      <a href="#tvos_static_framework-codesignopts">codesignopts</a>, <a href="#tvos_static_framework-deps">deps</a>, <a href="#tvos_static_framework-exclude_resources">exclude_resources</a>, <a href="#tvos_static_framework-executable_name">executable_name</a>, <a href="#tvos_static_framework-exported_symbols_lists">exported_symbols_lists</a>,
                      <a href="#tvos_static_framework-frameworks">frameworks</a>, <a href="#tvos_static_framework-hdrs">hdrs</a>, <a href="#tvos_static_framework-ipa_post_processor">ipa_post_processor</a>, <a href="#tvos_static_framework-linkopts">linkopts</a>, <a href="#tvos_static_framework-minimum_deployment_os_version">minimum_deployment_os_version</a>,
                      <a href="#tvos_static_framework-minimum_os_version">minimum_os_version</a>, <a href="#tvos_static_framework-platform_type">platform_type</a>, <a href="#tvos_static_framework-resources">resources</a>, <a href="#tvos_static_framework-stamp">stamp</a>, <a href="#tvos_static_framework-strings">strings</a>, <a href="#tvos_static_framework-umbrella_header">umbrella_header</a>,
                      <a href="#tvos_static_framework-version">version</a>)
</pre>


Builds and bundles an tvOS static framework for third-party distribution.

A static framework is bundled like a dynamic framework except that the embedded
binary is a static library rather than a dynamic library. It is intended to
create distributable static SDKs or artifacts that can be easily imported into
other Xcode projects; it is specifically **not** intended to be used as a
dependency of other Bazel targets. For that use case, use the corresponding
`objc_library` targets directly.

Unlike other tvOS bundles, the fat binary in an `tvos_static_framework` may
simultaneously contain simulator and device architectures (that is, you can
build a single framework artifact that works for all architectures by specifying
`--tvos_cpus=x86_64,arm64` when you build).

`tvos_static_framework` supports Swift, but there are some constraints:

* `tvos_static_framework` with Swift only works with Xcode 11 and above, since
  the required Swift functionality for module compatibility is available in
  Swift 5.1.
* `tvos_static_framework` only supports a single direct `swift_library` target
  that does not depend transitively on any other `swift_library` targets. The
  Swift compiler expects a framework to contain a single Swift module, and each
  `swift_library` target is its own module by definition.
* `tvos_static_framework` does not support mixed Objective-C and Swift public
  interfaces. This means that the `umbrella_header` and `hdrs` attributes are
  unavailable when using `swift_library` dependencies. You are allowed to depend
  on `objc_library` from the main `swift_library` dependency, but note that only
  the `swift_library`'s public interface will be available to users of the
  static framework.

When using Swift, the `tvos_static_framework` bundles `swiftinterface` and
`swiftdocs` file for each of the required architectures. It also bundles an
umbrella header which is the header generated by the single `swift_library`
target. Finally, it also bundles a `module.modulemap` file pointing to the
umbrella header for Objetive-C module compatibility. This umbrella header and
modulemap can be skipped by disabling the `swift.no_generated_header` feature (
i.e. `--features=-swift.no_generated_header`).


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="tvos_static_framework-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="tvos_static_framework-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_static_framework-avoid_deps"></a>avoid_deps |  A list of library targets on which this framework depends in order to compile, but the transitive closure of which will not be linked into the framework's binary.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_static_framework-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="tvos_static_framework-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_static_framework-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="tvos_static_framework-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_static_framework-exclude_resources"></a>exclude_resources |  Indicates whether resources should be excluded from the bundle. This can be used to avoid unnecessarily bundling resources if the static framework is being distributed in a different fashion, such as a Cocoapod.   | Boolean | optional | False |
| <a id="tvos_static_framework-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="tvos_static_framework-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_static_framework-frameworks"></a>frameworks |  A list of framework targets (see [<code>tvos_framework</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-tvos.md#tvos_framework)) that this target depends on.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_static_framework-hdrs"></a>hdrs |  A list of <code>.h</code> files that will be publicly exposed by this framework. These headers should have framework-relative imports, and if non-empty, an umbrella header named <code>%{bundle_name}.h</code> will also be generated that imports all of the headers listed here.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_static_framework-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="tvos_static_framework-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="tvos_static_framework-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="tvos_static_framework-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="tvos_static_framework-platform_type"></a>platform_type |  -   | String | optional | "tvos" |
| <a id="tvos_static_framework-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_static_framework-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="tvos_static_framework-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_static_framework-umbrella_header"></a>umbrella_header |  An optional single .h file to use as the umbrella header for this framework. Usually, this header will have the same name as this target, so that clients can load the header using the #import &lt;MyFramework/MyFramework.h&gt; format. If this attribute is not specified (the common use case), an umbrella header will be generated under the same name as this target.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="tvos_static_framework-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="#tvos_ui_test"></a>

## tvos_ui_test

<pre>
tvos_ui_test(<a href="#tvos_ui_test-name">name</a>, <a href="#tvos_ui_test-data">data</a>, <a href="#tvos_ui_test-deps">deps</a>, <a href="#tvos_ui_test-env">env</a>, <a href="#tvos_ui_test-platform_type">platform_type</a>, <a href="#tvos_ui_test-runner">runner</a>, <a href="#tvos_ui_test-test_host">test_host</a>)
</pre>


Builds and bundles a tvOS UI `.xctest` test bundle. Runs the tests using the
provided test runner when invoked with `bazel test`. When using Tulsi to run
tests built with this target, `runner` will not be used since Xcode is the test
runner in that case.

Note: tvOS UI tests are not currently supported in the default test runner.

The following is a list of the `tvos_ui_test` specific attributes; for a list of
the attributes inherited by all test rules, please check the
[Bazel documentation](https://bazel.build/reference/be/common-definitions#common-attributes-tests).


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="tvos_ui_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="tvos_ui_test-data"></a>data |  Files to be made available to the test during its execution.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_ui_test-deps"></a>deps |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="tvos_ui_test-env"></a>env |  Dictionary of environment variables that should be set during the test execution.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="tvos_ui_test-platform_type"></a>platform_type |  -   | String | optional | "tvos" |
| <a id="tvos_ui_test-runner"></a>runner |  The runner target that will provide the logic on how to run the tests. Needs to provide the AppleTestRunnerInfo provider.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="tvos_ui_test-test_host"></a>test_host |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="#tvos_unit_test"></a>

## tvos_unit_test

<pre>
tvos_unit_test(<a href="#tvos_unit_test-name">name</a>, <a href="#tvos_unit_test-data">data</a>, <a href="#tvos_unit_test-deps">deps</a>, <a href="#tvos_unit_test-env">env</a>, <a href="#tvos_unit_test-platform_type">platform_type</a>, <a href="#tvos_unit_test-runner">runner</a>, <a href="#tvos_unit_test-test_host">test_host</a>)
</pre>


Builds and bundles a tvOS Unit `.xctest` test bundle. Runs the tests using the
provided test runner when invoked with `bazel test`. When using Tulsi to run
tests built with this target, `runner` will not be used since Xcode is the test
runner in that case.

Note: tvOS unit tests are not currently supported in the default test runner.

`tvos_unit_test` targets can work in two modes: as app or library tests. If the
`test_host` attribute is set to an `tvos_application` target, the tests will run
within that application's context. If no `test_host` is provided, the tests will
run outside the context of a tvOS application. Because of this, certain
functionalities might not be present (e.g. UI layout, NSUserDefaults). You can
find more information about app and library testing for Apple platforms
[here](https://developer.apple.com/library/content/documentation/DeveloperTools/Conceptual/testing_with_xcode/chapters/03-testing_basics.html).

The following is a list of the `tvos_unit_test` specific attributes; for a list
of the attributes inherited by all test rules, please check the
[Bazel documentation](https://bazel.build/reference/be/common-definitions#common-attributes-tests).


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="tvos_unit_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="tvos_unit_test-data"></a>data |  Files to be made available to the test during its execution.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="tvos_unit_test-deps"></a>deps |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="tvos_unit_test-env"></a>env |  Dictionary of environment variables that should be set during the test execution.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="tvos_unit_test-platform_type"></a>platform_type |  -   | String | optional | "tvos" |
| <a id="tvos_unit_test-runner"></a>runner |  The runner target that will provide the logic on how to run the tests. Needs to provide the AppleTestRunnerInfo provider.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="tvos_unit_test-test_host"></a>test_host |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


