<!-- Generated with Stardoc, Do Not Edit! -->

# Bazel rules for creating macOS applications and bundles.
<a id="#macos_application"></a>

## macos_application

<pre>
macos_application(<a href="#macos_application-name">name</a>, <a href="#macos_application-additional_contents">additional_contents</a>, <a href="#macos_application-additional_linker_inputs">additional_linker_inputs</a>, <a href="#macos_application-app_icons">app_icons</a>, <a href="#macos_application-bundle_extension">bundle_extension</a>,
                  <a href="#macos_application-bundle_id">bundle_id</a>, <a href="#macos_application-bundle_name">bundle_name</a>, <a href="#macos_application-codesign_inputs">codesign_inputs</a>, <a href="#macos_application-codesignopts">codesignopts</a>, <a href="#macos_application-deps">deps</a>, <a href="#macos_application-entitlements">entitlements</a>,
                  <a href="#macos_application-entitlements_validation">entitlements_validation</a>, <a href="#macos_application-executable_name">executable_name</a>, <a href="#macos_application-exported_symbols_lists">exported_symbols_lists</a>, <a href="#macos_application-extensions">extensions</a>,
                  <a href="#macos_application-include_symbols_in_bundle">include_symbols_in_bundle</a>, <a href="#macos_application-infoplists">infoplists</a>, <a href="#macos_application-ipa_post_processor">ipa_post_processor</a>, <a href="#macos_application-linkopts">linkopts</a>,
                  <a href="#macos_application-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#macos_application-minimum_os_version">minimum_os_version</a>, <a href="#macos_application-platform_type">platform_type</a>,
                  <a href="#macos_application-provisioning_profile">provisioning_profile</a>, <a href="#macos_application-resources">resources</a>, <a href="#macos_application-stamp">stamp</a>, <a href="#macos_application-strings">strings</a>, <a href="#macos_application-version">version</a>, <a href="#macos_application-xpc_services">xpc_services</a>)
</pre>

Builds and bundles a macOS Application.

