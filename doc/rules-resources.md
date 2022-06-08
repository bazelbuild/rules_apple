<!-- Generated with Stardoc: http://skydoc.bazel.build -->

# Rules related to Apple resources and resource bundles.

<a id="apple_bundle_import"></a>

## apple_bundle_import

<pre>
apple_bundle_import(<a href="#apple_bundle_import-name">name</a>, <a href="#apple_bundle_import-bundle_imports">bundle_imports</a>)
</pre>


This rule encapsulates an already-built bundle. It is defined by a list of files
in exactly one `.bundle` directory. `apple_bundle_import` targets need to be
added to library targets through the `data` attribute, or to other resource
targets (i.e. `apple_resource_bundle` and `apple_resource_group`) through the
`resources` attribute.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="apple_bundle_import-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="apple_bundle_import-bundle_imports"></a>bundle_imports |  The list of files under a <code>.bundle</code> directory to be propagated to the top-level bundling target.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |


<a id="apple_core_data_model"></a>

## apple_core_data_model

<pre>
apple_core_data_model(<a href="#apple_core_data_model-name">name</a>, <a href="#apple_core_data_model-srcs">srcs</a>, <a href="#apple_core_data_model-swift_version">swift_version</a>)
</pre>


This rule takes a Core Data model definition from a .xcdatamodeld bundle
and generates Swift or Objective-C source files that can be added as a
dependency to a swift_library target.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="apple_core_data_model-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="apple_core_data_model-srcs"></a>srcs |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="apple_core_data_model-swift_version"></a>swift_version |  Target Swift version for generated classes.   | String | optional | "" |


<a id="apple_resource_bundle"></a>

## apple_resource_bundle

<pre>
apple_resource_bundle(<a href="#apple_resource_bundle-name">name</a>, <a href="#apple_resource_bundle-bundle_id">bundle_id</a>, <a href="#apple_resource_bundle-bundle_name">bundle_name</a>, <a href="#apple_resource_bundle-infoplists">infoplists</a>, <a href="#apple_resource_bundle-resources">resources</a>, <a href="#apple_resource_bundle-structured_resources">structured_resources</a>)
</pre>


