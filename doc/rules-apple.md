<!-- Generated with Stardoc, Do Not Edit! -->

# Rules that apply to all Apple platforms.
<a id="#apple_dynamic_framework_import"></a>

## apple_dynamic_framework_import

<pre>
apple_dynamic_framework_import(<a href="#apple_dynamic_framework_import-name">name</a>, <a href="#apple_dynamic_framework_import-bundle_only">bundle_only</a>, <a href="#apple_dynamic_framework_import-deps">deps</a>, <a href="#apple_dynamic_framework_import-dsym_imports">dsym_imports</a>, <a href="#apple_dynamic_framework_import-framework_imports">framework_imports</a>)
</pre>


This rule encapsulates an already-built dynamic framework. It is defined by a list of
files in exactly one `.framework` directory. `apple_dynamic_framework_import` targets
need to be added to library targets through the `deps` attribute.
### Examples

```python
apple_dynamic_framework_import(
    name = "my_dynamic_framework",
    framework_imports = glob(["my_dynamic_framework.framework/**"]),
)

objc_library(
    name = "foo_lib",
    ...,
    deps = [
        ":my_dynamic_framework",
    ],
)
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="apple_dynamic_framework_import-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="apple_dynamic_framework_import-bundle_only"></a>bundle_only |  Avoid linking the dynamic framework, but still include it in the app. This is useful when you want to manually dlopen the framework at runtime.   | Boolean | optional | False |
| <a id="apple_dynamic_framework_import-deps"></a>deps |  A list of targets that are dependencies of the target being built, which will be linked into that target.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="apple_dynamic_framework_import-dsym_imports"></a>dsym_imports |  The list of files under a .dSYM directory, that is the imported framework's dSYM bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="apple_dynamic_framework_import-framework_imports"></a>framework_imports |  The list of files under a .framework directory which are provided to Apple based targets that depend on this target.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |


<a id="#apple_dynamic_xcframework_import"></a>

## apple_dynamic_xcframework_import

<pre>
apple_dynamic_xcframework_import(<a href="#apple_dynamic_xcframework_import-name">name</a>, <a href="#apple_dynamic_xcframework_import-bundle_only">bundle_only</a>, <a href="#apple_dynamic_xcframework_import-deps">deps</a>, <a href="#apple_dynamic_xcframework_import-library_identifiers">library_identifiers</a>, <a href="#apple_dynamic_xcframework_import-xcframework_imports">xcframework_imports</a>)
</pre>


This rule encapsulates an already-built dynamic XCFramework. It is defined by a
list of files in exactly one `.xcframework` directory.
`apple_dynamic_xcframework_import` targets need to be added to library targets
through the `deps` attribute.

### Examples

```starlark
apple_dynamic_xcframework_import(
    name = "my_dynamic_xcframework",
    xcframework_imports = glob(["my_dynamic_framework.xcframework/**"]),
)

