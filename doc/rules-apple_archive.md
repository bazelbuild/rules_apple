<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Rules for creating Apple application archives.

<a id="apple_archive"></a>

## apple_archive

<pre>
load("@rules_apple//apple:apple_archive.bzl", "apple_archive")

apple_archive(<a href="#apple_archive-name">name</a>, <a href="#apple_archive-bundle">bundle</a>, <a href="#apple_archive-include_symbols">include_symbols</a>)
</pre>

Re-packages an Apple bundle into an Apple archive.

This rule uses the providers from the bundle target to construct the required
metadata for the archive. iOS/tvOS/visionOS/watchOS applications produce an
`.ipa`; macOS applications produce a `.zip`. The archive target preserves the
wrapped bundle target's debug providers and output groups so follow-on artifacts
such as dSYMs and linkmaps remain available from the archive target. In the
`AppleBundleInfo` propagated by this rule, `archive` points to the `.ipa` or
`.zip` file, while `archive_root` intentionally remains the wrapped bundle
target's unarchived bundle root for IDE consumers.

Example:

````starlark
load("@rules_apple//apple:apple_archive.bzl", "apple_archive")

ios_application(
    name = "App",
    bundle_id = "com.example.my.app",
    ...
)

apple_archive(
    name = "AppArchive",
    bundle = ":App",
)
````

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="apple_archive-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="apple_archive-bundle"></a>bundle |  The label to a target to re-package into an Apple archive. For example, an `ios_application` or `macos_application` target.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="apple_archive-include_symbols"></a>include_symbols |  If true, collects generated `$UUID.symbols` files from all `{binary: .dSYM, ...}` pairs for the application and its dependencies, then packages them under the `Symbols/` directory in the final archive. Symbol files are only available when dSYM generation is enabled, such as by passing `--apple_generate_dsym`.   | Boolean | optional |  `False`  |