This rule creates an application that is a `.app` bundle. If you want to build a
simple command line tool as a standalone binary, use
[`macos_command_line_application`](#macos_command_line_application) instead.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="macos_application-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="macos_application-additional_contents"></a>additional_contents |  Files that should be copied into specific subdirectories of the Contents folder in the bundle. The keys of this dictionary are labels pointing to single files, filegroups, or targets; the corresponding value is the name of the subdirectory of Contents where they should be placed.<br><br>The relative directory structure of filegroup contents is preserved when they are copied into the desired Contents subdirectory.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: Label -> String</a> | optional | {} |
| <a id="macos_application-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_application-app_icons"></a>app_icons |  Files that comprise the app icons for the application. Each file must have a containing directory named <code>*..xcassets/*..appiconset</code> and there may be only one such <code>..appiconset</code> directory in the list.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_application-bundle_extension"></a>bundle_extension |  The extension, without a leading dot, that will be used to name the bundle. If this attribute is not set, then the default extension is determined by the application's product_type.   | String | optional | "" |
| <a id="macos_application-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target.   | String | required |  |
| <a id="macos_application-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="macos_application-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_application-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="macos_application-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_application-entitlements"></a>entitlements |  The entitlements file required for device builds of this target. If absent, the default entitlements from the provisioning profile will be used.<br><br>The following variables are substituted in the entitlements file: <code>$(CFBundleIdentifier)</code> with the bundle ID of the application and <code>$(AppIdentifierPrefix)</code> with the value of the <code>ApplicationIdentifierPrefix</code> key from the target's provisioning profile.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_application-entitlements_validation"></a>entitlements_validation |  An [<code>entitlements_validation_mode</code>](/doc/types.md#entitlements-validation-mode) to control the validation of the requested entitlements against the provisioning profile to ensure they are supported.   | String | optional | "loose" |
| <a id="macos_application-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="macos_application-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_application-extensions"></a>extensions |  A list of macOS extensions to include in the final application bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_application-include_symbols_in_bundle"></a>include_symbols_in_bundle |  If true and --output_groups=+dsyms is specified, generates <code>$UUID.symbols</code>     files from all <code>{binary: .dSYM, ...}</code> pairs for the application and its     dependencies, then packages them under the <code>Symbols/</code> directory in the     final application bundle.   | Boolean | optional | False |
| <a id="macos_application-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="macos_application-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_application-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="macos_application-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="macos_application-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="macos_application-platform_type"></a>platform_type |  -   | String | optional | "macos" |
| <a id="macos_application-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.provisionprofile</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_application-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_application-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="macos_application-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_application-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_application-xpc_services"></a>xpc_services |  A list of macOS XPC Services to include in the final application bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |


<a id="#macos_build_test"></a>

## macos_build_test

<pre>
macos_build_test(<a href="#macos_build_test-name">name</a>, <a href="#macos_build_test-minimum_os_version">minimum_os_version</a>, <a href="#macos_build_test-platform_type">platform_type</a>, <a href="#macos_build_test-targets">targets</a>)
</pre>

Test rule to check that the given library targets (Swift, Objective-C, C++)
build for macOS.

Typical usage:

```starlark
macos_build_test(
    name = "my_build_test",
    minimum_os_version = "10.14",
    targets = [
        "//some/package:my_library",
    ],
)
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="macos_build_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="macos_build_test-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version that will be used as the deployment target when building the targets, represented as a dotted version number (for example, <code>"9.0"</code>).   | String | optional | "" |
| <a id="macos_build_test-platform_type"></a>platform_type |  -   | String | optional | "macos" |
| <a id="macos_build_test-targets"></a>targets |  The targets to check for successful build.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |


<a id="#macos_bundle"></a>

## macos_bundle

<pre>
macos_bundle(<a href="#macos_bundle-name">name</a>, <a href="#macos_bundle-additional_contents">additional_contents</a>, <a href="#macos_bundle-additional_linker_inputs">additional_linker_inputs</a>, <a href="#macos_bundle-app_icons">app_icons</a>, <a href="#macos_bundle-bundle_extension">bundle_extension</a>,
             <a href="#macos_bundle-bundle_id">bundle_id</a>, <a href="#macos_bundle-bundle_loader">bundle_loader</a>, <a href="#macos_bundle-bundle_name">bundle_name</a>, <a href="#macos_bundle-codesign_inputs">codesign_inputs</a>, <a href="#macos_bundle-codesignopts">codesignopts</a>, <a href="#macos_bundle-deps">deps</a>, <a href="#macos_bundle-entitlements">entitlements</a>,
             <a href="#macos_bundle-entitlements_validation">entitlements_validation</a>, <a href="#macos_bundle-executable_name">executable_name</a>, <a href="#macos_bundle-exported_symbols_lists">exported_symbols_lists</a>, <a href="#macos_bundle-infoplists">infoplists</a>,
             <a href="#macos_bundle-ipa_post_processor">ipa_post_processor</a>, <a href="#macos_bundle-linkopts">linkopts</a>, <a href="#macos_bundle-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#macos_bundle-minimum_os_version">minimum_os_version</a>,
             <a href="#macos_bundle-platform_type">platform_type</a>, <a href="#macos_bundle-provisioning_profile">provisioning_profile</a>, <a href="#macos_bundle-resources">resources</a>, <a href="#macos_bundle-stamp">stamp</a>, <a href="#macos_bundle-strings">strings</a>, <a href="#macos_bundle-version">version</a>)
</pre>

Builds and bundles a macOS Loadable Bundle.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="macos_bundle-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="macos_bundle-additional_contents"></a>additional_contents |  Files that should be copied into specific subdirectories of the Contents folder in the bundle. The keys of this dictionary are labels pointing to single files, filegroups, or targets; the corresponding value is the name of the subdirectory of Contents where they should be placed.<br><br>The relative directory structure of filegroup contents is preserved when they are copied into the desired Contents subdirectory.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: Label -> String</a> | optional | {} |
| <a id="macos_bundle-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_bundle-app_icons"></a>app_icons |  Files that comprise the app icons for the application. Each file must have a containing directory named <code>*..xcassets/*..appiconset</code> and there may be only one such <code>..appiconset</code> directory in the list.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_bundle-bundle_extension"></a>bundle_extension |  The extension, without a leading dot, that will be used to name the bundle. If this attribute is not set, then the default extension is determined by the application's product_type.   | String | optional | "" |
| <a id="macos_bundle-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target.   | String | required |  |
| <a id="macos_bundle-bundle_loader"></a>bundle_loader |  The target representing the executable that will be loading this bundle. Undefined symbols from the bundle are checked against this execuable during linking as if it were one of the dynamic libraries the bundle was linked with.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_bundle-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="macos_bundle-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_bundle-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="macos_bundle-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_bundle-entitlements"></a>entitlements |  The entitlements file required for device builds of this target. If absent, the default entitlements from the provisioning profile will be used.<br><br>The following variables are substituted in the entitlements file: <code>$(CFBundleIdentifier)</code> with the bundle ID of the application and <code>$(AppIdentifierPrefix)</code> with the value of the <code>ApplicationIdentifierPrefix</code> key from the target's provisioning profile.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_bundle-entitlements_validation"></a>entitlements_validation |  An [<code>entitlements_validation_mode</code>](/doc/types.md#entitlements-validation-mode) to control the validation of the requested entitlements against the provisioning profile to ensure they are supported.   | String | optional | "loose" |
| <a id="macos_bundle-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="macos_bundle-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_bundle-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="macos_bundle-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_bundle-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="macos_bundle-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="macos_bundle-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="macos_bundle-platform_type"></a>platform_type |  -   | String | optional | "macos" |
| <a id="macos_bundle-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.provisionprofile</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_bundle-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_bundle-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="macos_bundle-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_bundle-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="#macos_command_line_application"></a>

## macos_command_line_application

<pre>
macos_command_line_application(<a href="#macos_command_line_application-name">name</a>, <a href="#macos_command_line_application-additional_linker_inputs">additional_linker_inputs</a>, <a href="#macos_command_line_application-bundle_id">bundle_id</a>, <a href="#macos_command_line_application-codesign_inputs">codesign_inputs</a>,
                               <a href="#macos_command_line_application-codesignopts">codesignopts</a>, <a href="#macos_command_line_application-deps">deps</a>, <a href="#macos_command_line_application-exported_symbols_lists">exported_symbols_lists</a>, <a href="#macos_command_line_application-infoplists">infoplists</a>, <a href="#macos_command_line_application-launchdplists">launchdplists</a>,
                               <a href="#macos_command_line_application-linkopts">linkopts</a>, <a href="#macos_command_line_application-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#macos_command_line_application-minimum_os_version">minimum_os_version</a>,
                               <a href="#macos_command_line_application-platform_type">platform_type</a>, <a href="#macos_command_line_application-provisioning_profile">provisioning_profile</a>, <a href="#macos_command_line_application-stamp">stamp</a>, <a href="#macos_command_line_application-version">version</a>)
</pre>

Builds a macOS Command Line Application binary.


A command line application is a standalone binary file, rather than a `.app`
bundle like those produced by [`macos_application`](#macos_application). Unlike
a plain `apple_binary` target, however, this rule supports versioning and
embedding an `Info.plist` into the binary and allows the binary to be
code-signed.

Targets created with `macos_command_line_application` can be executed using
`bazel run`.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="macos_command_line_application-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="macos_command_line_application-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_command_line_application-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) of the command line application. If present, this value will be embedded in an Info.plist in the application binary.   | String | optional | "" |
| <a id="macos_command_line_application-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_command_line_application-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="macos_command_line_application-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_command_line_application-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_command_line_application-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist that represents the application and is embedded into the binary. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_command_line_application-launchdplists"></a>launchdplists |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_command_line_application-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="macos_command_line_application-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="macos_command_line_application-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "10.11").   | String | required |  |
| <a id="macos_command_line_application-platform_type"></a>platform_type |  -   | String | optional | "macos" |
| <a id="macos_command_line_application-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.provisionprofile</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_command_line_application-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="macos_command_line_application-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="#macos_dylib"></a>

## macos_dylib

<pre>
macos_dylib(<a href="#macos_dylib-name">name</a>, <a href="#macos_dylib-additional_linker_inputs">additional_linker_inputs</a>, <a href="#macos_dylib-bundle_id">bundle_id</a>, <a href="#macos_dylib-codesign_inputs">codesign_inputs</a>, <a href="#macos_dylib-codesignopts">codesignopts</a>, <a href="#macos_dylib-deps">deps</a>,
            <a href="#macos_dylib-exported_symbols_lists">exported_symbols_lists</a>, <a href="#macos_dylib-infoplists">infoplists</a>, <a href="#macos_dylib-linkopts">linkopts</a>, <a href="#macos_dylib-minimum_deployment_os_version">minimum_deployment_os_version</a>,
            <a href="#macos_dylib-minimum_os_version">minimum_os_version</a>, <a href="#macos_dylib-platform_type">platform_type</a>, <a href="#macos_dylib-provisioning_profile">provisioning_profile</a>, <a href="#macos_dylib-stamp">stamp</a>, <a href="#macos_dylib-version">version</a>)
</pre>

Builds a macOS Dylib binary.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="macos_dylib-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="macos_dylib-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_dylib-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) of the command line application. If present, this value will be embedded in an Info.plist in the application binary.   | String | optional | "" |
| <a id="macos_dylib-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_dylib-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="macos_dylib-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_dylib-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_dylib-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist that represents the application and is embedded into the binary. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_dylib-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="macos_dylib-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="macos_dylib-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "10.11").   | String | required |  |
| <a id="macos_dylib-platform_type"></a>platform_type |  -   | String | optional | "macos" |
| <a id="macos_dylib-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.mobileprovision</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_dylib-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="macos_dylib-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="#macos_extension"></a>

## macos_extension

<pre>
macos_extension(<a href="#macos_extension-name">name</a>, <a href="#macos_extension-additional_contents">additional_contents</a>, <a href="#macos_extension-additional_linker_inputs">additional_linker_inputs</a>, <a href="#macos_extension-app_icons">app_icons</a>, <a href="#macos_extension-bundle_id">bundle_id</a>,
                <a href="#macos_extension-bundle_name">bundle_name</a>, <a href="#macos_extension-codesign_inputs">codesign_inputs</a>, <a href="#macos_extension-codesignopts">codesignopts</a>, <a href="#macos_extension-deps">deps</a>, <a href="#macos_extension-entitlements">entitlements</a>,
                <a href="#macos_extension-entitlements_validation">entitlements_validation</a>, <a href="#macos_extension-executable_name">executable_name</a>, <a href="#macos_extension-exported_symbols_lists">exported_symbols_lists</a>, <a href="#macos_extension-infoplists">infoplists</a>,
                <a href="#macos_extension-ipa_post_processor">ipa_post_processor</a>, <a href="#macos_extension-linkopts">linkopts</a>, <a href="#macos_extension-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#macos_extension-minimum_os_version">minimum_os_version</a>,
                <a href="#macos_extension-platform_type">platform_type</a>, <a href="#macos_extension-provisioning_profile">provisioning_profile</a>, <a href="#macos_extension-resources">resources</a>, <a href="#macos_extension-stamp">stamp</a>, <a href="#macos_extension-strings">strings</a>, <a href="#macos_extension-version">version</a>)
</pre>

Builds and bundles a macOS Application Extension.

Most macOS app extensions use a plug-in-based architecture where the
executable's entry point is provided by a system framework. However, macOS 11
introduced Widget Extensions that use a traditional `main` entry
point (typically expressed through Swift's `@main` attribute).

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="macos_extension-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="macos_extension-additional_contents"></a>additional_contents |  Files that should be copied into specific subdirectories of the Contents folder in the bundle. The keys of this dictionary are labels pointing to single files, filegroups, or targets; the corresponding value is the name of the subdirectory of Contents where they should be placed.<br><br>The relative directory structure of filegroup contents is preserved when they are copied into the desired Contents subdirectory.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: Label -> String</a> | optional | {} |
| <a id="macos_extension-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_extension-app_icons"></a>app_icons |  Files that comprise the app icons for the application. Each file must have a containing directory named <code>*..xcassets/*..appiconset</code> and there may be only one such <code>..appiconset</code> directory in the list.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_extension-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target.   | String | required |  |
| <a id="macos_extension-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="macos_extension-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_extension-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="macos_extension-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_extension-entitlements"></a>entitlements |  The entitlements file required for device builds of this target. If absent, the default entitlements from the provisioning profile will be used.<br><br>The following variables are substituted in the entitlements file: <code>$(CFBundleIdentifier)</code> with the bundle ID of the application and <code>$(AppIdentifierPrefix)</code> with the value of the <code>ApplicationIdentifierPrefix</code> key from the target's provisioning profile.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_extension-entitlements_validation"></a>entitlements_validation |  An [<code>entitlements_validation_mode</code>](/doc/types.md#entitlements-validation-mode) to control the validation of the requested entitlements against the provisioning profile to ensure they are supported.   | String | optional | "loose" |
| <a id="macos_extension-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="macos_extension-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_extension-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="macos_extension-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_extension-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="macos_extension-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="macos_extension-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="macos_extension-platform_type"></a>platform_type |  -   | String | optional | "macos" |
| <a id="macos_extension-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.provisionprofile</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_extension-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_extension-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="macos_extension-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_extension-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="#macos_kernel_extension"></a>

## macos_kernel_extension

<pre>
macos_kernel_extension(<a href="#macos_kernel_extension-name">name</a>, <a href="#macos_kernel_extension-additional_contents">additional_contents</a>, <a href="#macos_kernel_extension-additional_linker_inputs">additional_linker_inputs</a>, <a href="#macos_kernel_extension-bundle_id">bundle_id</a>, <a href="#macos_kernel_extension-bundle_name">bundle_name</a>,
                       <a href="#macos_kernel_extension-codesign_inputs">codesign_inputs</a>, <a href="#macos_kernel_extension-codesignopts">codesignopts</a>, <a href="#macos_kernel_extension-deps">deps</a>, <a href="#macos_kernel_extension-entitlements">entitlements</a>, <a href="#macos_kernel_extension-entitlements_validation">entitlements_validation</a>,
                       <a href="#macos_kernel_extension-executable_name">executable_name</a>, <a href="#macos_kernel_extension-exported_symbols_lists">exported_symbols_lists</a>, <a href="#macos_kernel_extension-infoplists">infoplists</a>, <a href="#macos_kernel_extension-ipa_post_processor">ipa_post_processor</a>,
                       <a href="#macos_kernel_extension-linkopts">linkopts</a>, <a href="#macos_kernel_extension-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#macos_kernel_extension-minimum_os_version">minimum_os_version</a>, <a href="#macos_kernel_extension-platform_type">platform_type</a>,
                       <a href="#macos_kernel_extension-provisioning_profile">provisioning_profile</a>, <a href="#macos_kernel_extension-resources">resources</a>, <a href="#macos_kernel_extension-stamp">stamp</a>, <a href="#macos_kernel_extension-strings">strings</a>, <a href="#macos_kernel_extension-version">version</a>)
</pre>

Builds and bundles a macOS Kernel Extension.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="macos_kernel_extension-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="macos_kernel_extension-additional_contents"></a>additional_contents |  Files that should be copied into specific subdirectories of the Contents folder in the bundle. The keys of this dictionary are labels pointing to single files, filegroups, or targets; the corresponding value is the name of the subdirectory of Contents where they should be placed.<br><br>The relative directory structure of filegroup contents is preserved when they are copied into the desired Contents subdirectory.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: Label -> String</a> | optional | {} |
| <a id="macos_kernel_extension-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_kernel_extension-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target.   | String | required |  |
| <a id="macos_kernel_extension-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="macos_kernel_extension-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_kernel_extension-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="macos_kernel_extension-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_kernel_extension-entitlements"></a>entitlements |  The entitlements file required for device builds of this target. If absent, the default entitlements from the provisioning profile will be used.<br><br>The following variables are substituted in the entitlements file: <code>$(CFBundleIdentifier)</code> with the bundle ID of the application and <code>$(AppIdentifierPrefix)</code> with the value of the <code>ApplicationIdentifierPrefix</code> key from the target's provisioning profile.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_kernel_extension-entitlements_validation"></a>entitlements_validation |  An [<code>entitlements_validation_mode</code>](/doc/types.md#entitlements-validation-mode) to control the validation of the requested entitlements against the provisioning profile to ensure they are supported.   | String | optional | "loose" |
| <a id="macos_kernel_extension-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="macos_kernel_extension-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_kernel_extension-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="macos_kernel_extension-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_kernel_extension-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="macos_kernel_extension-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="macos_kernel_extension-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="macos_kernel_extension-platform_type"></a>platform_type |  -   | String | optional | "macos" |
| <a id="macos_kernel_extension-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.provisionprofile</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_kernel_extension-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_kernel_extension-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="macos_kernel_extension-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_kernel_extension-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="#macos_quick_look_plugin"></a>

## macos_quick_look_plugin

<pre>
macos_quick_look_plugin(<a href="#macos_quick_look_plugin-name">name</a>, <a href="#macos_quick_look_plugin-additional_contents">additional_contents</a>, <a href="#macos_quick_look_plugin-additional_linker_inputs">additional_linker_inputs</a>, <a href="#macos_quick_look_plugin-bundle_id">bundle_id</a>, <a href="#macos_quick_look_plugin-bundle_name">bundle_name</a>,
                        <a href="#macos_quick_look_plugin-codesign_inputs">codesign_inputs</a>, <a href="#macos_quick_look_plugin-codesignopts">codesignopts</a>, <a href="#macos_quick_look_plugin-deps">deps</a>, <a href="#macos_quick_look_plugin-entitlements">entitlements</a>, <a href="#macos_quick_look_plugin-entitlements_validation">entitlements_validation</a>,
                        <a href="#macos_quick_look_plugin-executable_name">executable_name</a>, <a href="#macos_quick_look_plugin-exported_symbols_lists">exported_symbols_lists</a>, <a href="#macos_quick_look_plugin-infoplists">infoplists</a>, <a href="#macos_quick_look_plugin-ipa_post_processor">ipa_post_processor</a>,
                        <a href="#macos_quick_look_plugin-linkopts">linkopts</a>, <a href="#macos_quick_look_plugin-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#macos_quick_look_plugin-minimum_os_version">minimum_os_version</a>, <a href="#macos_quick_look_plugin-platform_type">platform_type</a>,
                        <a href="#macos_quick_look_plugin-provisioning_profile">provisioning_profile</a>, <a href="#macos_quick_look_plugin-resources">resources</a>, <a href="#macos_quick_look_plugin-stamp">stamp</a>, <a href="#macos_quick_look_plugin-strings">strings</a>, <a href="#macos_quick_look_plugin-version">version</a>)
</pre>

Builds and bundles a macOS Quick Look Plugin.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="macos_quick_look_plugin-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="macos_quick_look_plugin-additional_contents"></a>additional_contents |  Files that should be copied into specific subdirectories of the Contents folder in the bundle. The keys of this dictionary are labels pointing to single files, filegroups, or targets; the corresponding value is the name of the subdirectory of Contents where they should be placed.<br><br>The relative directory structure of filegroup contents is preserved when they are copied into the desired Contents subdirectory.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: Label -> String</a> | optional | {} |
| <a id="macos_quick_look_plugin-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_quick_look_plugin-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target.   | String | required |  |
| <a id="macos_quick_look_plugin-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="macos_quick_look_plugin-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_quick_look_plugin-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="macos_quick_look_plugin-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_quick_look_plugin-entitlements"></a>entitlements |  The entitlements file required for device builds of this target. If absent, the default entitlements from the provisioning profile will be used.<br><br>The following variables are substituted in the entitlements file: <code>$(CFBundleIdentifier)</code> with the bundle ID of the application and <code>$(AppIdentifierPrefix)</code> with the value of the <code>ApplicationIdentifierPrefix</code> key from the target's provisioning profile.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_quick_look_plugin-entitlements_validation"></a>entitlements_validation |  An [<code>entitlements_validation_mode</code>](/doc/types.md#entitlements-validation-mode) to control the validation of the requested entitlements against the provisioning profile to ensure they are supported.   | String | optional | "loose" |
| <a id="macos_quick_look_plugin-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="macos_quick_look_plugin-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_quick_look_plugin-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="macos_quick_look_plugin-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_quick_look_plugin-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="macos_quick_look_plugin-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="macos_quick_look_plugin-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="macos_quick_look_plugin-platform_type"></a>platform_type |  -   | String | optional | "macos" |
| <a id="macos_quick_look_plugin-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.provisionprofile</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_quick_look_plugin-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_quick_look_plugin-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="macos_quick_look_plugin-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_quick_look_plugin-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="#macos_spotlight_importer"></a>

## macos_spotlight_importer

<pre>
macos_spotlight_importer(<a href="#macos_spotlight_importer-name">name</a>, <a href="#macos_spotlight_importer-additional_contents">additional_contents</a>, <a href="#macos_spotlight_importer-additional_linker_inputs">additional_linker_inputs</a>, <a href="#macos_spotlight_importer-bundle_id">bundle_id</a>,
                         <a href="#macos_spotlight_importer-bundle_name">bundle_name</a>, <a href="#macos_spotlight_importer-codesign_inputs">codesign_inputs</a>, <a href="#macos_spotlight_importer-codesignopts">codesignopts</a>, <a href="#macos_spotlight_importer-deps">deps</a>, <a href="#macos_spotlight_importer-entitlements">entitlements</a>,
                         <a href="#macos_spotlight_importer-entitlements_validation">entitlements_validation</a>, <a href="#macos_spotlight_importer-executable_name">executable_name</a>, <a href="#macos_spotlight_importer-exported_symbols_lists">exported_symbols_lists</a>, <a href="#macos_spotlight_importer-infoplists">infoplists</a>,
                         <a href="#macos_spotlight_importer-ipa_post_processor">ipa_post_processor</a>, <a href="#macos_spotlight_importer-linkopts">linkopts</a>, <a href="#macos_spotlight_importer-minimum_deployment_os_version">minimum_deployment_os_version</a>,
                         <a href="#macos_spotlight_importer-minimum_os_version">minimum_os_version</a>, <a href="#macos_spotlight_importer-platform_type">platform_type</a>, <a href="#macos_spotlight_importer-provisioning_profile">provisioning_profile</a>, <a href="#macos_spotlight_importer-resources">resources</a>, <a href="#macos_spotlight_importer-stamp">stamp</a>,
                         <a href="#macos_spotlight_importer-strings">strings</a>, <a href="#macos_spotlight_importer-version">version</a>)
</pre>

Builds and bundles a macOS Spotlight Importer.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="macos_spotlight_importer-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="macos_spotlight_importer-additional_contents"></a>additional_contents |  Files that should be copied into specific subdirectories of the Contents folder in the bundle. The keys of this dictionary are labels pointing to single files, filegroups, or targets; the corresponding value is the name of the subdirectory of Contents where they should be placed.<br><br>The relative directory structure of filegroup contents is preserved when they are copied into the desired Contents subdirectory.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: Label -> String</a> | optional | {} |
| <a id="macos_spotlight_importer-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_spotlight_importer-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target.   | String | required |  |
| <a id="macos_spotlight_importer-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="macos_spotlight_importer-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_spotlight_importer-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="macos_spotlight_importer-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_spotlight_importer-entitlements"></a>entitlements |  The entitlements file required for device builds of this target. If absent, the default entitlements from the provisioning profile will be used.<br><br>The following variables are substituted in the entitlements file: <code>$(CFBundleIdentifier)</code> with the bundle ID of the application and <code>$(AppIdentifierPrefix)</code> with the value of the <code>ApplicationIdentifierPrefix</code> key from the target's provisioning profile.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_spotlight_importer-entitlements_validation"></a>entitlements_validation |  An [<code>entitlements_validation_mode</code>](/doc/types.md#entitlements-validation-mode) to control the validation of the requested entitlements against the provisioning profile to ensure they are supported.   | String | optional | "loose" |
| <a id="macos_spotlight_importer-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="macos_spotlight_importer-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_spotlight_importer-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="macos_spotlight_importer-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_spotlight_importer-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="macos_spotlight_importer-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="macos_spotlight_importer-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="macos_spotlight_importer-platform_type"></a>platform_type |  -   | String | optional | "macos" |
| <a id="macos_spotlight_importer-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.provisionprofile</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_spotlight_importer-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_spotlight_importer-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="macos_spotlight_importer-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_spotlight_importer-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="#macos_ui_test"></a>

## macos_ui_test

<pre>
macos_ui_test(<a href="#macos_ui_test-name">name</a>, <a href="#macos_ui_test-data">data</a>, <a href="#macos_ui_test-deps">deps</a>, <a href="#macos_ui_test-env">env</a>, <a href="#macos_ui_test-platform_type">platform_type</a>, <a href="#macos_ui_test-runner">runner</a>, <a href="#macos_ui_test-test_host">test_host</a>)
</pre>

Builds and bundles an iOS UI `.xctest` test bundle. Runs the tests using the
provided test runner when invoked with `bazel test`. When using Tulsi to run
tests built with this target, `runner` will not be used since Xcode is the test
runner in that case.

Note: macOS UI tests are not currently supported in the default test runner.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="macos_ui_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="macos_ui_test-data"></a>data |  Files to be made available to the test during its execution.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_ui_test-deps"></a>deps |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="macos_ui_test-env"></a>env |  Dictionary of environment variables that should be set during the test execution.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="macos_ui_test-platform_type"></a>platform_type |  -   | String | optional | "macos" |
| <a id="macos_ui_test-runner"></a>runner |  The runner target that will provide the logic on how to run the tests. Needs to provide the AppleTestRunnerInfo provider.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="macos_ui_test-test_host"></a>test_host |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="#macos_unit_test"></a>

## macos_unit_test

<pre>
macos_unit_test(<a href="#macos_unit_test-name">name</a>, <a href="#macos_unit_test-data">data</a>, <a href="#macos_unit_test-deps">deps</a>, <a href="#macos_unit_test-env">env</a>, <a href="#macos_unit_test-platform_type">platform_type</a>, <a href="#macos_unit_test-runner">runner</a>, <a href="#macos_unit_test-test_host">test_host</a>)
</pre>

Builds and bundles a macOS unit `.xctest` test bundle. Runs the tests using the
provided test runner when invoked with `bazel test`. When using Tulsi to run
tests built with this target, `runner` will not be used since Xcode is the test
runner in that case.

`macos_unit_test` targets can work in two modes: as app or library tests. If the
`test_host` attribute is set to an `macos_application` target, the tests will
run within that application's context. If no `test_host` is provided, the tests
will run outside the context of an macOS application. Because of this, certain
functionalities might not be present (e.g. UI layout, NSUserDefaults). You can
find more information about testing for Apple platforms
[here](https://developer.apple.com/library/content/documentation/DeveloperTools/Conceptual/testing_with_xcode/chapters/03-testing_basics.html).

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="macos_unit_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="macos_unit_test-data"></a>data |  Files to be made available to the test during its execution.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_unit_test-deps"></a>deps |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="macos_unit_test-env"></a>env |  Dictionary of environment variables that should be set during the test execution.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="macos_unit_test-platform_type"></a>platform_type |  -   | String | optional | "macos" |
| <a id="macos_unit_test-runner"></a>runner |  The runner target that will provide the logic on how to run the tests. Needs to provide the AppleTestRunnerInfo provider.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="macos_unit_test-test_host"></a>test_host |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="#macos_xpc_service"></a>

## macos_xpc_service

<pre>
macos_xpc_service(<a href="#macos_xpc_service-name">name</a>, <a href="#macos_xpc_service-additional_contents">additional_contents</a>, <a href="#macos_xpc_service-additional_linker_inputs">additional_linker_inputs</a>, <a href="#macos_xpc_service-bundle_id">bundle_id</a>, <a href="#macos_xpc_service-bundle_name">bundle_name</a>,
                  <a href="#macos_xpc_service-codesign_inputs">codesign_inputs</a>, <a href="#macos_xpc_service-codesignopts">codesignopts</a>, <a href="#macos_xpc_service-deps">deps</a>, <a href="#macos_xpc_service-entitlements">entitlements</a>, <a href="#macos_xpc_service-entitlements_validation">entitlements_validation</a>,
                  <a href="#macos_xpc_service-executable_name">executable_name</a>, <a href="#macos_xpc_service-exported_symbols_lists">exported_symbols_lists</a>, <a href="#macos_xpc_service-infoplists">infoplists</a>, <a href="#macos_xpc_service-ipa_post_processor">ipa_post_processor</a>, <a href="#macos_xpc_service-linkopts">linkopts</a>,
                  <a href="#macos_xpc_service-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#macos_xpc_service-minimum_os_version">minimum_os_version</a>, <a href="#macos_xpc_service-platform_type">platform_type</a>,
                  <a href="#macos_xpc_service-provisioning_profile">provisioning_profile</a>, <a href="#macos_xpc_service-resources">resources</a>, <a href="#macos_xpc_service-stamp">stamp</a>, <a href="#macos_xpc_service-strings">strings</a>, <a href="#macos_xpc_service-version">version</a>)
</pre>

Builds and bundles a macOS XPC Service.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="macos_xpc_service-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="macos_xpc_service-additional_contents"></a>additional_contents |  Files that should be copied into specific subdirectories of the Contents folder in the bundle. The keys of this dictionary are labels pointing to single files, filegroups, or targets; the corresponding value is the name of the subdirectory of Contents where they should be placed.<br><br>The relative directory structure of filegroup contents is preserved when they are copied into the desired Contents subdirectory.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: Label -> String</a> | optional | {} |
| <a id="macos_xpc_service-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_xpc_service-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target.   | String | required |  |
| <a id="macos_xpc_service-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="macos_xpc_service-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by <code>codesign</code> (referenced with <code>codesignopts</code>).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_xpc_service-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to <code>codesign</code>.   | List of strings | optional | [] |
| <a id="macos_xpc_service-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_xpc_service-entitlements"></a>entitlements |  The entitlements file required for device builds of this target. If absent, the default entitlements from the provisioning profile will be used.<br><br>The following variables are substituted in the entitlements file: <code>$(CFBundleIdentifier)</code> with the bundle ID of the application and <code>$(AppIdentifierPrefix)</code> with the value of the <code>ApplicationIdentifierPrefix</code> key from the target's provisioning profile.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_xpc_service-entitlements_validation"></a>entitlements_validation |  An [<code>entitlements_validation_mode</code>](/doc/types.md#entitlements-validation-mode) to control the validation of the requested entitlements against the provisioning profile to ensure they are supported.   | String | optional | "loose" |
| <a id="macos_xpc_service-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | "" |
| <a id="macos_xpc_service-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_xpc_service-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="macos_xpc_service-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_xpc_service-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="macos_xpc_service-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="macos_xpc_service-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="macos_xpc_service-platform_type"></a>platform_type |  -   | String | optional | "macos" |
| <a id="macos_xpc_service-provisioning_profile"></a>provisioning_profile |  The provisioning profile (<code>.provisionprofile</code> file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="macos_xpc_service-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_xpc_service-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="macos_xpc_service-strings"></a>strings |  A list of <code>.strings</code> files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named <code>*.lproj</code>, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="macos_xpc_service-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


