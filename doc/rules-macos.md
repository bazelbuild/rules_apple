<!-- Generated with Stardoc: http://skydoc.bazel.build -->

# Bazel rules for creating macOS applications and bundles.

<a id="macos_build_test"></a>

## macos_build_test

<pre>
load("@rules_apple//apple:macos.bzl", "macos_build_test")

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
| <a id="macos_build_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="macos_build_test-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version that will be used as the deployment target when building the targets, represented as a dotted version number (for example, `"9.0"`).   | String | required |  |
| <a id="macos_build_test-platform_type"></a>platform_type |  -   | String | optional |  `"macos"`  |
| <a id="macos_build_test-targets"></a>targets |  The targets to check for successful build.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


<a id="macos_quick_look_plugin"></a>

## macos_quick_look_plugin

<pre>
load("@rules_apple//apple:macos.bzl", "macos_quick_look_plugin")

macos_quick_look_plugin(<a href="#macos_quick_look_plugin-name">name</a>, <a href="#macos_quick_look_plugin-deps">deps</a>, <a href="#macos_quick_look_plugin-resources">resources</a>, <a href="#macos_quick_look_plugin-additional_contents">additional_contents</a>, <a href="#macos_quick_look_plugin-additional_linker_inputs">additional_linker_inputs</a>,
                        <a href="#macos_quick_look_plugin-bundle_id">bundle_id</a>, <a href="#macos_quick_look_plugin-bundle_id_suffix">bundle_id_suffix</a>, <a href="#macos_quick_look_plugin-bundle_name">bundle_name</a>, <a href="#macos_quick_look_plugin-codesign_inputs">codesign_inputs</a>, <a href="#macos_quick_look_plugin-codesignopts">codesignopts</a>,
                        <a href="#macos_quick_look_plugin-entitlements">entitlements</a>, <a href="#macos_quick_look_plugin-entitlements_validation">entitlements_validation</a>, <a href="#macos_quick_look_plugin-executable_name">executable_name</a>,
                        <a href="#macos_quick_look_plugin-exported_symbols_lists">exported_symbols_lists</a>, <a href="#macos_quick_look_plugin-families">families</a>, <a href="#macos_quick_look_plugin-infoplists">infoplists</a>, <a href="#macos_quick_look_plugin-ipa_post_processor">ipa_post_processor</a>, <a href="#macos_quick_look_plugin-linkopts">linkopts</a>,
                        <a href="#macos_quick_look_plugin-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#macos_quick_look_plugin-minimum_os_version">minimum_os_version</a>, <a href="#macos_quick_look_plugin-platform_type">platform_type</a>,
                        <a href="#macos_quick_look_plugin-provisioning_profile">provisioning_profile</a>, <a href="#macos_quick_look_plugin-shared_capabilities">shared_capabilities</a>, <a href="#macos_quick_look_plugin-stamp">stamp</a>, <a href="#macos_quick_look_plugin-strings">strings</a>, <a href="#macos_quick_look_plugin-version">version</a>)
</pre>

