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


