<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Defines rules for building Apple DocC targets.

<a id="docc_archive"></a>

## docc_archive

<pre>
docc_archive(<a href="#docc_archive-name">name</a>, <a href="#docc_archive-default_code_listing_language">default_code_listing_language</a>, <a href="#docc_archive-dep">dep</a>, <a href="#docc_archive-diagnostic_level">diagnostic_level</a>, <a href="#docc_archive-enable_inherited_docs">enable_inherited_docs</a>,
             <a href="#docc_archive-fallback_bundle_identifier">fallback_bundle_identifier</a>, <a href="#docc_archive-fallback_bundle_version">fallback_bundle_version</a>, <a href="#docc_archive-fallback_display_name">fallback_display_name</a>, <a href="#docc_archive-kinds">kinds</a>,
             <a href="#docc_archive-transform_for_static_hosting">transform_for_static_hosting</a>)
</pre>

Builds a .doccarchive for the given dependency.
The target created by this rule can also be `run` to preview the generated documentation in Xcode.

NOTE: At this time Swift is the only supported language for this rule.

Example:

```python
load("@build_bazel_rules_apple//apple:docc.bzl", "docc_archive")

docc_archive(
    name = "Lib.doccarchive",
    dep = ":Lib",
    fallback_bundle_identifier = "com.example.lib",
    fallback_bundle_version = "1.0.0",
    fallback_display_name = "Lib",
)
```

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="docc_archive-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="docc_archive-default_code_listing_language"></a>default_code_listing_language |  A fallback default language for code listings if no value is provided in the documentation bundle's Info.plist file.   | String | optional |  `""`  |
| <a id="docc_archive-dep"></a>dep |  -   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="docc_archive-diagnostic_level"></a>diagnostic_level |  Filters diagnostics above this level from output This filter level is inclusive. If a level of `information` is specified, diagnostics with a severity up to and including `information` will be printed. Must be one of "error", "warning", "information", or "hint"   | String | optional |  `""`  |
| <a id="docc_archive-enable_inherited_docs"></a>enable_inherited_docs |  Inherit documentation for inherited symbols.   | Boolean | optional |  `False`  |
| <a id="docc_archive-fallback_bundle_identifier"></a>fallback_bundle_identifier |  A fallback bundle identifier if no value is provided in the documentation bundle's Info.plist file.   | String | required |  |
| <a id="docc_archive-fallback_bundle_version"></a>fallback_bundle_version |  A fallback bundle version if no value is provided in the documentation bundle's Info.plist file.   | String | required |  |
| <a id="docc_archive-fallback_display_name"></a>fallback_display_name |  A fallback display name if no value is provided in the documentation bundle's Info.plist file.   | String | required |  |
| <a id="docc_archive-kinds"></a>kinds |  The kinds of entities to filter generated documentation for.   | List of strings | optional |  `[]`  |
| <a id="docc_archive-transform_for_static_hosting"></a>transform_for_static_hosting |  -   | Boolean | optional |  `True`  |


