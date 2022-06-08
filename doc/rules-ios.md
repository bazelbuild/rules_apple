<!-- Generated with Stardoc: http://skydoc.bazel.build -->

# Build rules for iOS

<a id="ios_app_clip"></a>

## ios_app_clip

<pre>
ios_app_clip(<a href="#ios_app_clip-name">name</a>, <a href="#ios_app_clip-additional_linker_inputs">additional_linker_inputs</a>, <a href="#ios_app_clip-app_icons">app_icons</a>, <a href="#ios_app_clip-bundle_id">bundle_id</a>, <a href="#ios_app_clip-bundle_name">bundle_name</a>, <a href="#ios_app_clip-codesign_inputs">codesign_inputs</a>,
             <a href="#ios_app_clip-codesignopts">codesignopts</a>, <a href="#ios_app_clip-deps">deps</a>, <a href="#ios_app_clip-entitlements">entitlements</a>, <a href="#ios_app_clip-entitlements_validation">entitlements_validation</a>, <a href="#ios_app_clip-executable_name">executable_name</a>,
             <a href="#ios_app_clip-exported_symbols_lists">exported_symbols_lists</a>, <a href="#ios_app_clip-families">families</a>, <a href="#ios_app_clip-frameworks">frameworks</a>, <a href="#ios_app_clip-infoplists">infoplists</a>, <a href="#ios_app_clip-ipa_post_processor">ipa_post_processor</a>,
             <a href="#ios_app_clip-launch_storyboard">launch_storyboard</a>, <a href="#ios_app_clip-linkopts">linkopts</a>, <a href="#ios_app_clip-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#ios_app_clip-minimum_os_version">minimum_os_version</a>,
             <a href="#ios_app_clip-platform_type">platform_type</a>, <a href="#ios_app_clip-provisioning_profile">provisioning_profile</a>, <a href="#ios_app_clip-resources">resources</a>, <a href="#ios_app_clip-stamp">stamp</a>, <a href="#ios_app_clip-strings">strings</a>, <a href="#ios_app_clip-version">version</a>)
</pre>

