<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Rules related to Apple linker.

<a id="apple_exported_symbols_list"></a>

## apple_exported_symbols_list

<pre>
load("@rules_apple//apple:linker.bzl", "apple_exported_symbols_list")

apple_exported_symbols_list(<a href="#apple_exported_symbols_list-name">name</a>, <a href="#apple_exported_symbols_list-deps">deps</a>, <a href="#apple_exported_symbols_list-additional_exported_symbols_lists">additional_exported_symbols_lists</a>, <a href="#apple_exported_symbols_list-clients">clients</a>, <a href="#apple_exported_symbols_list-nm">nm</a>,
                            <a href="#apple_exported_symbols_list-preserve_all_non_swift_exports">preserve_all_non_swift_exports</a>)
</pre>

Derives the exported-symbol list for a closed-world, app-private framework.

The rule keeps definitions referenced by the declared client link graphs. By
default it also keeps every non-Swift definition because Objective-C runtime
lookup and `dlsym` do not necessarily leave static undefined references. That
conservative policy can pull otherwise-unreferenced archive members into the
framework; set `preserve_all_non_swift_exports = False` only after auditing
runtime lookup and listing its roots in `additional_exported_symbols_lists`.
Authored roots are validated independently for each architecture, and the
`report` output group on this target lists selected policy buckets and missing
entries.

```starlark
apple_exported_symbols_list(
    name = "private_framework_exports",
    deps = [":private_framework_lib"],
    clients = [
        ":app_binary_lib",
        ":extension_binary_lib",
    ],
)

ios_framework(
    name = "PrivateFramework",
    deps = [":private_framework_lib"],
    exported_symbols_lists = [":private_framework_exports"],
    ...
)
```

Bazel cannot discover reverse dependencies, so `clients` must name the complete
set explicitly. Do not use a client-derived list for a public framework: its
current consumers are not a stable public ABI contract.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="apple_exported_symbols_list-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="apple_exported_symbols_list-deps"></a>deps |  The same library roots linked into the private framework. Their transitive static definitions are the maximum possible export surface.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="apple_exported_symbols_list-additional_exported_symbols_lists"></a>additional_exported_symbols_lists |  Optional authored symbol lists for runtime-discovered entry points that do not appear as undefined symbols in `clients`. Entries are retained only when that architecture's framework inputs define them; missing entries are listed in the `report` output group on this target.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="apple_exported_symbols_list-clients"></a>clients |  The complete set of application and extension link roots that may load the framework. Pass library or binary targets that provide `CcInfo`, not bundle targets that embed the framework, to avoid a dependency cycle.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="apple_exported_symbols_list-nm"></a>nm |  Optional `llvm-nm` executable. By default the selected Xcode's `llvm-nm` is used through `xcrun`. Override this when the link inputs come from another LLVM toolchain, especially when they contain LLVM bitcode.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="apple_exported_symbols_list-preserve_all_non_swift_exports"></a>preserve_all_non_swift_exports |  Whether to retain every non-Swift definition conservatively for Objective-C runtime and `dlsym` lookup. This can pull otherwise-unreferenced archive members into the framework. Set this to `False` only when all runtime-discovered entry points are absent or listed in `additional_exported_symbols_lists`.   | Boolean | optional |  `True`  |


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


