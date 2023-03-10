<!-- Generated with Stardoc: http://skydoc.bazel.build -->

# Rules that apply to all Apple platforms.

<a id="apple_dynamic_framework_import"></a>

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
| <a id="apple_dynamic_framework_import-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="apple_dynamic_framework_import-bundle_only"></a>bundle_only |  Avoid linking the dynamic framework, but still include it in the app. This is useful when you want to manually dlopen the framework at runtime.   | Boolean | optional | <code>False</code> |
| <a id="apple_dynamic_framework_import-deps"></a>deps |  A list of targets that are dependencies of the target being built, which will be linked into that target.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="apple_dynamic_framework_import-dsym_imports"></a>dsym_imports |  The list of files under a .dSYM directory, that is the imported framework's dSYM bundle.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="apple_dynamic_framework_import-framework_imports"></a>framework_imports |  The list of files under a .framework directory which are provided to Apple based targets that depend on this target.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |


<a id="apple_dynamic_xcframework_import"></a>

## apple_dynamic_xcframework_import

<pre>
apple_dynamic_xcframework_import(<a href="#apple_dynamic_xcframework_import-name">name</a>, <a href="#apple_dynamic_xcframework_import-bundle_only">bundle_only</a>, <a href="#apple_dynamic_xcframework_import-deps">deps</a>, <a href="#apple_dynamic_xcframework_import-library_identifiers">library_identifiers</a>, <a href="#apple_dynamic_xcframework_import-xcframework_imports">xcframework_imports</a>)
</pre>


This rule encapsulates an already-built XCFramework. Defined by a list of files in a .xcframework
directory. apple_xcframework_import targets need to be added as dependencies to library targets
through the `deps` attribute.

### Example