Builds and bundles an iOS App Clip.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="ios_app_clip-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="ios_app_clip-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_app_clip-app_icons"></a>app_icons |  Files that comprise the app icons for the application. Each file must have a containing directory named <code>*..xcassets/*..appiconset</code> and there may be only one such <code>..appiconset</code> directory in the list.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_app_clip-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target.   | String | required |  |
| <a id="ios_app_clip-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="ios_app_clip-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_app_clip-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="ios_app_clip-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_app_clip-entitlements"></a>entitlements |  The entitlements file required for device builds of this target. If absent, the default entitlements from the provisioning profile will be used.<br><br>The following variables are substituted in the entitlements file: <code>$(CFBundleIdentifier)</code> with the bundle ID of the application and <code>$(AppIdentifierPrefix)</code> with the value of the <code>ApplicationIdentifierPrefix</code> key from the target's provisioning profile.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_app_clip-entitlements_validation"></a>entitlements_validation |  An [<code>entitlements_validation_mode</code>](/doc/types.md#entitlements-validation-mode) to control the validation of the requested entitlements against the provisioning profile to ensure they are supported.   | String | optional | "loose" |
| <a id="ios_app_clip-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="ios_app_clip-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_app_clip-families"></a>families |  A list of device families supported by this extension. Valid values are <code>iphone</code> and <code>ipad</code>; at least one must be specified.   | List of strings | required |  |
| <a id="ios_app_clip-frameworks"></a>frameworks |  A list of framework targets (see [<code>ios_framework</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-ios.md#ios_framework)) that this target depends on.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_app_clip-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="ios_app_clip-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_app_clip-launch_storyboard"></a>launch_storyboard |  The <code>.storyboard</code> or <code>.xib</code> file that should be used as the launch screen for the app clip. The provided file will be compiled into the appropriate format (<code>.storyboardc</code> or <code>.nib</code>) and placed in the root of the final bundle. The generated file will also be registered in the bundle's Info.plist under the key <code>UILaunchStoryboardName</code>.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_app_clip-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="ios_app_clip-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="ios_app_clip-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="ios_app_clip-platform_type"></a>platform_type |  -   | String | optional | "ios" |
| <a id="ios_app_clip-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.mobileprovision</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_app_clip-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_app_clip-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="ios_app_clip-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_app_clip-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-versioning.md#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="ios_application"></a>

## ios_application

<pre>
ios_application(<a href="#ios_application-name">name</a>, <a href="#ios_application-additional_linker_inputs">additional_linker_inputs</a>, <a href="#ios_application-alternate_icons">alternate_icons</a>, <a href="#ios_application-app_clips">app_clips</a>, <a href="#ios_application-app_icons">app_icons</a>, <a href="#ios_application-bundle_id">bundle_id</a>,
                <a href="#ios_application-bundle_name">bundle_name</a>, <a href="#ios_application-codesign_inputs">codesign_inputs</a>, <a href="#ios_application-codesignopts">codesignopts</a>, <a href="#ios_application-deps">deps</a>, <a href="#ios_application-entitlements">entitlements</a>,
                <a href="#ios_application-entitlements_validation">entitlements_validation</a>, <a href="#ios_application-executable_name">executable_name</a>, <a href="#ios_application-exported_symbols_lists">exported_symbols_lists</a>, <a href="#ios_application-extensions">extensions</a>,
                <a href="#ios_application-families">families</a>, <a href="#ios_application-frameworks">frameworks</a>, <a href="#ios_application-include_symbols_in_bundle">include_symbols_in_bundle</a>, <a href="#ios_application-infoplists">infoplists</a>, <a href="#ios_application-ipa_post_processor">ipa_post_processor</a>,
                <a href="#ios_application-launch_images">launch_images</a>, <a href="#ios_application-launch_storyboard">launch_storyboard</a>, <a href="#ios_application-linkopts">linkopts</a>, <a href="#ios_application-minimum_deployment_os_version">minimum_deployment_os_version</a>,
                <a href="#ios_application-minimum_os_version">minimum_os_version</a>, <a href="#ios_application-platform_type">platform_type</a>, <a href="#ios_application-provisioning_profile">provisioning_profile</a>, <a href="#ios_application-resources">resources</a>, <a href="#ios_application-sdk_frameworks">sdk_frameworks</a>,
                <a href="#ios_application-settings_bundle">settings_bundle</a>, <a href="#ios_application-stamp">stamp</a>, <a href="#ios_application-strings">strings</a>, <a href="#ios_application-version">version</a>, <a href="#ios_application-watch_application">watch_application</a>)
</pre>

Builds and bundles an iOS Application.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="ios_application-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="ios_application-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_application-alternate_icons"></a>alternate_icons |  Files that comprise the alternate app icons for the application. Each file must have a containing directory named after the alternate icon identifier.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_application-app_clips"></a>app_clips |  A list of iOS app clips to include in the final application bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_application-app_icons"></a>app_icons |  Files that comprise the app icons for the application. Each file must have a containing directory named <code>*..xcassets/*..appiconset</code> and there may be only one such <code>..appiconset</code> directory in the list.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_application-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target.   | String | required |  |
| <a id="ios_application-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="ios_application-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_application-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="ios_application-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_application-entitlements"></a>entitlements |  The entitlements file required for device builds of this target. If absent, the default entitlements from the provisioning profile will be used.<br><br>The following variables are substituted in the entitlements file: <code>$(CFBundleIdentifier)</code> with the bundle ID of the application and <code>$(AppIdentifierPrefix)</code> with the value of the <code>ApplicationIdentifierPrefix</code> key from the target's provisioning profile.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_application-entitlements_validation"></a>entitlements_validation |  An [<code>entitlements_validation_mode</code>](/doc/types.md#entitlements-validation-mode) to control the validation of the requested entitlements against the provisioning profile to ensure they are supported.   | String | optional | "loose" |
| <a id="ios_application-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="ios_application-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_application-extensions"></a>extensions |  A list of iOS application extensions to include in the final application bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_application-families"></a>families |  A list of device families supported by this extension. Valid values are <code>iphone</code> and <code>ipad</code>; at least one must be specified.   | List of strings | required |  |
| <a id="ios_application-frameworks"></a>frameworks |  A list of framework targets (see [<code>ios_framework</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-ios.md#ios_framework)) that this target depends on.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_application-include_symbols_in_bundle"></a>include_symbols_in_bundle |  If true and --output_groups=+dsyms is specified, generates <code>$UUID.symbols</code>     files from all <code>{binary: .dSYM, ...}</code> pairs for the application and its     dependencies, then packages them under the <code>Symbols/</code> directory in the     final application bundle.   | Boolean | optional | False |
| <a id="ios_application-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="ios_application-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_application-launch_images"></a>launch_images |  Files that comprise the launch images for the application. Each file must have a containing directory named <code>*.xcassets/*.launchimage</code> and there may be only one such <code>.launchimage</code> directory in the list.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_application-launch_storyboard"></a>launch_storyboard |  The <code>.storyboard</code> or <code>.xib</code> file that should be used as the launch screen for the application. The provided file will be compiled into the appropriate format (<code>.storyboardc</code> or <code>.nib</code>) and placed in the root of the final bundle. The generated file will also be registered in the bundle's Info.plist under the key <code>UILaunchStoryboardName</code>.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_application-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="ios_application-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="ios_application-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="ios_application-platform_type"></a>platform_type |  -   | String | optional | "ios" |
| <a id="ios_application-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.mobileprovision</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_application-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_application-sdk_frameworks"></a>sdk_frameworks |  Names of SDK frameworks to link with (e.g., <code>AddressBook</code>, <code>QuartzCore</code>). <code>UIKit</code> and <code>Foundation</code> are always included, even if this attribute is provided and does not list them.<br><br>This attribute is discouraged; in general, targets should list system framework dependencies in the library targets where that framework is used, not in the top-level bundle.   | List of strings | optional | [] |
| <a id="ios_application-settings_bundle"></a>settings_bundle |  A resource bundle (e.g. <code>apple_bundle_import</code>) target that contains the files that make up the application's settings bundle. These files will be copied into the root of the final application bundle in a directory named <code>Settings.bundle</code>.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_application-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="ios_application-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_application-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-versioning.md#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_application-watch_application"></a>watch_application |  A <code>watchos_application</code> target that represents an Apple Watch application that should be embedded in the application bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="ios_build_test"></a>

## ios_build_test

<pre>
ios_build_test(<a href="#ios_build_test-name">name</a>, <a href="#ios_build_test-minimum_os_version">minimum_os_version</a>, <a href="#ios_build_test-platform_type">platform_type</a>, <a href="#ios_build_test-targets">targets</a>)
</pre>

Test rule to check that the given library targets (Swift, Objective-C, C++)
build for iOS.

Typical usage:

```starlark
ios_build_test(
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
| <a id="ios_build_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="ios_build_test-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version that will be used as the deployment target when building the targets, represented as a dotted version number (for example, <code>"9.0"</code>).   | String | optional | "" |
| <a id="ios_build_test-platform_type"></a>platform_type |  -   | String | optional | "ios" |
| <a id="ios_build_test-targets"></a>targets |  The targets to check for successful build.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |


<a id="ios_dynamic_framework"></a>

## ios_dynamic_framework

<pre>
ios_dynamic_framework(<a href="#ios_dynamic_framework-name">name</a>, <a href="#ios_dynamic_framework-additional_linker_inputs">additional_linker_inputs</a>, <a href="#ios_dynamic_framework-bundle_id">bundle_id</a>, <a href="#ios_dynamic_framework-bundle_name">bundle_name</a>, <a href="#ios_dynamic_framework-bundle_only">bundle_only</a>,
                      <a href="#ios_dynamic_framework-codesign_inputs">codesign_inputs</a>, <a href="#ios_dynamic_framework-codesignopts">codesignopts</a>, <a href="#ios_dynamic_framework-deps">deps</a>, <a href="#ios_dynamic_framework-executable_name">executable_name</a>, <a href="#ios_dynamic_framework-exported_symbols_lists">exported_symbols_lists</a>,
                      <a href="#ios_dynamic_framework-extension_safe">extension_safe</a>, <a href="#ios_dynamic_framework-families">families</a>, <a href="#ios_dynamic_framework-frameworks">frameworks</a>, <a href="#ios_dynamic_framework-hdrs">hdrs</a>, <a href="#ios_dynamic_framework-infoplists">infoplists</a>, <a href="#ios_dynamic_framework-ipa_post_processor">ipa_post_processor</a>,
                      <a href="#ios_dynamic_framework-linkopts">linkopts</a>, <a href="#ios_dynamic_framework-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#ios_dynamic_framework-minimum_os_version">minimum_os_version</a>, <a href="#ios_dynamic_framework-platform_type">platform_type</a>,
                      <a href="#ios_dynamic_framework-provisioning_profile">provisioning_profile</a>, <a href="#ios_dynamic_framework-resources">resources</a>, <a href="#ios_dynamic_framework-stamp">stamp</a>, <a href="#ios_dynamic_framework-strings">strings</a>, <a href="#ios_dynamic_framework-version">version</a>)
</pre>

Builds and bundles an iOS dynamic framework that is consumable by Xcode.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="ios_dynamic_framework-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="ios_dynamic_framework-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_dynamic_framework-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target.   | String | required |  |
| <a id="ios_dynamic_framework-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="ios_dynamic_framework-bundle_only"></a>bundle_only |  Avoid linking the dynamic framework, but still include it in the app. This is useful when you want to manually dlopen the framework at runtime.   | Boolean | optional | False |
| <a id="ios_dynamic_framework-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_dynamic_framework-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="ios_dynamic_framework-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_dynamic_framework-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="ios_dynamic_framework-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_dynamic_framework-extension_safe"></a>extension_safe |  If true, compiles and links this framework with <code>-application-extension</code>, restricting the binary to use only extension-safe APIs.   | Boolean | optional | False |
| <a id="ios_dynamic_framework-families"></a>families |  A list of device families supported by this extension. Valid values are <code>iphone</code> and <code>ipad</code>; at least one must be specified.   | List of strings | required |  |
| <a id="ios_dynamic_framework-frameworks"></a>frameworks |  A list of framework targets (see [<code>ios_framework</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-ios.md#ios_framework)) that this target depends on.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_dynamic_framework-hdrs"></a>hdrs |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_dynamic_framework-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="ios_dynamic_framework-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_dynamic_framework-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="ios_dynamic_framework-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="ios_dynamic_framework-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="ios_dynamic_framework-platform_type"></a>platform_type |  -   | String | optional | "ios" |
| <a id="ios_dynamic_framework-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.mobileprovision</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_dynamic_framework-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_dynamic_framework-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="ios_dynamic_framework-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_dynamic_framework-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-versioning.md#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="ios_extension"></a>

## ios_extension

<pre>
ios_extension(<a href="#ios_extension-name">name</a>, <a href="#ios_extension-additional_linker_inputs">additional_linker_inputs</a>, <a href="#ios_extension-app_icons">app_icons</a>, <a href="#ios_extension-bundle_id">bundle_id</a>, <a href="#ios_extension-bundle_name">bundle_name</a>, <a href="#ios_extension-codesign_inputs">codesign_inputs</a>,
              <a href="#ios_extension-codesignopts">codesignopts</a>, <a href="#ios_extension-deps">deps</a>, <a href="#ios_extension-entitlements">entitlements</a>, <a href="#ios_extension-entitlements_validation">entitlements_validation</a>, <a href="#ios_extension-executable_name">executable_name</a>,
              <a href="#ios_extension-exported_symbols_lists">exported_symbols_lists</a>, <a href="#ios_extension-families">families</a>, <a href="#ios_extension-frameworks">frameworks</a>, <a href="#ios_extension-infoplists">infoplists</a>, <a href="#ios_extension-ipa_post_processor">ipa_post_processor</a>, <a href="#ios_extension-linkopts">linkopts</a>,
              <a href="#ios_extension-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#ios_extension-minimum_os_version">minimum_os_version</a>, <a href="#ios_extension-platform_type">platform_type</a>, <a href="#ios_extension-provisioning_profile">provisioning_profile</a>,
              <a href="#ios_extension-resources">resources</a>, <a href="#ios_extension-sdk_frameworks">sdk_frameworks</a>, <a href="#ios_extension-stamp">stamp</a>, <a href="#ios_extension-strings">strings</a>, <a href="#ios_extension-version">version</a>)
</pre>

Builds and bundles an iOS Application Extension.

Most iOS app extensions use a plug-in-based architecture where the executable's entry point
is provided by a system framework.
However, iOS 14 introduced Widget Extensions that use a traditional `main` entry point
(typically expressed through Swift's `@main` attribute).

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="ios_extension-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="ios_extension-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_extension-app_icons"></a>app_icons |  Files that comprise the app icons for the application. Each file must have a containing directory named <code>*..xcassets/*..appiconset</code> and there may be only one such <code>..appiconset</code> directory in the list.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_extension-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target.   | String | required |  |
| <a id="ios_extension-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="ios_extension-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_extension-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="ios_extension-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_extension-entitlements"></a>entitlements |  The entitlements file required for device builds of this target. If absent, the default entitlements from the provisioning profile will be used.<br><br>The following variables are substituted in the entitlements file: <code>$(CFBundleIdentifier)</code> with the bundle ID of the application and <code>$(AppIdentifierPrefix)</code> with the value of the <code>ApplicationIdentifierPrefix</code> key from the target's provisioning profile.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_extension-entitlements_validation"></a>entitlements_validation |  An [<code>entitlements_validation_mode</code>](/doc/types.md#entitlements-validation-mode) to control the validation of the requested entitlements against the provisioning profile to ensure they are supported.   | String | optional | "loose" |
| <a id="ios_extension-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="ios_extension-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_extension-families"></a>families |  A list of device families supported by this extension. Valid values are <code>iphone</code> and <code>ipad</code>; at least one must be specified.   | List of strings | required |  |
| <a id="ios_extension-frameworks"></a>frameworks |  A list of framework targets (see [<code>ios_framework</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-ios.md#ios_framework)) that this target depends on.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_extension-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="ios_extension-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_extension-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="ios_extension-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="ios_extension-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="ios_extension-platform_type"></a>platform_type |  -   | String | optional | "ios" |
| <a id="ios_extension-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.mobileprovision</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_extension-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_extension-sdk_frameworks"></a>sdk_frameworks |  Names of SDK frameworks to link with (e.g., <code>AddressBook</code>, <code>QuartzCore</code>). <code>UIKit</code> and <code>Foundation</code> are always included, even if this attribute is provided and does not list them.<br><br>This attribute is discouraged; in general, targets should list system framework dependencies in the library targets where that framework is used, not in the top-level bundle.   | List of strings | optional | [] |
| <a id="ios_extension-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="ios_extension-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_extension-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-versioning.md#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="ios_framework"></a>

## ios_framework

<pre>
ios_framework(<a href="#ios_framework-name">name</a>, <a href="#ios_framework-additional_linker_inputs">additional_linker_inputs</a>, <a href="#ios_framework-bundle_id">bundle_id</a>, <a href="#ios_framework-bundle_name">bundle_name</a>, <a href="#ios_framework-bundle_only">bundle_only</a>, <a href="#ios_framework-codesign_inputs">codesign_inputs</a>,
              <a href="#ios_framework-codesignopts">codesignopts</a>, <a href="#ios_framework-deps">deps</a>, <a href="#ios_framework-executable_name">executable_name</a>, <a href="#ios_framework-exported_symbols_lists">exported_symbols_lists</a>, <a href="#ios_framework-extension_safe">extension_safe</a>, <a href="#ios_framework-families">families</a>,
              <a href="#ios_framework-frameworks">frameworks</a>, <a href="#ios_framework-hdrs">hdrs</a>, <a href="#ios_framework-infoplists">infoplists</a>, <a href="#ios_framework-ipa_post_processor">ipa_post_processor</a>, <a href="#ios_framework-linkopts">linkopts</a>,
              <a href="#ios_framework-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#ios_framework-minimum_os_version">minimum_os_version</a>, <a href="#ios_framework-platform_type">platform_type</a>, <a href="#ios_framework-provisioning_profile">provisioning_profile</a>,
              <a href="#ios_framework-resources">resources</a>, <a href="#ios_framework-stamp">stamp</a>, <a href="#ios_framework-strings">strings</a>, <a href="#ios_framework-version">version</a>)
</pre>

Builds and bundles an iOS Dynamic Framework.

To use this framework for your app and extensions, list it in the `frameworks` attributes
of those `ios_application` and/or `ios_extension` rules.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="ios_framework-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="ios_framework-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_framework-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target.   | String | required |  |
| <a id="ios_framework-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="ios_framework-bundle_only"></a>bundle_only |  Avoid linking the dynamic framework, but still include it in the app. This is useful when you want to manually dlopen the framework at runtime.   | Boolean | optional | False |
| <a id="ios_framework-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_framework-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="ios_framework-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_framework-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="ios_framework-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_framework-extension_safe"></a>extension_safe |  If true, compiles and links this framework with <code>-application-extension</code>, restricting the binary to use only extension-safe APIs.   | Boolean | optional | False |
| <a id="ios_framework-families"></a>families |  A list of device families supported by this extension. Valid values are <code>iphone</code> and <code>ipad</code>; at least one must be specified.   | List of strings | required |  |
| <a id="ios_framework-frameworks"></a>frameworks |  A list of framework targets (see [<code>ios_framework</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-ios.md#ios_framework)) that this target depends on.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_framework-hdrs"></a>hdrs |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_framework-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="ios_framework-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_framework-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="ios_framework-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="ios_framework-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="ios_framework-platform_type"></a>platform_type |  -   | String | optional | "ios" |
| <a id="ios_framework-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.mobileprovision</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_framework-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_framework-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="ios_framework-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_framework-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-versioning.md#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="ios_imessage_application"></a>

## ios_imessage_application

<pre>
ios_imessage_application(<a href="#ios_imessage_application-name">name</a>, <a href="#ios_imessage_application-app_icons">app_icons</a>, <a href="#ios_imessage_application-bundle_id">bundle_id</a>, <a href="#ios_imessage_application-bundle_name">bundle_name</a>, <a href="#ios_imessage_application-entitlements">entitlements</a>,
                         <a href="#ios_imessage_application-entitlements_validation">entitlements_validation</a>, <a href="#ios_imessage_application-executable_name">executable_name</a>, <a href="#ios_imessage_application-extension">extension</a>, <a href="#ios_imessage_application-families">families</a>, <a href="#ios_imessage_application-infoplists">infoplists</a>,
                         <a href="#ios_imessage_application-ipa_post_processor">ipa_post_processor</a>, <a href="#ios_imessage_application-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#ios_imessage_application-minimum_os_version">minimum_os_version</a>,
                         <a href="#ios_imessage_application-platform_type">platform_type</a>, <a href="#ios_imessage_application-provisioning_profile">provisioning_profile</a>, <a href="#ios_imessage_application-resources">resources</a>, <a href="#ios_imessage_application-strings">strings</a>, <a href="#ios_imessage_application-version">version</a>)
</pre>

Builds and bundles an iOS iMessage Application.

iOS iMessage applications do not have any dependencies, as it works mostly as a wrapper
for either an iOS iMessage extension or a Sticker Pack extension.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="ios_imessage_application-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="ios_imessage_application-app_icons"></a>app_icons |  Files that comprise the app icons for the application. Each file must have a containing directory named <code>*..xcassets/*..appiconset</code> and there may be only one such <code>..appiconset</code> directory in the list.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_imessage_application-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target.   | String | required |  |
| <a id="ios_imessage_application-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="ios_imessage_application-entitlements"></a>entitlements |  The entitlements file required for device builds of this target. If absent, the default entitlements from the provisioning profile will be used.<br><br>The following variables are substituted in the entitlements file: <code>$(CFBundleIdentifier)</code> with the bundle ID of the application and <code>$(AppIdentifierPrefix)</code> with the value of the <code>ApplicationIdentifierPrefix</code> key from the target's provisioning profile.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_imessage_application-entitlements_validation"></a>entitlements_validation |  An [<code>entitlements_validation_mode</code>](/doc/types.md#entitlements-validation-mode) to control the validation of the requested entitlements against the provisioning profile to ensure they are supported.   | String | optional | "loose" |
| <a id="ios_imessage_application-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="ios_imessage_application-extension"></a>extension |  Single label referencing either an ios_imessage_extension or ios_sticker_pack_extension target. Required.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="ios_imessage_application-families"></a>families |  A list of device families supported by this extension. Valid values are <code>iphone</code> and <code>ipad</code>; at least one must be specified.   | List of strings | required |  |
| <a id="ios_imessage_application-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="ios_imessage_application-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_imessage_application-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="ios_imessage_application-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="ios_imessage_application-platform_type"></a>platform_type |  -   | String | optional | "ios" |
| <a id="ios_imessage_application-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.mobileprovision</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_imessage_application-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_imessage_application-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_imessage_application-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-versioning.md#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="ios_imessage_extension"></a>

## ios_imessage_extension

<pre>
ios_imessage_extension(<a href="#ios_imessage_extension-name">name</a>, <a href="#ios_imessage_extension-additional_linker_inputs">additional_linker_inputs</a>, <a href="#ios_imessage_extension-app_icons">app_icons</a>, <a href="#ios_imessage_extension-bundle_id">bundle_id</a>, <a href="#ios_imessage_extension-bundle_name">bundle_name</a>,
                       <a href="#ios_imessage_extension-codesign_inputs">codesign_inputs</a>, <a href="#ios_imessage_extension-codesignopts">codesignopts</a>, <a href="#ios_imessage_extension-deps">deps</a>, <a href="#ios_imessage_extension-entitlements">entitlements</a>, <a href="#ios_imessage_extension-entitlements_validation">entitlements_validation</a>,
                       <a href="#ios_imessage_extension-executable_name">executable_name</a>, <a href="#ios_imessage_extension-exported_symbols_lists">exported_symbols_lists</a>, <a href="#ios_imessage_extension-families">families</a>, <a href="#ios_imessage_extension-frameworks">frameworks</a>, <a href="#ios_imessage_extension-infoplists">infoplists</a>,
                       <a href="#ios_imessage_extension-ipa_post_processor">ipa_post_processor</a>, <a href="#ios_imessage_extension-linkopts">linkopts</a>, <a href="#ios_imessage_extension-minimum_deployment_os_version">minimum_deployment_os_version</a>,
                       <a href="#ios_imessage_extension-minimum_os_version">minimum_os_version</a>, <a href="#ios_imessage_extension-platform_type">platform_type</a>, <a href="#ios_imessage_extension-provisioning_profile">provisioning_profile</a>, <a href="#ios_imessage_extension-resources">resources</a>, <a href="#ios_imessage_extension-stamp">stamp</a>,
                       <a href="#ios_imessage_extension-strings">strings</a>, <a href="#ios_imessage_extension-version">version</a>)
</pre>

Builds and bundles an iOS iMessage Extension.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="ios_imessage_extension-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="ios_imessage_extension-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_imessage_extension-app_icons"></a>app_icons |  Files that comprise the app icons for the application. Each file must have a containing directory named <code>*..xcassets/*..stickersiconset</code> and there may be only one such <code>..stickersiconset</code> directory in the list.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_imessage_extension-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target.   | String | required |  |
| <a id="ios_imessage_extension-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="ios_imessage_extension-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_imessage_extension-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="ios_imessage_extension-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_imessage_extension-entitlements"></a>entitlements |  The entitlements file required for device builds of this target. If absent, the default entitlements from the provisioning profile will be used.<br><br>The following variables are substituted in the entitlements file: <code>$(CFBundleIdentifier)</code> with the bundle ID of the application and <code>$(AppIdentifierPrefix)</code> with the value of the <code>ApplicationIdentifierPrefix</code> key from the target's provisioning profile.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_imessage_extension-entitlements_validation"></a>entitlements_validation |  An [<code>entitlements_validation_mode</code>](/doc/types.md#entitlements-validation-mode) to control the validation of the requested entitlements against the provisioning profile to ensure they are supported.   | String | optional | "loose" |
| <a id="ios_imessage_extension-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="ios_imessage_extension-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_imessage_extension-families"></a>families |  A list of device families supported by this extension. Valid values are <code>iphone</code> and <code>ipad</code>; at least one must be specified.   | List of strings | required |  |
| <a id="ios_imessage_extension-frameworks"></a>frameworks |  A list of framework targets (see [<code>ios_framework</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-ios.md#ios_framework)) that this target depends on.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_imessage_extension-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="ios_imessage_extension-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_imessage_extension-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="ios_imessage_extension-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="ios_imessage_extension-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="ios_imessage_extension-platform_type"></a>platform_type |  -   | String | optional | "ios" |
| <a id="ios_imessage_extension-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.mobileprovision</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_imessage_extension-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_imessage_extension-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="ios_imessage_extension-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_imessage_extension-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-versioning.md#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="ios_static_framework"></a>

## ios_static_framework

<pre>
ios_static_framework(<a href="#ios_static_framework-name">name</a>, <a href="#ios_static_framework-additional_linker_inputs">additional_linker_inputs</a>, <a href="#ios_static_framework-avoid_deps">avoid_deps</a>, <a href="#ios_static_framework-bundle_name">bundle_name</a>, <a href="#ios_static_framework-codesign_inputs">codesign_inputs</a>,
                     <a href="#ios_static_framework-codesignopts">codesignopts</a>, <a href="#ios_static_framework-deps">deps</a>, <a href="#ios_static_framework-exclude_resources">exclude_resources</a>, <a href="#ios_static_framework-executable_name">executable_name</a>, <a href="#ios_static_framework-exported_symbols_lists">exported_symbols_lists</a>,
                     <a href="#ios_static_framework-families">families</a>, <a href="#ios_static_framework-frameworks">frameworks</a>, <a href="#ios_static_framework-hdrs">hdrs</a>, <a href="#ios_static_framework-ipa_post_processor">ipa_post_processor</a>, <a href="#ios_static_framework-linkopts">linkopts</a>,
                     <a href="#ios_static_framework-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#ios_static_framework-minimum_os_version">minimum_os_version</a>, <a href="#ios_static_framework-platform_type">platform_type</a>, <a href="#ios_static_framework-resources">resources</a>,
                     <a href="#ios_static_framework-stamp">stamp</a>, <a href="#ios_static_framework-strings">strings</a>, <a href="#ios_static_framework-umbrella_header">umbrella_header</a>, <a href="#ios_static_framework-version">version</a>)
</pre>

Builds and bundles an iOS static framework for third-party distribution.

A static framework is bundled like a dynamic framework except that the embedded
binary is a static library rather than a dynamic library. It is intended to
create distributable static SDKs or artifacts that can be easily imported into
other Xcode projects; it is specifically **not** intended to be used as a
dependency of other Bazel targets. For that use case, use the corresponding
`objc_library` targets directly.

Unlike other iOS bundles, the fat binary in an `ios_static_framework` may
simultaneously contain simulator and device architectures (that is, you can
build a single framework artifact that works for all architectures by specifying
`--ios_multi_cpus=i386,x86_64,armv7,arm64` when you build).

`ios_static_framework` supports Swift, but there are some constraints:

* `ios_static_framework` with Swift only works with Xcode 11 and above, since
  the required Swift functionality for module compatibility is available in
  Swift 5.1.
* `ios_static_framework` only supports a single direct `swift_library` target
  that does not depend transitively on any other `swift_library` targets. The
  Swift compiler expects a framework to contain a single Swift module, and each
  `swift_library` target is its own module by definition.
* `ios_static_framework` does not support mixed Objective-C and Swift public
  interfaces. This means that the `umbrella_header` and `hdrs` attributes are
  unavailable when using `swift_library` dependencies. You are allowed to depend
  on `objc_library` from the main `swift_library` dependency, but note that only
  the `swift_library`'s public interface will be available to users of the
  static framework.

When using Swift, the `ios_static_framework` bundles `swiftinterface` and
`swiftdocs` file for each of the required architectures. It also bundles an
umbrella header which is the header generated by the single `swift_library`
target. Finally, it also bundles a `module.modulemap` file pointing to the
umbrella header for Objetive-C module compatibility. This umbrella header and
modulemap can be skipped by disabling the `swift.no_generated_header` feature (
i.e. `--features=-swift.no_generated_header`).

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="ios_static_framework-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="ios_static_framework-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_static_framework-avoid_deps"></a>avoid_deps |  A list of library targets on which this framework depends in order to compile, but the transitive closure of which will not be linked into the framework's binary.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_static_framework-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="ios_static_framework-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_static_framework-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="ios_static_framework-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_static_framework-exclude_resources"></a>exclude_resources |  Indicates whether resources should be excluded from the bundle. This can be used to avoid unnecessarily bundling resources if the static framework is being distributed in a different fashion, such as a Cocoapod.   | Boolean | optional | False |
| <a id="ios_static_framework-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="ios_static_framework-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_static_framework-families"></a>families |  A list of device families supported by this extension. Valid values are <code>iphone</code> and <code>ipad</code>; at least one must be specified.   | List of strings | optional | ["iphone", "ipad"] |
| <a id="ios_static_framework-frameworks"></a>frameworks |  A list of framework targets (see [<code>ios_framework</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-ios.md#ios_framework)) that this target depends on.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_static_framework-hdrs"></a>hdrs |  A list of <code>.h</code> files that will be publicly exposed by this framework. These headers should have framework-relative imports, and if non-empty, an umbrella header named <code>%{bundle_name}.h</code> will also be generated that imports all of the headers listed here.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_static_framework-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_static_framework-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="ios_static_framework-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="ios_static_framework-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="ios_static_framework-platform_type"></a>platform_type |  -   | String | optional | "ios" |
| <a id="ios_static_framework-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_static_framework-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="ios_static_framework-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_static_framework-umbrella_header"></a>umbrella_header |  An optional single .h file to use as the umbrella header for this framework. Usually, this header will have the same name as this target, so that clients can load the header using the #import &lt;MyFramework/MyFramework.h&gt; format. If this attribute is not specified (the common use case), an umbrella header will be generated under the same name as this target.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_static_framework-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-versioning.md#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="ios_sticker_pack_extension"></a>

## ios_sticker_pack_extension

<pre>
ios_sticker_pack_extension(<a href="#ios_sticker_pack_extension-name">name</a>, <a href="#ios_sticker_pack_extension-app_icons">app_icons</a>, <a href="#ios_sticker_pack_extension-bundle_id">bundle_id</a>, <a href="#ios_sticker_pack_extension-bundle_name">bundle_name</a>, <a href="#ios_sticker_pack_extension-entitlements">entitlements</a>,
                           <a href="#ios_sticker_pack_extension-entitlements_validation">entitlements_validation</a>, <a href="#ios_sticker_pack_extension-executable_name">executable_name</a>, <a href="#ios_sticker_pack_extension-families">families</a>, <a href="#ios_sticker_pack_extension-infoplists">infoplists</a>,
                           <a href="#ios_sticker_pack_extension-ipa_post_processor">ipa_post_processor</a>, <a href="#ios_sticker_pack_extension-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#ios_sticker_pack_extension-minimum_os_version">minimum_os_version</a>,
                           <a href="#ios_sticker_pack_extension-platform_type">platform_type</a>, <a href="#ios_sticker_pack_extension-provisioning_profile">provisioning_profile</a>, <a href="#ios_sticker_pack_extension-resources">resources</a>, <a href="#ios_sticker_pack_extension-sticker_assets">sticker_assets</a>, <a href="#ios_sticker_pack_extension-strings">strings</a>,
                           <a href="#ios_sticker_pack_extension-version">version</a>)
</pre>

Builds and bundles an iOS Sticker Pack Extension.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="ios_sticker_pack_extension-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="ios_sticker_pack_extension-app_icons"></a>app_icons |  Files that comprise the app icons for the application. Each file must have a containing directory named <code>*..xcstickers/*..stickersiconset</code> and there may be only one such <code>..stickersiconset</code> directory in the list.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_sticker_pack_extension-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target.   | String | required |  |
| <a id="ios_sticker_pack_extension-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="ios_sticker_pack_extension-entitlements"></a>entitlements |  The entitlements file required for device builds of this target. If absent, the default entitlements from the provisioning profile will be used.<br><br>The following variables are substituted in the entitlements file: <code>$(CFBundleIdentifier)</code> with the bundle ID of the application and <code>$(AppIdentifierPrefix)</code> with the value of the <code>ApplicationIdentifierPrefix</code> key from the target's provisioning profile.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_sticker_pack_extension-entitlements_validation"></a>entitlements_validation |  An [<code>entitlements_validation_mode</code>](/doc/types.md#entitlements-validation-mode) to control the validation of the requested entitlements against the provisioning profile to ensure they are supported.   | String | optional | "loose" |
| <a id="ios_sticker_pack_extension-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="ios_sticker_pack_extension-families"></a>families |  A list of device families supported by this extension. Valid values are <code>iphone</code> and <code>ipad</code>; at least one must be specified.   | List of strings | required |  |
| <a id="ios_sticker_pack_extension-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="ios_sticker_pack_extension-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_sticker_pack_extension-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="ios_sticker_pack_extension-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="ios_sticker_pack_extension-platform_type"></a>platform_type |  -   | String | optional | "ios" |
| <a id="ios_sticker_pack_extension-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.mobileprovision</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="ios_sticker_pack_extension-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_sticker_pack_extension-sticker_assets"></a>sticker_assets |  List of sticker files to bundle. The collection of assets should be under a folder named <code>*.*.xcstickers</code>. The icons go in a <code>*.stickersiconset</code> (instead of <code>*.appiconset</code>); and the files for the stickers should all be in Sticker Pack directories, so <code>*.stickerpack/*.sticker</code> or <code>*.stickerpack/*.stickersequence</code>.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_sticker_pack_extension-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_sticker_pack_extension-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-versioning.md#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="ios_ui_test"></a>

## ios_ui_test

<pre>
ios_ui_test(<a href="#ios_ui_test-name">name</a>, <a href="#ios_ui_test-data">data</a>, <a href="#ios_ui_test-deps">deps</a>, <a href="#ios_ui_test-env">env</a>, <a href="#ios_ui_test-platform_type">platform_type</a>, <a href="#ios_ui_test-runner">runner</a>, <a href="#ios_ui_test-test_host">test_host</a>)
</pre>

iOS UI Test rule.

Builds and bundles an iOS UI `.xctest` test bundle. Runs the tests using the
provided test runner when invoked with `bazel test`. When using Tulsi to run
tests built with this target, `runner` will not be used since Xcode is the test
runner in that case.

To run the same test on multiple simulators/devices see
[ios_ui_test_suite](#ios_ui_test_suite).

The following is a list of the `ios_ui_test` specific attributes; for a list
of the attributes inherited by all test rules, please check the
[Bazel documentation](https://bazel.build/reference/be/common-definitions#common-attributes-tests).


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="ios_ui_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="ios_ui_test-data"></a>data |  Files to be made available to the test during its execution.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_ui_test-deps"></a>deps |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="ios_ui_test-env"></a>env |  Dictionary of environment variables that should be set during the test execution.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="ios_ui_test-platform_type"></a>platform_type |  -   | String | optional | "ios" |
| <a id="ios_ui_test-runner"></a>runner |  The runner target that will provide the logic on how to run the tests. Needs to provide the AppleTestRunnerInfo provider.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="ios_ui_test-test_host"></a>test_host |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="ios_unit_test"></a>

## ios_unit_test

<pre>
ios_unit_test(<a href="#ios_unit_test-name">name</a>, <a href="#ios_unit_test-data">data</a>, <a href="#ios_unit_test-deps">deps</a>, <a href="#ios_unit_test-env">env</a>, <a href="#ios_unit_test-platform_type">platform_type</a>, <a href="#ios_unit_test-runner">runner</a>, <a href="#ios_unit_test-test_host">test_host</a>)
</pre>

Builds and bundles an iOS Unit `.xctest` test bundle. Runs the tests using the
provided test runner when invoked with `bazel test`. When using Tulsi to run
tests built with this target, `runner` will not be used since Xcode is the test
runner in that case.

`ios_unit_test` targets can work in two modes: as app or library
tests. If the `test_host` attribute is set to an `ios_application` target, the
tests will run within that application's context. If no `test_host` is provided,
the tests will run outside the context of an iOS application. Because of this,
certain functionalities might not be present (e.g. UI layout, NSUserDefaults).
You can find more information about app and library testing for Apple platforms
[here](https://developer.apple.com/library/content/documentation/DeveloperTools/Conceptual/testing_with_xcode/chapters/03-testing_basics.html).

To run the same test on multiple simulators/devices see
[ios_unit_test_suite](#ios_unit_test_suite).

The following is a list of the `ios_unit_test` specific attributes; for a list
of the attributes inherited by all test rules, please check the
[Bazel documentation](https://bazel.build/reference/be/common-definitions#common-attributes-tests).

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="ios_unit_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="ios_unit_test-data"></a>data |  Files to be made available to the test during its execution.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ios_unit_test-deps"></a>deps |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="ios_unit_test-env"></a>env |  Dictionary of environment variables that should be set during the test execution.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="ios_unit_test-platform_type"></a>platform_type |  -   | String | optional | "ios" |
| <a id="ios_unit_test-runner"></a>runner |  The runner target that will provide the logic on how to run the tests. Needs to provide the AppleTestRunnerInfo provider.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="ios_unit_test-test_host"></a>test_host |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="ios_ui_test_suite"></a>

## ios_ui_test_suite

<pre>
ios_ui_test_suite(<a href="#ios_ui_test_suite-name">name</a>, <a href="#ios_ui_test_suite-runners">runners</a>, <a href="#ios_ui_test_suite-kwargs">kwargs</a>)
</pre>

Generates a [test_suite] containing an [ios_ui_test] for each of the given `runners`.

`ios_ui_test_suite` takes the same parameters as [ios_ui_test], except `runner` is replaced by `runners`.

[test_suite]: https://docs.bazel.build/versions/master/be/general.html#test_suite
[ios_ui_test]: #ios_ui_test


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="ios_ui_test_suite-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="ios_ui_test_suite-runners"></a>runners |  a list of runner targets   |  <code>None</code> |
| <a id="ios_ui_test_suite-kwargs"></a>kwargs |  passed to the [ios_ui_test]   |  none |


<a id="ios_unit_test_suite"></a>

## ios_unit_test_suite

<pre>
ios_unit_test_suite(<a href="#ios_unit_test_suite-name">name</a>, <a href="#ios_unit_test_suite-runners">runners</a>, <a href="#ios_unit_test_suite-kwargs">kwargs</a>)
</pre>

Generates a [test_suite] containing an [ios_unit_test] for each of the given `runners`.

`ios_unit_test_suite` takes the same parameters as [ios_unit_test], except `runner` is replaced by `runners`.

[test_suite]: https://docs.bazel.build/versions/master/be/general.html#test_suite
[ios_unit_test]: #ios_unit_test


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="ios_unit_test_suite-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="ios_unit_test_suite-runners"></a>runners |  a list of runner targets   |  <code>None</code> |
| <a id="ios_unit_test_suite-kwargs"></a>kwargs |  passed to the [ios_unit_test]   |  none |