This rule encapsulates a target which is provided to dependers as a bundle. An
`apple_resource_bundle`'s resources are put in a resource bundle in the top
level Apple bundle dependent. apple_resource_bundle targets need to be added to
library targets through the `data` attribute.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="apple_resource_bundle-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="apple_resource_bundle-bundle_id"></a>bundle_id |  The bundle ID for this target. It will replace <code>$(PRODUCT_BUNDLE_IDENTIFIER)</code> found in the files from defined in the <code>infoplists</code> paramter.   | String | optional | "" |
| <a id="apple_resource_bundle-bundle_name"></a>bundle_name |  The desired name of the bundle (without the <code>.bundle</code> extension). If this attribute is not set, then the <code>name</code> of the target will be used instead.   | String | optional | "" |
| <a id="apple_resource_bundle-infoplists"></a>infoplists |  A list of <code>.plist</code> files that will be merged to form the <code>Info.plist</code> that represents the extension. At least one file must be specified. Please see [Info.plist Handling](/doc/common_info.md#infoplist-handling") for what is supported.<br><br>Duplicate keys between infoplist files will cause an error if and only if the values conflict. Bazel will perform variable substitution on the Info.plist file for the following values (if they are strings in the top-level dict of the plist):<br><br>${BUNDLE_NAME}: This target's name and bundle suffix (.bundle or .app) in the form name.suffix. ${PRODUCT_NAME}: This target's name. ${TARGET_NAME}: This target's name. The key in ${} may be suffixed with :rfc1034identifier (for example ${PRODUCT_NAME::rfc1034identifier}) in which case Bazel will replicate Xcode's behavior and replace non-RFC1034-compliant characters with -.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="apple_resource_bundle-resources"></a>resources |  Files to include in the resource bundle. Files that are processable resources, like .xib, .storyboard, .strings, .png, and others, will be processed by the Apple bundling rules that have those files as dependencies. Other file types that are not processed will be copied verbatim. These files are placed in the root of the resource bundle (e.g. <code>Payload/foo.app/bar.bundle/...</code>) in most cases. However, if they appear to be localized (i.e. are contained in a directory called *.lproj), they will be placed in a directory of the same name in the app bundle.<br><br>You can also add other <code>apple_resource_bundle</code> and <code>apple_bundle_import</code> targets into <code>resources</code>, and the resource bundle structures will be propagated into the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="apple_resource_bundle-structured_resources"></a>structured_resources |  Files to include in the final resource bundle. They are not processed or compiled in any way besides the processing done by the rules that actually generate them. These files are placed in the bundle root in the same structure passed to this argument, so <code>["res/foo.png"]</code> will end up in <code>res/foo.png</code> inside the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |


<a id="apple_resource_group"></a>

## apple_resource_group

<pre>
apple_resource_group(<a href="#apple_resource_group-name">name</a>, <a href="#apple_resource_group-resources">resources</a>, <a href="#apple_resource_group-structured_resources">structured_resources</a>)
</pre>


This rule encapsulates a target which provides resources to dependents. An
`apple_resource_group`'s `resources` and `structured_resources` are put in the
top-level Apple bundle target. `apple_resource_group` targets need to be added
to library targets through the `data` attribute, or to other
`apple_resource_bundle` or `apple_resource_group` targets through the
`resources` attribute.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="apple_resource_group-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="apple_resource_group-resources"></a>resources |  Files to include in the final bundle that depends on this target. Files that are processable resources, like .xib, .storyboard, .strings, .png, and others, will be processed by the Apple bundling rules that have those files as dependencies. Other file types that are not processed will be copied verbatim. These files are placed in the root of the final bundle (e.g. Payload/foo.app/...) in most cases. However, if they appear to be localized (i.e. are contained in a directory called *.lproj), they will be placed in a directory of the same name in the app bundle.<br><br>You can also add apple_resource_bundle and apple_bundle_import targets into <code>resources</code>, and the resource bundle structures will be propagated into the final bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="apple_resource_group-structured_resources"></a>structured_resources |  Files to include in the final application bundle. They are not processed or compiled in any way besides the processing done by the rules that actually generate them. These files are placed in the bundle root in the same structure passed to this argument, so <code>["res/foo.png"]</code> will end up in <code>res/foo.png</code> inside the bundle.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |


<a id="apple_core_ml_library"></a>

## apple_core_ml_library

<pre>
apple_core_ml_library(<a href="#apple_core_ml_library-name">name</a>, <a href="#apple_core_ml_library-mlmodel">mlmodel</a>, <a href="#apple_core_ml_library-kwargs">kwargs</a>)
</pre>

Macro to orchestrate an objc_library with generated sources for mlmodel files.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="apple_core_ml_library-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="apple_core_ml_library-mlmodel"></a>mlmodel |  <p align="center"> - </p>   |  none |
| <a id="apple_core_ml_library-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


<a id="objc_intent_library"></a>

## objc_intent_library

<pre>
objc_intent_library(<a href="#objc_intent_library-name">name</a>, <a href="#objc_intent_library-src">src</a>, <a href="#objc_intent_library-class_prefix">class_prefix</a>, <a href="#objc_intent_library-testonly">testonly</a>, <a href="#objc_intent_library-kwargs">kwargs</a>)
</pre>

Macro to orchestrate an objc_library with generated sources for intentdefiniton files.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="objc_intent_library-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="objc_intent_library-src"></a>src |  <p align="center"> - </p>   |  none |
| <a id="objc_intent_library-class_prefix"></a>class_prefix |  <p align="center"> - </p>   |  <code>None</code> |
| <a id="objc_intent_library-testonly"></a>testonly |  <p align="center"> - </p>   |  <code>False</code> |
| <a id="objc_intent_library-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


<a id="swift_apple_core_ml_library"></a>

## swift_apple_core_ml_library

<pre>
swift_apple_core_ml_library(<a href="#swift_apple_core_ml_library-name">name</a>, <a href="#swift_apple_core_ml_library-mlmodel">mlmodel</a>, <a href="#swift_apple_core_ml_library-kwargs">kwargs</a>)
</pre>

Macro to orchestrate a swift_library with generated sources for mlmodel files.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="swift_apple_core_ml_library-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="swift_apple_core_ml_library-mlmodel"></a>mlmodel |  <p align="center"> - </p>   |  none |
| <a id="swift_apple_core_ml_library-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


<a id="swift_intent_library"></a>

## swift_intent_library

<pre>
swift_intent_library(<a href="#swift_intent_library-name">name</a>, <a href="#swift_intent_library-src">src</a>, <a href="#swift_intent_library-class_prefix">class_prefix</a>, <a href="#swift_intent_library-class_visibility">class_visibility</a>, <a href="#swift_intent_library-swift_version">swift_version</a>, <a href="#swift_intent_library-testonly">testonly</a>, <a href="#swift_intent_library-kwargs">kwargs</a>)
</pre>

This macro supports the integration of Intents `.intentdefinition` files into Apple rules.

It takes a single `.intentdefinition` file and creates a target that can be added as a dependency from `objc_library` or
`swift_library` targets.

It accepts the regular `swift_library` attributes too.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="swift_intent_library-name"></a>name |  A unique name for the target.   |  none |
| <a id="swift_intent_library-src"></a>src |  Reference to the <code>.intentdefiniton</code> file to process.   |  none |
| <a id="swift_intent_library-class_prefix"></a>class_prefix |  Class prefix to use for the generated classes.   |  <code>None</code> |
| <a id="swift_intent_library-class_visibility"></a>class_visibility |  Visibility attribute for the generated classes (<code>public</code>, <code>private</code>, <code>project</code>).   |  <code>None</code> |
| <a id="swift_intent_library-swift_version"></a>swift_version |  Version of Swift to use for the generated classes.   |  <code>None</code> |
| <a id="swift_intent_library-testonly"></a>testonly |  Set to True to enforce that this library is only used from test code.   |  <code>False</code> |
| <a id="swift_intent_library-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