```bzl
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
| <a id="apple_dynamic_xcframework_import-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="apple_dynamic_xcframework_import-bundle_only"></a>bundle_only |  Avoid linking the dynamic framework, but still include it in the app. This is useful when you want to manually dlopen the framework at runtime.   | Boolean | optional | <code>False</code> |
| <a id="apple_dynamic_xcframework_import-deps"></a>deps |  List of targets that are dependencies of the target being built, which will provide headers and be linked into that target.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="apple_dynamic_xcframework_import-library_identifiers"></a>library_identifiers |  Unnecssary and ignored, will be removed in the future.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional | <code>{}</code> |
| <a id="apple_dynamic_xcframework_import-xcframework_imports"></a>xcframework_imports |  List of files under a .xcframework directory which are provided to Apple based targets that depend on this target.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |


<a id="apple_static_framework_import"></a>

## apple_static_framework_import

<pre>
apple_static_framework_import(<a href="#apple_static_framework_import-name">name</a>, <a href="#apple_static_framework_import-alwayslink">alwayslink</a>, <a href="#apple_static_framework_import-data">data</a>, <a href="#apple_static_framework_import-deps">deps</a>, <a href="#apple_static_framework_import-framework_imports">framework_imports</a>, <a href="#apple_static_framework_import-has_swift">has_swift</a>,
                              <a href="#apple_static_framework_import-sdk_dylibs">sdk_dylibs</a>, <a href="#apple_static_framework_import-sdk_frameworks">sdk_frameworks</a>, <a href="#apple_static_framework_import-weak_sdk_frameworks">weak_sdk_frameworks</a>)
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
| <a id="apple_static_framework_import-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="apple_static_framework_import-alwayslink"></a>alwayslink |  If true, any binary that depends (directly or indirectly) on this framework will link in all the object files for the framework file, even if some contain no symbols referenced by the binary. This is useful if your code isn't explicitly called by code in the binary; for example, if you rely on runtime checks for protocol conformances added in extensions in the library but do not directly reference any other symbols in the object file that adds that conformance.   | Boolean | optional | <code>False</code> |
| <a id="apple_static_framework_import-data"></a>data |  List of files needed by this target at runtime.<br><br>Files and targets named in the <code>data</code> attribute will appear in the <code>*.runfiles</code> area of this target, if it has one. This may include data files needed by a binary or library, or other programs needed by it.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="apple_static_framework_import-deps"></a>deps |  A list of targets that are dependencies of the target being built, which will provide headers and be linked into that target.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="apple_static_framework_import-framework_imports"></a>framework_imports |  The list of files under a .framework directory which are provided to Apple based targets that depend on this target.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="apple_static_framework_import-has_swift"></a>has_swift |  A boolean indicating if the target has Swift source code. This helps flag frameworks that do not include Swift interface files but require linking the Swift libraries.   | Boolean | optional | <code>False</code> |
| <a id="apple_static_framework_import-sdk_dylibs"></a>sdk_dylibs |  Names of SDK .dylib libraries to link with. For instance, <code>libz</code> or <code>libarchive</code>. <code>libc++</code> is included automatically if the binary has any C++ or Objective-C++ sources in its dependency tree. When linking a binary, all libraries named in that binary's transitive dependency graph are used.   | List of strings | optional | <code>[]</code> |
| <a id="apple_static_framework_import-sdk_frameworks"></a>sdk_frameworks |  Names of SDK frameworks to link with (e.g. <code>AddressBook</code>, <code>QuartzCore</code>). <code>UIKit</code> and <code>Foundation</code> are always included when building for the iOS, tvOS and watchOS platforms. For macOS, only <code>Foundation</code> is always included. When linking a top level binary, all SDK frameworks listed in that binary's transitive dependency graph are linked.   | List of strings | optional | <code>[]</code> |
| <a id="apple_static_framework_import-weak_sdk_frameworks"></a>weak_sdk_frameworks |  Names of SDK frameworks to weakly link with. For instance, <code>MediaAccessibility</code>. In difference to regularly linked SDK frameworks, symbols from weakly linked frameworks do not cause an error if they are not present at runtime.   | List of strings | optional | <code>[]</code> |


<a id="apple_static_library"></a>

## apple_static_library

<pre>
apple_static_library(<a href="#apple_static_library-name">name</a>, <a href="#apple_static_library-additional_linker_inputs">additional_linker_inputs</a>, <a href="#apple_static_library-avoid_deps">avoid_deps</a>, <a href="#apple_static_library-data">data</a>, <a href="#apple_static_library-deps">deps</a>, <a href="#apple_static_library-linkopts">linkopts</a>,
                     <a href="#apple_static_library-minimum_os_version">minimum_os_version</a>, <a href="#apple_static_library-platform_type">platform_type</a>, <a href="#apple_static_library-sdk_dylibs">sdk_dylibs</a>, <a href="#apple_static_library-sdk_frameworks">sdk_frameworks</a>,
                     <a href="#apple_static_library-weak_sdk_frameworks">weak_sdk_frameworks</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="apple_static_library-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="apple_static_library-additional_linker_inputs"></a>additional_linker_inputs |  A list of input files to be passed to the linker.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="apple_static_library-avoid_deps"></a>avoid_deps |  A list of library targets on which this framework depends in order to compile, but the transitive closure of which will not be linked into the framework's binary.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="apple_static_library-data"></a>data |  Files to be made available to the library archive upon execution.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="apple_static_library-deps"></a>deps |  A list of dependencies targets that will be linked into this target's binary. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the final bundle.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="apple_static_library-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | <code>[]</code> |
| <a id="apple_static_library-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "9.0").   | String | required |  |
| <a id="apple_static_library-platform_type"></a>platform_type |  The target Apple platform for which to create a binary. This dictates which SDK is used for compilation/linking and which flag is used to determine the architectures to target. For example, if <code>ios</code> is specified, then the output binaries/libraries will be created combining all architectures specified by <code>--ios_multi_cpus</code>. Options are:<br><br>*   <code>ios</code>: architectures gathered from <code>--ios_multi_cpus</code>. *   <code>macos</code>: architectures gathered from <code>--macos_cpus</code>. *   <code>tvos</code>: architectures gathered from <code>--tvos_cpus</code>. *   <code>watchos</code>: architectures gathered from <code>--watchos_cpus</code>.   | String | required |  |
| <a id="apple_static_library-sdk_dylibs"></a>sdk_dylibs |  Names of SDK <code>.dylib</code> libraries to link with (e.g., <code>libz</code> or <code>libarchive</code>). <code>libc++</code> is included automatically if the binary has any C++ or Objective-C++ sources in its dependency tree. When linking a binary, all libraries named in that binary's transitive dependency graph are used.   | List of strings | optional | <code>[]</code> |
| <a id="apple_static_library-sdk_frameworks"></a>sdk_frameworks |  Names of SDK frameworks to link with (e.g., <code>AddressBook</code>, <code>QuartzCore</code>). <code>UIKit</code> and <code>Foundation</code> are always included, even if this attribute is provided and does not list them.<br><br>This attribute is discouraged; in general, targets should list system framework dependencies in the library targets where that framework is used, not in the top-level bundle.   | List of strings | optional | <code>[]</code> |
| <a id="apple_static_library-weak_sdk_frameworks"></a>weak_sdk_frameworks |  Names of SDK frameworks to weakly link with (e.g., <code>MediaAccessibility</code>). Unlike regularly linked SDK frameworks, symbols from weakly linked frameworks do not cause the binary to fail to load if they are not present in the version of the framework available at runtime.<br><br>This attribute is discouraged; in general, targets should list system framework dependencies in the library targets where that framework is used, not in the top-level bundle.   | List of strings | optional | <code>[]</code> |


<a id="apple_static_xcframework"></a>

## apple_static_xcframework

<pre>
apple_static_xcframework(<a href="#apple_static_xcframework-name">name</a>, <a href="#apple_static_xcframework-avoid_deps">avoid_deps</a>, <a href="#apple_static_xcframework-bundle_name">bundle_name</a>, <a href="#apple_static_xcframework-deps">deps</a>, <a href="#apple_static_xcframework-executable_name">executable_name</a>, <a href="#apple_static_xcframework-families_required">families_required</a>,
                         <a href="#apple_static_xcframework-ios">ios</a>, <a href="#apple_static_xcframework-minimum_deployment_os_versions">minimum_deployment_os_versions</a>, <a href="#apple_static_xcframework-minimum_os_versions">minimum_os_versions</a>, <a href="#apple_static_xcframework-public_hdrs">public_hdrs</a>,
                         <a href="#apple_static_xcframework-umbrella_header">umbrella_header</a>)
</pre>

Generates an XCFramework with static libraries for third-party distribution.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="apple_static_xcframework-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="apple_static_xcframework-avoid_deps"></a>avoid_deps |  A list of library targets on which this framework depends in order to compile, but the transitive closure of which will not be linked into the framework's binary.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="apple_static_xcframework-bundle_name"></a>bundle_name |  The desired name of the XCFramework bundle (without the extension) and the binaries for all embedded static libraries. If this attribute is not set, then the name of the target will be used instead.   | String | optional | <code>""</code> |
| <a id="apple_static_xcframework-deps"></a>deps |  A list of files directly referencing libraries to be represented for each given platform split in the XCFramework. These libraries will be embedded within each platform split.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="apple_static_xcframework-executable_name"></a>executable_name |  The desired name of the executable, if the bundle has an executable. If this attribute is not set, then the name of the <code>bundle_name</code> attribute will be used if it is set; if not, then the name of the target will be used instead.   | String | optional | <code>""</code> |
| <a id="apple_static_xcframework-families_required"></a>families_required |  A list of device families supported by this extension, with platforms such as <code>ios</code> as keys. Valid values are <code>iphone</code> and <code>ipad</code> for <code>ios</code>; at least one must be specified if a platform is defined. Currently, this only affects processing of <code>ios</code> resources.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> List of strings</a> | optional | <code>{}</code> |
| <a id="apple_static_xcframework-ios"></a>ios |  A dictionary of strings indicating which platform variants should be built for the <code>ios</code> platform ( <code>device</code> or <code>simulator</code>) as keys, and arrays of strings listing which architectures should be built for those platform variants (for example, <code>x86_64</code>, <code>arm64</code>) as their values.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> List of strings</a> | optional | <code>{}</code> |
| <a id="apple_static_xcframework-minimum_deployment_os_versions"></a>minimum_deployment_os_versions |  A dictionary of strings indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0") as values, with their respective platforms such as <code>ios</code> as keys. This is different from <code>minimum_os_versions</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional | <code>{}</code> |
| <a id="apple_static_xcframework-minimum_os_versions"></a>minimum_os_versions |  A dictionary of strings indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "8.0") as values, with their respective platforms such as <code>ios</code> as keys.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | required |  |
| <a id="apple_static_xcframework-public_hdrs"></a>public_hdrs |  A list of files directly referencing header files to be used as the publicly visible interface for each of these embedded libraries. These header files will be embedded within each platform split, typically in a subdirectory such as <code>Headers</code>.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="apple_static_xcframework-umbrella_header"></a>umbrella_header |  An optional single .h file to use as the umbrella header for this framework. Usually, this header will have the same name as this target, so that clients can load the header using the #import &lt;MyFramework/MyFramework.h&gt; format. If this attribute is not specified (the common use case), an umbrella header will be generated under the same name as this target.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | <code>None</code> |


<a id="apple_static_xcframework_import"></a>

## apple_static_xcframework_import

<pre>
apple_static_xcframework_import(<a href="#apple_static_xcframework_import-name">name</a>, <a href="#apple_static_xcframework_import-alwayslink">alwayslink</a>, <a href="#apple_static_xcframework_import-data">data</a>, <a href="#apple_static_xcframework_import-deps">deps</a>, <a href="#apple_static_xcframework_import-has_swift">has_swift</a>, <a href="#apple_static_xcframework_import-includes">includes</a>,
                                <a href="#apple_static_xcframework_import-library_identifiers">library_identifiers</a>, <a href="#apple_static_xcframework_import-linkopts">linkopts</a>, <a href="#apple_static_xcframework_import-sdk_dylibs">sdk_dylibs</a>, <a href="#apple_static_xcframework_import-sdk_frameworks">sdk_frameworks</a>,
                                <a href="#apple_static_xcframework_import-weak_sdk_frameworks">weak_sdk_frameworks</a>, <a href="#apple_static_xcframework_import-xcframework_imports">xcframework_imports</a>)
</pre>


This rule encapsulates an already-built XCFramework with static libraries. Defined by a list of
files in a .xcframework directory. apple_xcframework_import targets need to be added as dependencies
to library targets through the `deps` attribute.
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
| <a id="apple_static_xcframework_import-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="apple_static_xcframework_import-alwayslink"></a>alwayslink |  If true, any binary that depends (directly or indirectly) on this XCFramework will link in all the object files for the XCFramework bundle, even if some contain no symbols referenced by the binary. This is useful if your code isn't explicitly called by code in the binary; for example, if you rely on runtime checks for protocol conformances added in extensions in the library but do not directly reference any other symbols in the object file that adds that conformance.   | Boolean | optional | <code>False</code> |
| <a id="apple_static_xcframework_import-data"></a>data |  List of files needed by this target at runtime.<br><br>Files and targets named in the <code>data</code> attribute will appear in the <code>*.runfiles</code> area of this target, if it has one. This may include data files needed by a binary or library, or other programs needed by it.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="apple_static_xcframework_import-deps"></a>deps |  List of targets that are dependencies of the target being built, which will provide headers and be linked into that target.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="apple_static_xcframework_import-has_swift"></a>has_swift |  A boolean indicating if the target has Swift source code. This helps flag XCFrameworks that do not include Swift interface files.   | Boolean | optional | <code>False</code> |
| <a id="apple_static_xcframework_import-includes"></a>includes |  List of <code>#include/#import</code> search paths to add to this target and all depending targets.<br><br>The paths are interpreted relative to the single platform directory inside the XCFramework for the platform being built.<br><br>These flags are added for this rule and every rule that depends on it. (Note: not the rules it depends upon!) Be very careful, since this may have far-reaching effects.   | List of strings | optional | <code>[]</code> |
| <a id="apple_static_xcframework_import-library_identifiers"></a>library_identifiers |  Unnecssary and ignored, will be removed in the future.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional | <code>{}</code> |
| <a id="apple_static_xcframework_import-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | <code>[]</code> |
| <a id="apple_static_xcframework_import-sdk_dylibs"></a>sdk_dylibs |  Names of SDK .dylib libraries to link with. For instance, <code>libz</code> or <code>libarchive</code>. <code>libc++</code> is included automatically if the binary has any C++ or Objective-C++ sources in its dependency tree. When linking a binary, all libraries named in that binary's transitive dependency graph are used.   | List of strings | optional | <code>[]</code> |
| <a id="apple_static_xcframework_import-sdk_frameworks"></a>sdk_frameworks |  Names of SDK frameworks to link with (e.g. <code>AddressBook</code>, <code>QuartzCore</code>). <code>UIKit</code> and <code>Foundation</code> are always included when building for the iOS, tvOS and watchOS platforms. For macOS, only <code>Foundation</code> is always included. When linking a top level binary, all SDK frameworks listed in that binary's transitive dependency graph are linked.   | List of strings | optional | <code>[]</code> |
| <a id="apple_static_xcframework_import-weak_sdk_frameworks"></a>weak_sdk_frameworks |  Names of SDK frameworks to weakly link with. For instance, <code>MediaAccessibility</code>. In difference to regularly linked SDK frameworks, symbols from weakly linked frameworks do not cause an error if they are not present at runtime.   | List of strings | optional | <code>[]</code> |
| <a id="apple_static_xcframework_import-xcframework_imports"></a>xcframework_imports |  List of files under a .xcframework directory which are provided to Apple based targets that depend on this target.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |


<a id="apple_universal_binary"></a>

## apple_universal_binary

<pre>
apple_universal_binary(<a href="#apple_universal_binary-name">name</a>, <a href="#apple_universal_binary-binary">binary</a>, <a href="#apple_universal_binary-forced_cpus">forced_cpus</a>, <a href="#apple_universal_binary-minimum_deployment_os_version">minimum_deployment_os_version</a>, <a href="#apple_universal_binary-minimum_os_version">minimum_os_version</a>,
                       <a href="#apple_universal_binary-platform_type">platform_type</a>)
</pre>


This rule produces a multi-architecture ("fat") binary targeting Apple platforms.
The `lipo` tool is used to combine built binaries of multiple architectures.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="apple_universal_binary-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="apple_universal_binary-binary"></a>binary |  Target to generate a 'fat' binary from.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="apple_universal_binary-forced_cpus"></a>forced_cpus |  An optional list of target CPUs for which the universal binary should be built.<br><br>If this attribute is present, the value of the platform-specific CPU flag (<code>--ios_multi_cpus</code>, <code>--macos_cpus</code>, <code>--tvos_cpus</code>, or <code>--watchos_cpus</code>) will be ignored and the binary will be built for all of the specified architectures instead.<br><br>This is primarily useful to force macOS tools to be built as universal binaries using <code>forced_cpus = ["x86_64", "arm64"]</code>, without requiring the user to pass additional flags when invoking Bazel.   | List of strings | optional | <code>[]</code> |
| <a id="apple_universal_binary-minimum_deployment_os_version"></a>minimum_deployment_os_version |  A required string indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0"). This is different from <code>minimum_os_version</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | String | optional | <code>""</code> |
| <a id="apple_universal_binary-minimum_os_version"></a>minimum_os_version |  A required string indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "10.11").   | String | required |  |
| <a id="apple_universal_binary-platform_type"></a>platform_type |  The target Apple platform for which to create a binary. This dictates which SDK is used for compilation/linking and which flag is used to determine the architectures to target. For example, if <code>ios</code> is specified, then the output binaries/libraries will be created combining all architectures specified by <code>--ios_multi_cpus</code>. Options are:<br><br>*   <code>ios</code>: architectures gathered from <code>--ios_multi_cpus</code>. *   <code>macos</code>: architectures gathered from <code>--macos_cpus</code>. *   <code>tvos</code>: architectures gathered from <code>--tvos_cpus</code>. *   <code>watchos</code>: architectures gathered from <code>--watchos_cpus</code>.   | String | required |  |


<a id="apple_xcframework"></a>

## apple_xcframework

<pre>
apple_xcframework(<a href="#apple_xcframework-name">name</a>, <a href="#apple_xcframework-bundle_id">bundle_id</a>, <a href="#apple_xcframework-bundle_name">bundle_name</a>, <a href="#apple_xcframework-data">data</a>, <a href="#apple_xcframework-deps">deps</a>, <a href="#apple_xcframework-exported_symbols_lists">exported_symbols_lists</a>,
                  <a href="#apple_xcframework-families_required">families_required</a>, <a href="#apple_xcframework-infoplists">infoplists</a>, <a href="#apple_xcframework-ios">ios</a>, <a href="#apple_xcframework-linkopts">linkopts</a>, <a href="#apple_xcframework-minimum_deployment_os_versions">minimum_deployment_os_versions</a>,
                  <a href="#apple_xcframework-minimum_os_versions">minimum_os_versions</a>, <a href="#apple_xcframework-public_hdrs">public_hdrs</a>, <a href="#apple_xcframework-stamp">stamp</a>, <a href="#apple_xcframework-umbrella_header">umbrella_header</a>, <a href="#apple_xcframework-version">version</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="apple_xcframework-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="apple_xcframework-bundle_id"></a>bundle_id |  The bundle ID (reverse-DNS path followed by app name) for each of the embedded frameworks. If present, this value will be embedded in an Info.plist within each framework bundle.   | String | required |  |
| <a id="apple_xcframework-bundle_name"></a>bundle_name |  The desired name of the xcframework bundle (without the extension) and the bundles for all embedded frameworks. If this attribute is not set, then the name of the target will be used instead.   | String | optional | <code>""</code> |
| <a id="apple_xcframework-data"></a>data |  A list of resources or files bundled with the bundle. The resources will be stored in the appropriate resources location within each of the embedded framework bundles.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="apple_xcframework-deps"></a>deps |  A list of dependencies targets that will be linked into this each of the framework target's individual binaries. Any resources, such as asset catalogs, that are referenced by those targets will also be transitively included in the framework bundles.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="apple_xcframework-exported_symbols_lists"></a>exported_symbols_lists |  A list of targets containing exported symbols lists files for the linker to control symbol resolution.<br><br>Each file is expected to have a list of global symbol names that will remain as global symbols in the compiled binary owned by this framework. All other global symbols will be treated as if they were marked as <code>__private_extern__</code> (aka <code>visibility=hidden</code>) and will not be global in the output file.<br><br>See the man page documentation for <code>ld(1)</code> on macOS for more details.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="apple_xcframework-families_required"></a>families_required |  A list of device families supported by this extension, with platforms such as <code>ios</code> as keys. Valid values are <code>iphone</code> and <code>ipad</code> for <code>ios</code>; at least one must be specified if a platform is defined. Currently, this only affects processing of <code>ios</code> resources.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> List of strings</a> | optional | <code>{}</code> |
| <a id="apple_xcframework-infoplists"></a>infoplists |  A list of .plist files that will be merged to form the Info.plist for each of the embedded frameworks. At least one file must be specified. Please see [Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling) for what is supported.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="apple_xcframework-ios"></a>ios |  A dictionary of strings indicating which platform variants should be built for the <code>ios</code> platform ( <code>device</code> or <code>simulator</code>) as keys, and arrays of strings listing which architectures should be built for those platform variants (for example, <code>x86_64</code>, <code>arm64</code>) as their values.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> List of strings</a> | optional | <code>{}</code> |
| <a id="apple_xcframework-linkopts"></a>linkopts |  A list of strings representing extra flags that should be passed to the linker.   | List of strings | optional | <code>[]</code> |
| <a id="apple_xcframework-minimum_deployment_os_versions"></a>minimum_deployment_os_versions |  A dictionary of strings indicating the minimum deployment OS version supported by the target, represented as a dotted version number (for example, "9.0") as values, with their respective platforms such as <code>ios</code> as keys. This is different from <code>minimum_os_versions</code>, which is effective at compile time. Ensure version specific APIs are guarded with <code>available</code> clauses.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional | <code>{}</code> |
| <a id="apple_xcframework-minimum_os_versions"></a>minimum_os_versions |  A dictionary of strings indicating the minimum OS version supported by the target, represented as a dotted version number (for example, "8.0") as values, with their respective platforms such as <code>ios</code> as keys.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | required |  |
| <a id="apple_xcframework-public_hdrs"></a>public_hdrs |  A list of files directly referencing header files to be used as the publicly visible interface for each of these embedded frameworks. These header files will be embedded within each bundle, typically in a subdirectory such as <code>Headers</code>.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="apple_xcframework-stamp"></a>stamp |  Enable link stamping. Whether to encode build information into the binaries. Possible values:<br><br>*   <code>stamp = 1</code>: Stamp the build information into the binaries. Stamped binaries are only rebuilt     when their dependencies change. Use this if there are tests that depend on the build     information. *   <code>stamp = 0</code>: Always replace build information by constant values. This gives good build     result caching. *   <code>stamp = -1</code>: Embedding of build information is controlled by the <code>--[no]stamp</code> flag.   | Integer | optional | <code>-1</code> |
| <a id="apple_xcframework-umbrella_header"></a>umbrella_header |  An optional single .h file to use as the umbrella header for this framework. Usually, this header will have the same name as this target, so that clients can load the header using the #import &lt;MyFramework/MyFramework.h&gt; format. If this attribute is not specified (the common use case), an umbrella header will be generated under the same name as this target.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | <code>None</code> |
| <a id="apple_xcframework-version"></a>version |  An <code>apple_bundle_version</code> target that represents the version for this target. See [<code>apple_bundle_version</code>](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-versioning.md#apple_bundle_version).   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | <code>None</code> |


<a id="local_provisioning_profile"></a>

## local_provisioning_profile

<pre>
local_provisioning_profile(<a href="#local_provisioning_profile-name">name</a>, <a href="#local_provisioning_profile-profile_name">profile_name</a>, <a href="#local_provisioning_profile-team_id">team_id</a>)
</pre>


This rule declares a bazel target that you can pass to the
'provisioning_profile' attribute of rules that require it. It discovers a
provisioning profile for the given attributes either on the user's local
machine, or with the optional 'fallback_profiles' passed to
'provisioning_profile_repository'. This will automatically pick the newest
profile if there are multiple profiles matching the given criteria. By default
this rule will search for a profile with the same name as the rule itself, you
can pass profile_name to use a different name, and you can pass team_id if
you'd like to disambiguate between 2 Apple developer accounts that have the
same profile name.

## Example

```starlark
load("@build_bazel_rules_apple//apple:apple.bzl", "local_provisioning_profile")

