# Apple Bazel definitions - Common Information

## Controlling Builds

Most aspect of your builds should be controlled via the attributes you set on
the rules. However there are some things where bazel and/or the rules allow you
to opt in/out of something on a per-build basis without the need to express it
in a BUILD file.

### dSYMs Generation {#apple_generate_dsym}

dSYMs are needed for debugging, decode crash logs, etc.; but they can take a
while to generate and aren't always needed. All of the Apple rules support
generating a dSYM bundle via `--apple_generate_dsym` when doing a `bazel build`.

```shell
bazel build --apple_generate_dsym //your/target
```

<!-- Begin-External -->

### Codesigning identity

When building for devices, by default the codesigning step will use the first
codesigning identity present in the given provisioning profile. This should
accomodate most cases, but there are certain scenarios when the provisioning
profile will have more than one allowed signing identity, and developers may
have different development certificates installed on their devices. For these
cases you can use the `--ios_signing_cert_name` flag to force the signing
identity to be used when codesigning your app.

```shell
bazel build //your/target --ios_signing_cert_name="iPhone Developer: [CERT OWNER NAME]"
```

To make this easier to use, we recommend adding the following to the
`~/.bazelrc` file, which will configure bazel to pass this flag to all
invocations:

```text
build --ios_signing_cert_name="iPhone Developer: [CERT OWNER NAME]"
```

<!-- End-External -->
<!-- Blocked on b/73547309

### Sanitizers {#sanitizers}

Sanitizers are useful for validating your code by detecting runtime corruptions
in memory (Address Sanitizer), data race conditions (Thread Sanitizer), or
undefined behavior (Undefined Behavior Sanitizer). When running an application,
or its tests, using Bazel, you can enable these sanitizers using the following
flags:

```shell
# Address Sanitizer
bazel test --features=asan //your/target

# Thread Sanitizer
bazel test --features=tsan //your/target

# Undefined Behavior Sanitizer
bazel test --features=ubsan //your/target
```

When you enable these features, the appropriate compilation and linking flags
will be added to the build, and the rules will package the corresponding dylibs
into your output bundle.

Similar to what you can find in Xcode, the Address and Thread sanitizers are
mutually exclusive, i.e. you can only specify one or the other for a particular
build.

-->

<!-- Blocked on b/73547215

### linkmap Generation {#objc_generate_linkmap}

Linkmaps can be useful for figuring out how the `deps` going into a target are
contributing to the final size of the binary. Bazel will generate a link map
when linking by adding `--objc_generate_linkmap` to a `bazel build`.

```shell
bazel build --objc_generate_linkmap //your/target
```

-->

### Debugging Entitlement Support {#apple.add_debugger_entitlement}

Some Apple platforms require an entitlement (`get-task-allow`) to support
debugging tools. The rules will auto add the entitlement for non optimized
builds (i.e. - anything that isn't `-c opt`). However when looking at specific
issues (performance of a release build via Instruments), the entitlement is also
needed.

The rules support direct control over the inclusion/exclusion of any bundle
being built by
`--define=apple.add_debugger_entitlement=(yes|true|1|no|false|0)`.

Add `get-task-allow` entitlement:

```shell
bazel build --define=apple.add_debugger_entitlement=yes //your/target
```

Ensure `get-task-allow` entitlement is *not* added (even if the default would
have added it):

```shell
bazel build --define=apple.add_debugger_entitlement=no //your/target
```

### Include Embedded Bundles in Rule Output {#apple.propagate_embedded_extra_outputs}

Some Apple bundles include other bundles within them (for example, an
application extension inside an iOS application). When you build a top-level
application target and ask for extra outputs such as linkmaps or dSYM bundles,
Bazel typically only produces the extra outputs for the top-level application
but not for the embedded extension.

In order to produce those extra outputs for all embedded bundles as well, you
can pass `--define=apple.propagate_embedded_extra_outputs=(yes|true|1)` to
`bazel build`.

```shell
bazel build --define=apple.propagate_embedded_extra_outputs=yes //your/target
```

### Codesign Bundles for the Simulator {#apple.codesign_simulator_bundles}

The simulators are far more lax about a lot of things compared to working on
real devices. One of these areas is the codesigning of bundles (applications,
extensions, etc.). As of Xcode 9.3.x on macOS High Sierra, the Simulator will
run any bundle just fine as long as its Frameworks are signed (if it has any),
the main bundle does *not* appear to need to be signed.

By default, the rules will do what Xcode would otherwise do and *will* sign
the main bundle (with an adhoc signature) when targeting the Simulator.
However, this `--define` can be used to opt out of this if you are more
concerned with build speed vs. potential correctness.

Remember, at any time, Apple could do a macOS point release and/or an Xcode
release that changes this and opting out of could mean your binary doesn't
run under the simulator.

The rules support direct control over this signing via
`--define=apple.codesign_simulator_bundles=(yes|true|1|no|false|0)`.

Disable the signing of simulator bundles:

```shell
bazel build --define=apple.codesign_simulator_bundles=no //your/target
```

<!--
 Define not currently documented:

   apple.experimental_bundling=[bundle_and_archive,bundle_only,off]

 Support for this option is tracked in b/35451264, but because of the tree
 artifact issues, it isn't really useful at the moment.
-->

## Info.plist Handling

### Merging

The `infoplists` attribute on the Apple rules takes a list of files that will be
merged. This allows developers to provide fragments of the final Info.plist and
use `select()` statements to pull in different bits based on different
configuration settings. For example, a `select()` on some `config_setting` could
allow the rule to pull in a file with a different `CFBundleDisplayName` pair for
the TestFlight build.

The merging though is done only at the root level of these plists. If two files
being merged have the same key, their values must match. That means if two files
both have a value for something (e.g., `CFBundleDisplayName`), then as long as
the values are the same, the build will succeed; but if they have different
values, then the build will fail. If a key's value is an array or a dictionary,
those values won't be merged and must match to avoid the failure.

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
