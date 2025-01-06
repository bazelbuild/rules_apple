<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Rule for creating a XCTRunner.app with one or more .xctest bundles.

<a id="xctrunner"></a>

## xctrunner

<pre>
xctrunner(<a href="#xctrunner-name">name</a>, <a href="#xctrunner-arch">arch</a>, <a href="#xctrunner-platform">platform</a>, <a href="#xctrunner-test_targets">test_targets</a>, <a href="#xctrunner-zip">zip</a>)
</pre>

Packages one or more .xctest bundles into a XCTRunner.app.

Note: Tests inside must be qualified with the test target
name as `testTargetName/testClass/testCase` for device farm builds.

Example:

````starlark
load("//apple:xctrunner.bzl", "xctrunner")

ios_ui_test(
    name = "HelloWorldSwiftUITests",
    minimum_os_version = "15.0",
    runner = "@build_bazel_rules_apple//apple/testing/default_runner:ios_xctestrun_ordered_runner",
    test_host = ":HelloWorldSwift",
    deps = [":UITests"],
)

xctrunner(
    name = "HelloWorldSwiftXCTRunner",
    test_targets = [":HelloWorldSwiftUITests"],
    testonly = True,
)
````

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="xctrunner-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="xctrunner-arch"></a>arch |  List of architectures to bundle for. Default: arm64   | String | optional |  `"arm64"`  |
| <a id="xctrunner-platform"></a>platform |  Platform to bundle for. Default: iPhoneOS.platform   | String | optional |  `"iPhoneOS.platform"`  |
| <a id="xctrunner-test_targets"></a>test_targets |  List of test targets to include.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="xctrunner-zip"></a>zip |  Whether to zip the resulting bundle.   | Boolean | optional |  `False`  |