local_provisioning_profile(
    name = "app_debug_profile",
    profile_name = "Development App",
    team_id = "abc123",
)

ios_application(
    name = "app",
    ...
    provisioning_profile = ":app_debug_profile",
)

local_provisioning_profile(
    name = "app_release_profile",
)

ios_application(
    name = "release_app",
    ...
    provisioning_profile = ":app_release_profile",
)
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="local_provisioning_profile-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="local_provisioning_profile-profile_name"></a>profile_name |  Name of the profile to use, if it's not provided the name of the rule is used   | String | optional | <code>""</code> |
| <a id="local_provisioning_profile-team_id"></a>team_id |  Team ID of the profile to find. This is useful for disambiguating between multiple profiles with the same name on different developer accounts.   | String | optional | <code>""</code> |


<a id="provisioning_profile_repository"></a>

## provisioning_profile_repository

<pre>
provisioning_profile_repository(<a href="#provisioning_profile_repository-name">name</a>, <a href="#provisioning_profile_repository-fallback_profiles">fallback_profiles</a>, <a href="#provisioning_profile_repository-repo_mapping">repo_mapping</a>)
</pre>


This rule declares an external repository for discovering locally installed
provisioning profiles. This is consumed by `local_provisioning_profile`.
You can optionally set 'fallback_profiles' to point at a stable location of
profiles if a newer version of the desired profile does not exist on the local
machine. This is useful for checking in the current version of the profile, but
not having to update it every time a new device or certificate is added.

