<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Rules related to Apple linker.

<a id="apple_order_file"></a>

## apple_order_file

<pre>
load("@rules_apple//apple:linker.bzl", "apple_order_file")

apple_order_file(<a href="#apple_order_file-name">name</a>, <a href="#apple_order_file-deps">deps</a>, <a href="#apple_order_file-stats">stats</a>)
</pre>

Injects the provided `.order` files into Apple link lines, concatenating and deduplicating them before supplying the appropriate linker flags.
The rule short-circuits in non-optimized compilations because generating order files is intended for release/deployment builds where they improve runtime locality.

Example:

```starlark
apple_order_file(
    name = "app_order_file",
    deps = [
        "my_file.order",
        "my_second_order_file.order",
    ],
)

ios_application(
    name = "app",
    deps = [":app_order_file"],
)
```

Set `stats = True` if you want the linker to emit information about how it used the order file.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="apple_order_file-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="apple_order_file-deps"></a>deps |  The raw text order files to be used in the iOS application.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="apple_order_file-stats"></a>stats |  Indicate whether to log stats about how the linker used the order file.   | Boolean | optional |  `False`  |


