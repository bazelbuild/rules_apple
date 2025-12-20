<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Rules for creating iOS Package Archive (.ipa).

<a id="apple_archive"></a>

## apple_archive

<pre>
load("@rules_apple//apple:apple_archive.bzl", "apple_archive")

apple_archive(<a href="#apple_archive-name">name</a>, <a href="#apple_archive-bundle">bundle</a>, <a href="#apple_archive-include_symbols">include_symbols</a>)
</pre>

Re-packages an Apple bundle into a .ipa.

This rule uses the providers from the bundle target to construct the required
metadata for the .ipa.

Example:

````starlark
load("//apple:apple_archive.bzl", "apple_archive")

ios_application(
    name = "App",
    bundle_id = "com.example.my.app",
    ...
)

apple_archive(
    name = "App.ipa",
    bundle = ":App",
)
````

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="apple_archive-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="apple_archive-bundle"></a>bundle |  The label to a target to re-package into a .ipa. For example, an `ios_application` target.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="apple_archive-include_symbols"></a>include_symbols |  If true, collects `$UUID.symbols` files from all `{binary: .dSYM, ...}` pairs for the application and its dependencies, then packages them under the `Symbols/` directory in the final .ipa.   | Boolean | optional |  `False`  |