## Example

### In your `MODULE.bazel` file:

You only need this in the case you want to setup fallback profiles, otherwise
it can be ommitted when using bzlmod.

```bzl
provisioning_profile_repository = use_extension("@build_bazel_rules_apple//apple:apple.bzl", "provisioning_profile_repository_extension")
provisioning_profile_repository.setup(
    fallback_profiles = "//path/to/some:filegroup", # Profiles to use if one isn't found locally
)
```

### In your `WORKSPACE` file:

```starlark
load("@build_bazel_rules_apple//apple:apple.bzl", "provisioning_profile_repository")

provisioning_profile_repository(
    name = "local_provisioning_profiles",
    fallback_profiles = "//path/to/some:filegroup", # Optional profiles to use if one isn't found locally
)
```

### In your `BUILD` files (see `local_provisioning_profile` for more examples):

```starlark
load("@build_bazel_rules_apple//apple:apple.bzl", "local_provisioning_profile")

local_provisioning_profile(
    name = "app_debug_profile",
    profile_name = "Development App",
    team_id = "abc123",
)

ios_application(
    name = "app",
    ...
    provisioning_profile = ":app_debug_profile",
)
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="provisioning_profile_repository-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="provisioning_profile_repository-fallback_profiles"></a>fallback_profiles |  -   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | <code>None</code> |
| <a id="provisioning_profile_repository-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | required |  |


<a id="experimental_mixed_language_library"></a>

## experimental_mixed_language_library

<pre>
experimental_mixed_language_library(<a href="#experimental_mixed_language_library-name">name</a>, <a href="#experimental_mixed_language_library-srcs">srcs</a>, <a href="#experimental_mixed_language_library-deps">deps</a>, <a href="#experimental_mixed_language_library-module_name">module_name</a>, <a href="#experimental_mixed_language_library-objc_copts">objc_copts</a>, <a href="#experimental_mixed_language_library-swift_copts">swift_copts</a>,
                                    <a href="#experimental_mixed_language_library-swiftc_inputs">swiftc_inputs</a>, <a href="#experimental_mixed_language_library-kwargs">kwargs</a>)
</pre>

Compiles and links Objective-C and Swift code into a static library.

This is an experimental macro that supports compiling mixed Objective-C and
Swift source files into a static library.

Due to the build performance reason, in general it's not recommended to
have mixed Objective-C and Swift modules, but it isn't uncommon to see
mixed language modules in some old codebases. This macro is meant to make
it easier to migrate codebases with mixed language modules to Bazel without
having to demix them first.

This macro only supports a very simple use case of mixed language
modules---it does not support for header maps or Clang modules.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="experimental_mixed_language_library-name"></a>name |  A unique name for this target.   |  none |
| <a id="experimental_mixed_language_library-srcs"></a>srcs |  The list of Objective-C and Swift source files to compile.   |  none |
| <a id="experimental_mixed_language_library-deps"></a>deps |  A list of targets that are dependencies of the target being built, which will be linked into that target.   |  <code>[]</code> |
| <a id="experimental_mixed_language_library-module_name"></a>module_name |  The name of the mixed language module being built. If left unspecified, the module name will be the name of the target.   |  <code>None</code> |
| <a id="experimental_mixed_language_library-objc_copts"></a>objc_copts |  Additional compiler options that should be passed to <code>clang</code>.   |  <code>[]</code> |
| <a id="experimental_mixed_language_library-swift_copts"></a>swift_copts |  Additional compiler options that should be passed to <code>swiftc</code>. These strings are subject to <code>$(location ...)</code> and "Make" variable expansion.   |  <code>[]</code> |
| <a id="experimental_mixed_language_library-swiftc_inputs"></a>swiftc_inputs |  Additional files that are referenced using <code>$(location...)</code> in <code>swift_copts</code>.   |  <code>[]</code> |
| <a id="experimental_mixed_language_library-kwargs"></a>kwargs |  Other arguments to pass through to the underlying <code>objc_library</code>.   |  none |