objc_library(
    name = "foo_lib",
    ...,
    deps = [
        ":my_dynamic_xcframework",
    ],
)
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="apple_dynamic_xcframework_import-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="apple_dynamic_xcframework_import-bundle_only"></a>bundle_only |  Avoid linking the dynamic XCFramework, but still include it in the app. This is useful when you want to manually dlopen the XCFramework at runtime.   | Boolean | optional | False |
| <a id="apple_dynamic_xcframework_import-deps"></a>deps |  A list of targets that are dependencies of the target being built, which will provide headers (if the importing XCFramework is a dynamic framework) and can be linked into that target.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="apple_dynamic_xcframework_import-library_identifiers"></a>library_identifiers |  An optional key-value map of platforms to the corresponding platform IDs (containing all supported architectures), relative to the XCFramework. The identifier keys should be case-insensitive variants of the values in [<code>apple_common.platform</code>](https://docs.bazel.build/versions/5.0.0/skylark/lib/apple_common.html#platform); for example, <code>ios_device</code> or <code>ios_simulator</code>. The identifier values should be case-sensitive variants of values that might be found in the <code>LibraryIdentifier</code> of an <code>Info.plist</code> file in the XCFramework's root; for example, <code>ios-arm64_i386_x86_64-simulator</code> or <code>ios-arm64_armv7</code>.<br><br>Passing this attribute should not be neccessary if the XCFramework follows the standard naming convention (that is, it was created by Xcode or Bazel).   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="apple_dynamic_xcframework_import-xcframework_imports"></a>xcframework_imports |  The list of files under a .xcframework directory which are provided to Apple based targets that depend on this target.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |


<a id="#apple_static_framework_import"></a>

## apple_static_framework_import

<pre>
apple_static_framework_import(<a href="#apple_static_framework_import-name">name</a>, <a href="#apple_static_framework_import-alwayslink">alwayslink</a>, <a href="#apple_static_framework_import-deps">deps</a>, <a href="#apple_static_framework_import-framework_imports">framework_imports</a>, <a href="#apple_static_framework_import-sdk_dylibs">sdk_dylibs</a>, <a href="#apple_static_framework_import-sdk_frameworks">sdk_frameworks</a>,
                              <a href="#apple_static_framework_import-weak_sdk_frameworks">weak_sdk_frameworks</a>)
</pre>


This rule encapsulates an already-built static framework. It is defined by a list of
files in exactly one `.framework` directory. `apple_static_framework_import` targets
need to be added to library targets through the `deps` attribute.
### Examples

```python
apple_static_framework_import(
    name = "my_static_framework",
    framework_imports = glob(["my_static_framework.framework/**"]),
)

objc_library(
    name = "foo_lib",
    ...,
    deps = [
        ":my_static_framework",
    ],
)
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="apple_static_framework_import-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="apple_static_framework_import-alwayslink"></a>alwayslink |  If true, any binary that depends (directly or indirectly) on this framework will link in all the object files for the framework file, even if some contain no symbols referenced by the binary. This is useful if your code isn't explicitly called by code in the binary; for example, if you rely on runtime checks for protocol conformances added in extensions in the library but do not directly reference any other symbols in the object file that adds that conformance.   | Boolean | optional | False |
| <a id="apple_static_framework_import-deps"></a>deps |  A list of targets that are dependencies of the target being built, which will provide headers and be linked into that target.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="apple_static_framework_import-framework_imports"></a>framework_imports |  The list of files under a .framework directory which are provided to Apple based targets that depend on this target.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="apple_static_framework_import-sdk_dylibs"></a>sdk_dylibs |  Names of SDK .dylib libraries to link with. For instance, <code>libz</code> or <code>libarchive</code>. <code>libc++</code> is included automatically if the binary has any C++ or Objective-C++ sources in its dependency tree. When linking a binary, all libraries named in that binary's transitive dependency graph are used.   | List of strings | optional | [] |
| <a id="apple_static_framework_import-sdk_frameworks"></a>sdk_frameworks |  Names of SDK frameworks to link with (e.g. <code>AddressBook</code>, <code>QuartzCore</code>). <code>UIKit</code> and <code>Foundation</code> are always included when building for the iOS, tvOS and watchOS platforms. For macOS, only <code>Foundation</code> is always included. When linking a top level binary, all SDK frameworks listed in that binary's transitive dependency graph are linked.   | List of strings | optional | [] |
| <a id="apple_static_framework_import-weak_sdk_frameworks"></a>weak_sdk_frameworks |  Names of SDK frameworks to weakly link with. For instance, <code>MediaAccessibility</code>. In difference to regularly linked SDK frameworks, symbols from weakly linked frameworks do not cause an error if they are not present at runtime.   | List of strings | optional | [] |


<a id="#apple_static_xcframework_import"></a>

## apple_static_xcframework_import

<pre>
apple_static_xcframework_import(<a href="#apple_static_xcframework_import-name">name</a>, <a href="#apple_static_xcframework_import-alwayslink">alwayslink</a>, <a href="#apple_static_xcframework_import-deps">deps</a>, <a href="#apple_static_xcframework_import-includes">includes</a>, <a href="#apple_static_xcframework_import-library_identifiers">library_identifiers</a>, <a href="#apple_static_xcframework_import-sdk_dylibs">sdk_dylibs</a>,
                                <a href="#apple_static_xcframework_import-sdk_frameworks">sdk_frameworks</a>, <a href="#apple_static_xcframework_import-weak_sdk_frameworks">weak_sdk_frameworks</a>, <a href="#apple_static_xcframework_import-xcframework_imports">xcframework_imports</a>)
</pre>


This rule encapsulates an already-built static XCFramework. It is defined by a
list of files in exactly one `.xcframework` directory.
`apple_static_xcframework_import` targets need to be added to library targets
through the `deps` attribute.

### Examples

```slarlark
apple_static_xcframework_import(
    name = "my_static_xcframework",
    xcframework_imports = glob(["my_static_framework.xcframework/**"]),
)

objc_library(
    name = "foo_lib",
    ...,
    deps = [
        ":my_static_xcframework",
    ],
)
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="apple_static_xcframework_import-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="apple_static_xcframework_import-alwayslink"></a>alwayslink |  If true, any binary that depends (directly or indirectly) on this framework will link in all the object files for the framework file, even if some contain no symbols referenced by the binary. This is useful if your code isn't explicitly called by code in the binary; for example, if you rely on runtime checks for protocol conformances added in extensions in the library but do not directly reference any other symbols in the object file that adds that conformance.   | Boolean | optional | False |
| <a id="apple_static_xcframework_import-deps"></a>deps |  A list of targets that are dependencies of the target being built, which will provide headers (if the importing XCFramework is a dynamic framework) and can be linked into that target.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="apple_static_xcframework_import-includes"></a>includes |  List of <code>#include/#import</code> search paths to add to this target and all depending targets.<br><br>The paths are interpreted relative to the single platform directory inside the XCFramework for the platform being built.<br><br>These flags are added for this rule and every rule that depends on it. (Note: not the rules it depends upon!) Be very careful, since this may have far-reaching effects.   | List of strings | optional | [] |
| <a id="apple_static_xcframework_import-library_identifiers"></a>library_identifiers |  An optional key-value map of platforms to the corresponding platform IDs (containing all supported architectures), relative to the XCFramework. The identifier keys should be case-insensitive variants of the values in [<code>apple_common.platform</code>](https://docs.bazel.build/versions/5.0.0/skylark/lib/apple_common.html#platform); for example, <code>ios_device</code> or <code>ios_simulator</code>. The identifier values should be case-sensitive variants of values that might be found in the <code>LibraryIdentifier</code> of an <code>Info.plist</code> file in the XCFramework's root; for example, <code>ios-arm64_i386_x86_64-simulator</code> or <code>ios-arm64_armv7</code>.<br><br>Passing this attribute should not be neccessary if the XCFramework follows the standard naming convention (that is, it was created by Xcode or Bazel).   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="apple_static_xcframework_import-sdk_dylibs"></a>sdk_dylibs |  Names of SDK .dylib libraries to link with. For instance, <code>libz</code> or <code>libarchive</code>. <code>libc++</code> is included automatically if the binary has any C++ or Objective-C++ sources in its dependency tree.  When linking a binary, all libraries named in that binary's transitive dependency graph are used.   | List of strings | optional | [] |
| <a id="apple_static_xcframework_import-sdk_frameworks"></a>sdk_frameworks |  Names of SDK frameworks to link with (e.g. <code>AddressBook</code>, <code>QuartzCore</code>). <code>UIKit</code> and <code>Foundation</code> are always included when building for the iOS, tvOS and watchOS platforms. For macOS, only <code>Foundation</code> is always included. When linking a top level binary, all SDK frameworks listed in that binary's transitive dependency graph are linked.   | List of strings | optional | [] |
| <a id="apple_static_xcframework_import-weak_sdk_frameworks"></a>weak_sdk_frameworks |  Names of SDK frameworks to weakly link with. For instance, <code>MediaAccessibility</code>. In difference to regularly linked SDK frameworks, symbols from weakly linked frameworks do not cause an error if they are not present at runtime.   | List of strings | optional | [] |
| <a id="apple_static_xcframework_import-xcframework_imports"></a>xcframework_imports |  The list of files under a .xcframework directory which are provided to Apple based targets that depend on this target.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |


<a id="#apple_universal_binary"></a>

## apple_universal_binary

<pre>
apple_universal_binary(<a href="#apple_universal_binary-name">name</a>, <a href="#apple_universal_binary-binary">binary</a>, <a href="#apple_universal_binary-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#apple_universal_binary-minimum_os_version">minimum_os_version</a>,
                       <a href="#apple_universal_binary-platform_type">platform_type</a>)
</pre>


This rule produces a multi-architecture ("fat") binary targeting Apple platforms.
The `lipo` tool is used to combine built binaries of multiple architectures.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="apple_universal_binary-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="apple_universal_binary-binary"></a>binary |  Target to generate a 'fat' binary from.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="apple_universal_binary-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | "" |
| <a id="apple_universal_binary-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "10.11").   | String | required |  |
| <a id="apple_universal_binary-platform_type"></a>platform_type |  The target Apple platform for which to create a binary. This dictates which SDK is used for compilation/linking and which flag is used to determine the architectures to target. For example, if <code>ios</code> is specified, then the output binaries/libraries will be created combining all architectures specified by <code>--ios_multi_cpus</code>. Options are:<br><br>*   <code>ios</code>: architectures gathered from <code>--ios_multi_cpus</code>. *   <code>macos</code>: architectures gathered from <code>--macos_cpus</code>. *   <code>tvos</code>: architectures gathered from <code>--tvos_cpus</code>. *   <code>watchos</code>: architectures gathered from <code>--watchos_cpus</code>.   | String | required |  |


<a id="#apple_xcframework"></a>

## apple_xcframework

<pre>
apple_xcframework(<a href="#apple_xcframework-name">name</a>, <a href="#apple_xcframework-bundle_id">bundle_id</a>, <a href="#apple_xcframework-bundle_name">bundle_name</a>, <a href="#apple_xcframework-data">data</a>, <a href="#apple_xcframework-deps">deps</a>, <a href="#apple_xcframework-exported_symbols_lists">exported_symbols_lists</a>,
                  <a href="#apple_xcframework-families_required">families_required</a>, <a href="#apple_xcframework-framework_type">framework_type</a>, <a href="#apple_xcframework-infoplists">infoplists</a>, <a href="#apple_xcframework-ios">ios</a>, <a href="#apple_xcframework-linkopts">linkopts</a>,
                  <a href="#apple_xcframework-minimum_deployment_os_versions">minimum_deployment_os_versions</a>, <a href="#apple_xcframework-minimum_os_versions">minimum_os_versions</a>, <a href="#apple_xcframework-public_hdrs">public_hdrs</a>, <a href="#apple_xcframework-stamp">stamp</a>, <a href="#apple_xcframework-version">version</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="apple_xcframework-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="apple_xcframework-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for each of the embedded frameworks. If present, this value will be embedded in an Info.plist within each framework bundle.   | String | optional | "" |
| <a id="apple_xcframework-bundle_name"></a>bundle_name |  The desired name of the xcframework bundle (without the extension) and the bundles for all embedded frameworks. If this attribute is not set, then the name of the target will be used instead.   | String | optional | "" |
| <a id="apple_xcframework-data"></a>data |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within each of the embedded framework bundles.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="apple_xcframework-deps"></a>deps |  A list of dependencies targets that will be linked into this each of the framework target's individual binaries. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the framework bundles.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="apple_xcframework-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="apple_xcframework-families_required"></a>families_required |  A list of device families supported by this extension, with platforms such as <code>ios</code> as keys. Valid values are <code>iphone</code> and <code>ipad</code> for <code>ios</code>; at least one must be specified if a platform is defined. Currently, this only affects processing of <code>ios</code> resources.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> List of strings</a> | optional | {} |
| <a id="apple_xcframework-framework_type"></a>framework_type |  Indicates what type of framework the output should be, if defined. Currently only <code>dynamic</code> is supported. If this is not given, the default is to have all contained frameworks built as dynamic frameworks.   | List of strings | optional | [] |
| <a id="apple_xcframework-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for each of the embedded frameworks. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="apple_xcframework-ios"></a>ios |  A dictionary of strings indicating which platform variants should be built for the <code>ios</code> platform ( <code>device</code> or <code>simulator</code>) as keys, and arrays of strings listing which architectures should be built for those platform variants (for example, <code>x86_64</code>, <code>arm64</code>) as their values.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> List of strings</a> | optional | {} |
| <a id="apple_xcframework-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | [] |
| <a id="apple_xcframework-minimum_deployment_os_versions"></a>minimum_deployment_os_versions |  A dictionary of strings indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0") as values, with their respective platforms such as <code>ios</code> as keys. This is different from <code>minimum_os_versions</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="apple_xcframework-minimum_os_versions"></a>minimum_os_versions |  A dictionary of strings indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "8.0") as values, with their respective platforms such as <code>ios</code> as keys.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | required |  |
| <a id="apple_xcframework-public_hdrs"></a>public_hdrs |  A list of files directly referencing header files to be used as the publicly visible interface for each of these embedded frameworks. These header files will be embedded within each bundle, typically in a subdirectory such as <code>Headers</code>.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="apple_xcframework-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binaries. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binaries. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | -1 |
| <a id="apple_xcframework-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