Builds and bundles a macOS Quick Look Plugin.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="macos_quick_look_plugin-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="macos_quick_look_plugin-deps"></a>deps |  A list of dependent targets that will be linked into this target's binary(s). Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle(s).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="macos_quick_look_plugin-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="macos_quick_look_plugin-additional_contents"></a>additional_contents |  Files that should be copied into specific subdirectories of the Contents folder in the bundle. The keys of this dictionary are labels pointing to single files, filegroups, or targets; the corresponding value is the name of the subdirectory of Contents where they should be placed.<br><br>The relative directory structure of filegroup contents is preserved when they are copied into the desired Contents subdirectory.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: Label -> String</a> | optional |  `{}`  |
| <a id="macos_quick_look_plugin-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="macos_quick_look_plugin-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target. Only use this attribute if the bundle ID is not intended to be composed through an assigned base bundle ID rule found within `signed_capabilities`.   | String | optional |  `""`  |
| <a id="macos_quick_look_plugin-bundle_id_suffix"></a>bundle_id_suffix |  A string to act as the suffix of the composed bundle ID. If this target's bundle ID is composed from a base bundle ID rule found within `signed_capabilities`, then this string will be appended to the end of the bundle ID following a "." separator.   | String | optional |  `"_"`  |
| <a id="macos_quick_look_plugin-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional |  `""`  |
| <a id="macos_quick_look_plugin-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by `codesign` (referenced with `codesignopts`).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="macos_quick_look_plugin-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to `codesign`.   | List of strings | optional |  `[]`  |
| <a id="macos_quick_look_plugin-entitlements"></a>entitlements |  The entitlements file required for device builds of this target. If absent, the default entitlements from the provisioning profile will be used.<br><br>The following variables are substituted in the entitlements file: `$(CFBundleIdentifier)` with the bundle ID of the application and `$(AppIdentifierPrefix)` with the value of the `ApplicationIdentifierPrefix` key from the target's provisioning profile.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="macos_quick_look_plugin-entitlements_validation"></a>entitlements_validation |  An `entitlements_validation_mode` to control the validation of the requested entitlements against the provisioning profile to ensure they are supported.   | String | optional |  `"loose"`  |
| <a id="macos_quick_look_plugin-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the `bundle_name` attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional |  `""`  |
| <a id="macos_quick_look_plugin-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as `__private_extern__` (aka `visibility=hidden`) and will not be global in the output file.<br><br>See the man page documentation for `ld(1)` on macOS for more details.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="macos_quick_look_plugin-families"></a>families |  A list of device families supported by this rule. At least one must be specified.   | List of strings | optional |  `["mac"]`  |
| <a id="macos_quick_look_plugin-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="macos_quick_look_plugin-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="macos_quick_look_plugin-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional |  `[]`  |
| <a id="macos_quick_look_plugin-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from `minimum_os_version`, which is effective at compile time. Ensure version specific APIs are guarded with `available` clauses.   | String | optional |  `""`  |
| <a id="macos_quick_look_plugin-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="macos_quick_look_plugin-platform_type"></a>platform_type |  -   | String | optional |  `"macos"`  |
| <a id="macos_quick_look_plugin-provisioning_profile"></a>provisioning_profile |  The provisioning profile (`.provisionprofile` file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="macos_quick_look_plugin-shared_capabilities"></a>shared_capabilities |  A list of shared `apple_capability_set` rules to represent the capabilities that a code sign aware Apple bundle rule output should have. These can define the formal prefix for the target's `bundle_id` and can further be merged with information provided by `entitlements`, if defined by any capabilities found within the `apple_capability_set`.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="macos_quick_look_plugin-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   `stamp = 1`: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   `stamp = 0`: Always replace build information by constant values. This gives good build     result caching. *   `stamp = -1`: Embedding of build information is controlled by the `--[no]stamp` flag.   | Integer | optional |  `-1`  |
| <a id="macos_quick_look_plugin-strings"></a>strings |  A list of `.strings` files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named `*.lproj`, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="macos_quick_look_plugin-version"></a>version |  An `apple_bundle_version` target that represents the version for this target. See [`apple_bundle_version`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |


<a id="macos_spotlight_importer"></a>

## macos_spotlight_importer

<pre>
load("@rules_apple//apple:macos.bzl", "macos_spotlight_importer")

macos_spotlight_importer(<a href="#macos_spotlight_importer-name">name</a>, <a href="#macos_spotlight_importer-deps">deps</a>, <a href="#macos_spotlight_importer-resources">resources</a>, <a href="#macos_spotlight_importer-additional_contents">additional_contents</a>, <a href="#macos_spotlight_importer-additional_linker_inputs">additional_linker_inputs</a>,
                         <a href="#macos_spotlight_importer-bundle_id">bundle_id</a>, <a href="#macos_spotlight_importer-bundle_id_suffix">bundle_id_suffix</a>, <a href="#macos_spotlight_importer-bundle_name">bundle_name</a>, <a href="#macos_spotlight_importer-codesign_inputs">codesign_inputs</a>, <a href="#macos_spotlight_importer-codesignopts">codesignopts</a>,
                         <a href="#macos_spotlight_importer-entitlements">entitlements</a>, <a href="#macos_spotlight_importer-entitlements_validation">entitlements_validation</a>, <a href="#macos_spotlight_importer-executable_name">executable_name</a>,
                         <a href="#macos_spotlight_importer-exported_symbols_lists">exported_symbols_lists</a>, <a href="#macos_spotlight_importer-families">families</a>, <a href="#macos_spotlight_importer-infoplists">infoplists</a>, <a href="#macos_spotlight_importer-ipa_post_processor">ipa_post_processor</a>, <a href="#macos_spotlight_importer-linkopts">linkopts</a>,
                         <a href="#macos_spotlight_importer-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#macos_spotlight_importer-minimum_os_version">minimum_os_version</a>, <a href="#macos_spotlight_importer-platform_type">platform_type</a>,
                         <a href="#macos_spotlight_importer-provisioning_profile">provisioning_profile</a>, <a href="#macos_spotlight_importer-shared_capabilities">shared_capabilities</a>, <a href="#macos_spotlight_importer-stamp">stamp</a>, <a href="#macos_spotlight_importer-strings">strings</a>, <a href="#macos_spotlight_importer-version">version</a>)
</pre>

Builds and bundles a macOS Spotlight Importer.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="macos_spotlight_importer-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="macos_spotlight_importer-deps"></a>deps |  A list of dependent targets that will be linked into this target's binary(s). Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle(s).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="macos_spotlight_importer-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="macos_spotlight_importer-additional_contents"></a>additional_contents |  Files that should be copied into specific subdirectories of the Contents folder in the bundle. The keys of this dictionary are labels pointing to single files, filegroups, or targets; the corresponding value is the name of the subdirectory of Contents where they should be placed.<br><br>The relative directory structure of filegroup contents is preserved when they are copied into the desired Contents subdirectory.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: Label -> String</a> | optional |  `{}`  |
| <a id="macos_spotlight_importer-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="macos_spotlight_importer-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target. Only use this attribute if the bundle ID is not intended to be composed through an assigned base bundle ID rule found within `signed_capabilities`.   | String | optional |  `""`  |
| <a id="macos_spotlight_importer-bundle_id_suffix"></a>bundle_id_suffix |  A string to act as the suffix of the composed bundle ID. If this target's bundle ID is composed from a base bundle ID rule found within `signed_capabilities`, then this string will be appended to the end of the bundle ID following a "." separator.   | String | optional |  `"_"`  |
| <a id="macos_spotlight_importer-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional |  `""`  |
| <a id="macos_spotlight_importer-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by `codesign` (referenced with `codesignopts`).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="macos_spotlight_importer-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to `codesign`.   | List of strings | optional |  `[]`  |
| <a id="macos_spotlight_importer-entitlements"></a>entitlements |  The entitlements file required for device builds of this target. If absent, the default entitlements from the provisioning profile will be used.<br><br>The following variables are substituted in the entitlements file: `$(CFBundleIdentifier)` with the bundle ID of the application and `$(AppIdentifierPrefix)` with the value of the `ApplicationIdentifierPrefix` key from the target's provisioning profile.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="macos_spotlight_importer-entitlements_validation"></a>entitlements_validation |  An `entitlements_validation_mode` to control the validation of the requested entitlements against the provisioning profile to ensure they are supported.   | String | optional |  `"loose"`  |
| <a id="macos_spotlight_importer-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the `bundle_name` attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional |  `""`  |
| <a id="macos_spotlight_importer-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as `__private_extern__` (aka `visibility=hidden`) and will not be global in the output file.<br><br>See the man page documentation for `ld(1)` on macOS for more details.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="macos_spotlight_importer-families"></a>families |  A list of device families supported by this rule. At least one must be specified.   | List of strings | optional |  `["mac"]`  |
| <a id="macos_spotlight_importer-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="macos_spotlight_importer-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="macos_spotlight_importer-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional |  `[]`  |
| <a id="macos_spotlight_importer-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from `minimum_os_version`, which is effective at compile time. Ensure version specific APIs are guarded with `available` clauses.   | String | optional |  `""`  |
| <a id="macos_spotlight_importer-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="macos_spotlight_importer-platform_type"></a>platform_type |  -   | String | optional |  `"macos"`  |
| <a id="macos_spotlight_importer-provisioning_profile"></a>provisioning_profile |  The provisioning profile (`.provisionprofile` file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="macos_spotlight_importer-shared_capabilities"></a>shared_capabilities |  A list of shared `apple_capability_set` rules to represent the capabilities that a code sign aware Apple bundle rule output should have. These can define the formal prefix for the target's `bundle_id` and can further be merged with information provided by `entitlements`, if defined by any capabilities found within the `apple_capability_set`.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="macos_spotlight_importer-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   `stamp = 1`: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   `stamp = 0`: Always replace build information by constant values. This gives good build     result caching. *   `stamp = -1`: Embedding of build information is controlled by the `--[no]stamp` flag.   | Integer | optional |  `-1`  |
| <a id="macos_spotlight_importer-strings"></a>strings |  A list of `.strings` files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named `*.lproj`, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="macos_spotlight_importer-version"></a>version |  An `apple_bundle_version` target that represents the version for this target. See [`apple_bundle_version`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |


<a id="macos_xpc_service"></a>

## macos_xpc_service

<pre>
load("@rules_apple//apple:macos.bzl", "macos_xpc_service")

macos_xpc_service(<a href="#macos_xpc_service-name">name</a>, <a href="#macos_xpc_service-deps">deps</a>, <a href="#macos_xpc_service-resources">resources</a>, <a href="#macos_xpc_service-additional_contents">additional_contents</a>, <a href="#macos_xpc_service-additional_linker_inputs">additional_linker_inputs</a>, <a href="#macos_xpc_service-bundle_id">bundle_id</a>,
                  <a href="#macos_xpc_service-bundle_id_suffix">bundle_id_suffix</a>, <a href="#macos_xpc_service-bundle_name">bundle_name</a>, <a href="#macos_xpc_service-codesign_inputs">codesign_inputs</a>, <a href="#macos_xpc_service-codesignopts">codesignopts</a>, <a href="#macos_xpc_service-entitlements">entitlements</a>,
                  <a href="#macos_xpc_service-entitlements_validation">entitlements_validation</a>, <a href="#macos_xpc_service-executable_name">executable_name</a>, <a href="#macos_xpc_service-exported_symbols_lists">exported_symbols_lists</a>, <a href="#macos_xpc_service-families">families</a>,
                  <a href="#macos_xpc_service-infoplists">infoplists</a>, <a href="#macos_xpc_service-ipa_post_processor">ipa_post_processor</a>, <a href="#macos_xpc_service-linkopts">linkopts</a>, <a href="#macos_xpc_service-minimum_deployment_os_version">minimum_deployment_os_version</a>,
                  <a href="#macos_xpc_service-minimum_os_version">minimum_os_version</a>, <a href="#macos_xpc_service-platform_type">platform_type</a>, <a href="#macos_xpc_service-provisioning_profile">provisioning_profile</a>, <a href="#macos_xpc_service-shared_capabilities">shared_capabilities</a>, <a href="#macos_xpc_service-stamp">stamp</a>,
                  <a href="#macos_xpc_service-strings">strings</a>, <a href="#macos_xpc_service-version">version</a>)
</pre>

Builds and bundles a macOS XPC Service.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="macos_xpc_service-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="macos_xpc_service-deps"></a>deps |  A list of dependent targets that will be linked into this target's binary(s). Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle(s).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="macos_xpc_service-resources"></a>resources |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within the bundle.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="macos_xpc_service-additional_contents"></a>additional_contents |  Files that should be copied into specific subdirectories of the Contents folder in the bundle. The keys of this dictionary are labels pointing to single files, filegroups, or targets; the corresponding value is the name of the subdirectory of Contents where they should be placed.<br><br>The relative directory structure of filegroup contents is preserved when they are copied into the desired Contents subdirectory.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: Label -> String</a> | optional |  `{}`  |
| <a id="macos_xpc_service-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="macos_xpc_service-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for this target. Only use this attribute if the bundle ID is not intended to be composed through an assigned base bundle ID rule found within `signed_capabilities`.   | String | optional |  `""`  |
| <a id="macos_xpc_service-bundle_id_suffix"></a>bundle_id_suffix |  A string to act as the suffix of the composed bundle ID. If this target's bundle ID is composed from a base bundle ID rule found within `signed_capabilities`, then this string will be appended to the end of the bundle ID following a "." separator.   | String | optional |  `"_"`  |
| <a id="macos_xpc_service-bundle_name"></a>bundle_name |  The desired name of the bundle (without the extension). If this attribute is not set, then the name of the target will be used instead.   | String | optional |  `""`  |
| <a id="macos_xpc_service-codesign_inputs"></a>codesign_inputs |  A list of dependencies targets that provide inputs that will be used by `codesign` (referenced with `codesignopts`).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="macos_xpc_service-codesignopts"></a>codesignopts |  A list of strings representing extra flags that should be passed to `codesign`.   | List of strings | optional |  `[]`  |
| <a id="macos_xpc_service-entitlements"></a>entitlements |  The entitlements file required for device builds of this target. If absent, the default entitlements from the provisioning profile will be used.<br><br>The following variables are substituted in the entitlements file: `$(CFBundleIdentifier)` with the bundle ID of the application and `$(AppIdentifierPrefix)` with the value of the `ApplicationIdentifierPrefix` key from the target's provisioning profile.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="macos_xpc_service-entitlements_validation"></a>entitlements_validation |  An `entitlements_validation_mode` to control the validation of the requested entitlements against the provisioning profile to ensure they are supported.   | String | optional |  `"loose"`  |
| <a id="macos_xpc_service-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the `bundle_name` attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional |  `""`  |
| <a id="macos_xpc_service-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as `__private_extern__` (aka `visibility=hidden`) and will not be global in the output file.<br><br>See the man page documentation for `ld(1)` on macOS for more details.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="macos_xpc_service-families"></a>families |  A list of device families supported by this rule. At least one must be specified.   | List of strings | optional |  `["mac"]`  |
| <a id="macos_xpc_service-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for this target. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="macos_xpc_service-ipa_post_processor"></a>ipa_post_processor |  A tool that edits this target's archive after it is assembled but before it is signed. The tool is invoked with a single command-line argument that denotes the path to a directory containing the unzipped contents of the archive; this target's bundle will be the directory's only contents.<br><br>Any changes made by the tool must be made in this directory, and the tool's execution must be hermetic given these inputs to ensure that the result can be safely cached.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="macos_xpc_service-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional |  `[]`  |
| <a id="macos_xpc_service-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from `minimum_os_version`, which is effective at compile time. Ensure version specific APIs are guarded with `available` clauses.   | String | optional |  `""`  |
| <a id="macos_xpc_service-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="macos_xpc_service-platform_type"></a>platform_type |  -   | String | optional |  `"macos"`  |
| <a id="macos_xpc_service-provisioning_profile"></a>provisioning_profile |  The provisioning profile (`.provisionprofile` file) to use when creating the bundle. This value is optional for simulator builds as the simulator doesn't fully enforce entitlements, but is required for device builds.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="macos_xpc_service-shared_capabilities"></a>shared_capabilities |  A list of shared `apple_capability_set` rules to represent the capabilities that a code sign aware Apple bundle rule output should have. These can define the formal prefix for the target's `bundle_id` and can further be merged with information provided by `entitlements`, if defined by any capabilities found within the `apple_capability_set`.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="macos_xpc_service-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binary. Possible values:<br><br>*   `stamp = 1`: Stamp the build information into the binary. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   `stamp = 0`: Always replace build information by constant values. This gives good build     result caching. *   `stamp = -1`: Embedding of build information is controlled by the `--[no]stamp` flag.   | Integer | optional |  `-1`  |
| <a id="macos_xpc_service-strings"></a>strings |  A list of `.strings` files, often localizable. These files are converted to binary plists (if they are not already) and placed in the root of the final bundle, unless a file's immediate containing directory is named `*.lproj`, in which case it will be placed under a directory with the same name in the bundle.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="macos_xpc_service-version"></a>version |  An `apple_bundle_version` target that represents the version for this target. See [`apple_bundle_version`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |


<a id="macos_application"></a>

## macos_application

<pre>
load("@rules_apple//apple:macos.bzl", "macos_application")

macos_application(<a href="#macos_application-name">name</a>, <a href="#macos_application-kwargs">kwargs</a>)
</pre>

Packages a macOS application.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="macos_application-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="macos_application-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


<a id="macos_bundle"></a>

## macos_bundle

<pre>
load("@rules_apple//apple:macos.bzl", "macos_bundle")

macos_bundle(<a href="#macos_bundle-name">name</a>, <a href="#macos_bundle-kwargs">kwargs</a>)
</pre>

Packages a macOS loadable bundle.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="macos_bundle-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="macos_bundle-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


<a id="macos_command_line_application"></a>

## macos_command_line_application

<pre>
load("@rules_apple//apple:macos.bzl", "macos_command_line_application")

macos_command_line_application(<a href="#macos_command_line_application-name">name</a>, <a href="#macos_command_line_application-kwargs">kwargs</a>)
</pre>

Builds a macOS command line application.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="macos_command_line_application-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="macos_command_line_application-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


<a id="macos_dylib"></a>

## macos_dylib

<pre>
load("@rules_apple//apple:macos.bzl", "macos_dylib")

macos_dylib(<a href="#macos_dylib-name">name</a>, <a href="#macos_dylib-kwargs">kwargs</a>)
</pre>

Builds a macOS dylib.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="macos_dylib-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="macos_dylib-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


<a id="macos_dynamic_framework"></a>

## macos_dynamic_framework

<pre>
load("@rules_apple//apple:macos.bzl", "macos_dynamic_framework")

macos_dynamic_framework(<a href="#macos_dynamic_framework-name">name</a>, <a href="#macos_dynamic_framework-kwargs">kwargs</a>)
</pre>

Packages a macOS framework.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="macos_dynamic_framework-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="macos_dynamic_framework-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


<a id="macos_extension"></a>

## macos_extension

<pre>
load("@rules_apple//apple:macos.bzl", "macos_extension")

macos_extension(<a href="#macos_extension-name">name</a>, <a href="#macos_extension-kwargs">kwargs</a>)
</pre>

Packages a macOS Extension Bundle.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="macos_extension-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="macos_extension-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


<a id="macos_framework"></a>

## macos_framework

<pre>
load("@rules_apple//apple:macos.bzl", "macos_framework")

macos_framework(<a href="#macos_framework-name">name</a>, <a href="#macos_framework-kwargs">kwargs</a>)
</pre>

Packages a macOS framework.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="macos_framework-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="macos_framework-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


<a id="macos_kernel_extension"></a>

## macos_kernel_extension

<pre>
load("@rules_apple//apple:macos.bzl", "macos_kernel_extension")

macos_kernel_extension(<a href="#macos_kernel_extension-name">name</a>, <a href="#macos_kernel_extension-kwargs">kwargs</a>)
</pre>

Packages a macOS Kernel Extension.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="macos_kernel_extension-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="macos_kernel_extension-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


<a id="macos_static_framework"></a>

## macos_static_framework

<pre>
load("@rules_apple//apple:macos.bzl", "macos_static_framework")

macos_static_framework(<a href="#macos_static_framework-name">name</a>, <a href="#macos_static_framework-kwargs">kwargs</a>)
</pre>

Packages a macOS framework.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="macos_static_framework-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="macos_static_framework-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


<a id="macos_ui_test"></a>

## macos_ui_test

<pre>
load("@rules_apple//apple:macos.bzl", "macos_ui_test")

macos_ui_test(<a href="#macos_ui_test-name">name</a>, <a href="#macos_ui_test-kwargs">kwargs</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="macos_ui_test-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="macos_ui_test-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


<a id="macos_unit_test"></a>

## macos_unit_test

<pre>
load("@rules_apple//apple:macos.bzl", "macos_unit_test")

macos_unit_test(<a href="#macos_unit_test-name">name</a>, <a href="#macos_unit_test-kwargs">kwargs</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="macos_unit_test-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="macos_unit_test-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


