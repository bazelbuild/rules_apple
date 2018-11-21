# Apple Bazel definitions

## Platform-specific rules

Each Apple platform has its own rules for building bundles (applications,
extensions, and frameworks) and for running unit tests and UI tests.

<table class="table table-condensed table-bordered table-params">
  <thead>
    <tr>
      <th>Platform</th>
      <th><code>.bzl</code> file</th>
      <th>Bundling rules</th>
      <th>Testing rules</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th align="left" valign="top">iOS</th>
      <td valign="top"><code>@build_bazel_rules_apple//apple:ios.bzl</code></td>
      <td valign="top">
        <code><a href="rules-ios.md#ios_application">ios_application</a></code><br/>
        <code><a href="rules-ios.md#ios_extension">ios_extension</a></code><br/>
        <code><a href="rules-ios.md#ios_framework">ios_framework</a></code><br/>
        <code><a href="rules-ios.md#ios_static_framework">ios_static_framework</a></code><br/>
      </td>
      <td valign="top">
        <code><a href="rules-ios.md#ios_ui_test">ios_ui_test</a></code><br/>
        <code><a href="rules-ios.md#ios_ui_test_suite">ios_ui_test_suite</a></code><br/>
        <code><a href="rules-ios.md#ios_unit_test">ios_unit_test</a></code><br/>
        <code><a href="rules-ios.md#ios_unit_test_suite">ios_unit_test_suite</a></code><br/>
      </td>
    </tr>
    <tr>
      <th align="left" valign="top">macOS</th>
      <td valign="top"><code>@build_bazel_rules_apple//apple:macos.bzl</code></td>
      <td valign="top">
        <code><a href="rules-macos.md#macos_application">macos_application</a></code><br/>
        <code><a href="rules-macos.md#macos_bundle">macos_bundle</a></code><br/>
        <code><a href="rules-macos.md#macos_command_line_application">macos_command_line_application</a></code><br/>
        <code><a href="rules-macos.md#macos_extension">macos_extension</a></code><br/>
      </td>
      <td valign="top">
        <code><a href="rules-macos.md#macos_unit_test">macos_unit_test</a></code><br/>
      </td>
    <tr>
      <th align="left" valign="top">tvOS</th>
      <td valign="top"><code>@build_bazel_rules_apple//apple:tvos.bzl</code></td>
      <td valign="top">
        <code><a href="rules-tvos.md#tvos_application">tvos_application</a></code><br/>
        <code><a href="rules-tvos.md#tvos_extension">tvos_extension</a></code><br/>
      </td>
      <td valign="top">
        Coming soon.
      </td>
    </tr>
    <tr>
      <th align="left" valign="top">watchOS</th>
      <td valign="top"><code>@build_bazel_rules_apple//apple:watchos.bzl</code></td>
      <td valign="top">
        <code><a href="rules-watchos.md#watchos_application">watchos_application</a></code><br/>
        <code><a href="rules-watchos.md#watchos_extension">watchos_extension</a></code><br/>
      </td>
      <td valign="top"></td>
    </tr>
  </tbody>
</table>

## Other rules

General rules that are not specific to a particular Apple platform are listed
below.

<table class="table table-condensed table-bordered table-params">
  <thead>
    <tr>
      <th>Category</th>
      <th><code>.bzl</code> file</th>
      <th>Rules</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th align="left" valign="top" rowspan="2">General</th>
      <td valign="top"><code>@build_bazel_rules_apple//apple:versioning.bzl</code></td>
      <td valign="top"><code><a href="rules-general.md#apple_bundle_version">apple_bundle_version</a></code><br/></td>
    </tr>
    <tr>
      <td valign="top"><code>@build_bazel_rules_apple//apple:apple_genrule.bzl</code></td>
      <td valign="top"><code><a href="rules-general.md#apple_genrule">apple_genrule</a></code><br/></td>
    </tr>
    <tr>
      <td valign="top"><code>@build_bazel_rules_apple//apple:apple.bzl</code></td>
      <td valign="top"><code><a href="rules-general.md#apple_framework_import">apple_framework_import</a></code><br/></td>
    </tr>
    <tr>
      <th align="left" valign="top" rowspan="2">Resources</th>
      <td valign="top"><code>@build_bazel_rules_apple//apple:resources.bzl</code></td>
      <td valign="top"><code><a href="rules-resources.md#apple_bundle_import">apple_bundle_import</a></code><br/></td>
    </tr>
    <tr>
      <td valign="top"><code>@build_bazel_rules_apple//apple:resources.bzl</code></td>
      <td valign="top"><code><a href="rules-resources.md#apple_resource_bundle">apple_resource_bundle</a></code><br/></td>
    </tr>
    <tr>
      <td valign="top"><code>@build_bazel_rules_apple//apple:resources.bzl</code></td>
      <td valign="top"><code><a href="rules-resources.md#apple_resource_group">apple_resource_group</a></code><br/></td>
    </tr>
  </tbody>
</table>

## Related types

* [`apple_product_type`](types.md#apple_product_type) &ndash; Defines
  identifiers used to indicate special product types for Apple targets. This is
  currently exported by `@build_bazel_rules_apple//apple:ios.bzl` (the only
  platform that needs special product types at this time).

## Extending or integrating with these rules

If you want to write custom rules that integrate with these Apple platform rules
(for example, write a rule that provides resources to an application or takes
an application as a dependency), then please refer to the documentation on
[providers](providers.md) to see the data that these rules propagate as output
and expect as input.
