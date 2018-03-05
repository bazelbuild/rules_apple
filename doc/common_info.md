# Apple Bazel definitions - Common Information

## Info.plist Handling

### Merging

The `infoplists` attribute on the Apple rules takes a list of files that will
be merged. This allows developers to provide fragments of the final Info.plist
and use `select()` statements to pull in different bits based on different
configuration settings. For example, a `select()` on some `config_setting`
could allow the rule to pull in a file with a different
`CFBundleDisplayName` pair for the TestFlight build.

The merging though is done only at the root level of these plists. If two
files being merged have the same key, their values must match. That means
if two files both have a value for something (e.g., `CFBundleDisplayName`),
then as long as the values are the same, the build will succeed; but if they
have different values, then the build will fail. If a key's value is an array
or a dictionary, those values won't be merged and must match to avoid the
failure.

### Variable Substitution

As the files are merged, the values are recursively checked for variable
references and substitutions are made. A reference is made using `${NAME}` or
`$(NAME)` notation. Similar to Xcode, the variable reference can get the
`rfc1034identifier` qualifier (i.e., `${NAME:rfc1034identifier}`); this will
transform the value such that any characters besides `0-9A-Za-z.` will be
replaced with the `-` character (i.e., `Foo Bar` will become `Foo-Bar`).

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Variables Supported</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>BUNDLE_NAME</code></td>
      <td>
        <p>This is the same value as <code>PRODUCT_NAME</code>, but with the
        an extension appended. If the target supports a
        <code>bundle_extension</code></p> attribute, that is used. If it does
        not, or it is not set, then the Apple default is used based on the
        target's product type (i.e., <code>.app</code>, <code>.appex</code>,
        <code>.bundle</code>, etc.).</p>
      </td>
    </tr>
    <tr>
      <td><code>EXECUTABLE_NAME</code></td>
      <td>
        <p>This is an alias for the same value as <code>PRODUCT_NAME</code>.
        This is done to match some developer expectations from Xcode. It is
        only available on rules that create executables, not on those that
        create resource-only bundles.</p>
      </td>
    </tr>
    <tr>
      <td><code>PRODUCT_BUNDLE_IDENTIFIER</code></td>
      <td>
        <p>The value of the rule's <code>bundle_id</code> attribute. If the rule
        does not have the attribute, it is not supported.</p>
      </td>
    </tr>
    <tr>
      <td><code>PRODUCT_NAME</code></td>
      <td>
        <p>If the rule supports a <code>bundle_name</code> attribute, it is
        that value. If the rule doesn't have the attribute or the attribute
        isn't set, then it is the <code>name</code> of the target.</p>
      </td>
    </tr>
    <tr>
      <td><code>TARGET_NAME</code></td>
      <td>
        <p>This is an alias for the same value as <code>PRODUCT_NAME</code>.
        This is done to match some developer expectations from Xcode. Note
        that, despite the word "TARGET" in the name, it may not always
        correspond to the <code>BUILD</code> target if the
        <code>bundle_name</code> attribute is provided.</p>
      </td>
    </tr>
  </tbody>
</table>

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Variables Explicitly Not Supported</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>PRODUCT_MODULE_NAME</code></td>
      <td>
        <p>This is a variable commonly used in extensions to specify the
        <code>NSExtensionPrincipalClass</code> attribute, which signals which
        class is the entry point to the extension (e.g.
        <code>$(PRODUCT_MODULE_NAME).ServiceExtension</code>). When not
        explicitly set, Xcode sets it to the same value as
        <code>PRODUCT_NAME</code>, which is the name of the Xcode target. This
        is mostly safe to do when using plain Xcode, as by default it defines
        one module per target, and all classes belong to that module. When using
        Bazel to build an extension, through <code>objc_library</code> and/or
        <code>swift_library</code>, each of the targets defines a new module,
        which makes it harder to automatically detect the module name which
        contains the principal class. Because of this reason, this value is not
        supported and therefore should be explicitly set in your targets'
        Info.plist files.</p>
      </td>
    </tr>
  </tbody>
</table>

