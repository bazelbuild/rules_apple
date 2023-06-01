<!-- Generated with Stardoc: http://skydoc.bazel.build -->


Rules for creating Xcode archives.


<a id="xcarchive"></a>

## xcarchive

<pre>
xcarchive(<a href="#xcarchive-name">name</a>, <a href="#xcarchive-bundle">bundle</a>)
</pre>

Re-packages an Apple bundle into a .xcarchive.

This rule uses the providers from the bundle target to construct the required
metadata for the .xcarchive.

Example:

````starlark
load("@build_bazel_rules_apple//apple:xcarchive.bzl", "xcarchive")

ios_application(
    name = "App",
    bundle_id = "com.example.my.app",
    ...
)

xcarchive(
    name = "App.xcarchive",
    bundle = ":App",
)
````
    

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="xcarchive-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="xcarchive-bundle"></a>bundle |  The label to a target to re-package into a .xcarchive. For example, an <code>ios_application</code> target.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | <code>None</code> |


