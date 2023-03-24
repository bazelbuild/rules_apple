# Bazel Tutorial: Build an iOS App

This tutorial covers how to build a simple iOS app using Bazel.

## What you'll learn

In this tutorial, you learn how to:

*   Set up the environment by installing Bazel and Xcode, and downloading the
    sample project
*   Set up a Bazel [workspace](https://bazel.build/concepts/build-ref#workspace) that contained the source code
    for the app and a `WORKSPACE` file that identifies the top level of the
    workspace directory
*   Update the `WORKSPACE` file to contain references to the required
    external dependencies
*   Create a `BUILD` file
*   Run Bazel to build the app for the simulator and an iOS device
*   Run the app in the simulator and on an iOS device

## Set up your environment

To get started, install Bazel and Xcode, and get the sample project.

### Install Bazel

Follow the [installation instructions](https://bazel.build/install) to install Bazel and
its dependencies.

### Install Xcode

Download and install [Xcode](https://developer.apple.com/xcode/downloads/).
Xcode contains the compilers, SDKs, and other tools required by Bazel to build
Apple applications.

### Get the sample project

You also need to get the sample project for the tutorial from GitHub. The GitHub
repo has two branches: `source-only` and `main`. The `source-only` branch
contains the source files for the project only. You'll use the files in this
branch in this tutorial. The `main` branch contains both the source files
and completed Bazel `WORKSPACE` and `BUILD` files. You can use the files in this
branch to check your work when you've completed the tutorial steps.

Enter the following at the command line to get the files in the `source-only`
branch:

```bash
cd $HOME
git clone -b source-only https://github.com/bazelbuild/examples
```

The `git clone` command creates a directory named `$HOME/examples/`. This
directory contains several sample projects for Bazel. The project files for this
tutorial are in `$HOME/examples/tutorial/ios-app`.

## Set up a workspace

A [workspace](https://bazel.build/concepts/build-ref#workspace) is a directory that contains the
source files for one or more software projects, as well as a `WORKSPACE` file
and `BUILD` files that contain the instructions that Bazel uses to build
the software. The workspace may also contain symbolic links to output
directories.

A workspace directory can be located anywhere on your filesystem and is denoted
by the presence of the `WORKSPACE` file at its root. In this tutorial, your
workspace directory is `$HOME/examples/tutorial/`, which contains the sample
project files you cloned from the GitHub repo in the previous step.

Note: Bazel itself doesn't impose any requirements for organizing source
files in your workspace. The sample source files in this tutorial are organized
according to conventions for the target platform.

For your convenience, set the `$WORKSPACE` environment variable now to refer to
your workspace directory. At the command line, enter:

```bash
export WORKSPACE=$HOME/examples/tutorial
```

### Create a WORKSPACE file

Every workspace must have a text file named `WORKSPACE` located in the top-level
workspace directory. This file may be empty or it may contain references
to [external dependencies](https://bazel.build/docs/external) required to build the
software.

For now, you'll create an empty `WORKSPACE` file, which simply serves to
identify the workspace directory. In later steps, you'll update the file to add
external dependency information.

Enter the following at the command line:

```bash
touch $WORKSPACE/WORKSPACE
open -a Xcode $WORKSPACE/WORKSPACE
```

This creates and opens the empty `WORKSPACE` file.

### Update the WORKSPACE file

To build applications for Apple devices, Bazel needs to pull the latest
[Apple build rules](https://github.com/bazelbuild/rules_apple)
from its GitHub repository. To enable this, add the following
statements to your `WORKSPACE` file:

```starlark
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "build_bazel_rules_apple",
    sha256 = "90e3b5e8ff942be134e64a83499974203ea64797fd620eddeb71b3a8e1bff681",
    url = "https://github.com/bazelbuild/rules_apple/releases/download/1.1.2/rules_apple.1.1.2.tar.gz",
)

load(
    "@build_bazel_rules_apple//apple:repositories.bzl",
    "apple_rules_dependencies",
)

apple_rules_dependencies()

load(
    "@build_bazel_rules_swift//swift:repositories.bzl",
    "swift_rules_dependencies",
)

swift_rules_dependencies()

load(
    "@build_bazel_rules_swift//swift:extras.bzl",
    "swift_rules_extra_dependencies",
)

swift_rules_extra_dependencies()

load(
    "@build_bazel_apple_support//lib:repositories.bzl",
    "apple_support_dependencies",
)

apple_support_dependencies()
```

Note: Always use the
[latest version of the Apple rules](https://github.com/bazelbuild/rules_apple/releases)
in the `url` attribute. Make sure to check the latest dependencies required in
`rules_apple`'s [project](https://github.com/bazelbuild/rules_apple).

## Review the source files

Take a look at the source files for the app located in
`$WORKSPACE/ios-app/UrlGet`. Again, you're just looking at these files now to
become familiar with the structure of the app. You don't have to edit any of the
source files to complete this tutorial.

## Create a BUILD file

At a command-line prompt, open a new `BUILD` file for editing:

```bash
touch $WORKSPACE/ios-app/BUILD
open -a Xcode $WORKSPACE/ios-app/BUILD
```

### Add the rule load statement

To build iOS targets, Bazel needs to load build rules from its GitHub repository
whenever the build runs. To make these rules available to your project, add the
following load statement to the beginning of your `BUILD` file:

```
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_application")
```

You only need to load the `ios_application` rule because the `objc_library`
rule is built into the Bazel package.

### Add an objc_library rule

Bazel provides several build rules that you can use to build an app for the
iOS platform. For this tutorial, you'll first use the
[`objc_library`](https://bazel.build/reference/be/objective-c#objc_library) rule to tell Bazel
how to build a static library from the app source code and Xib files. Then
you'll use the
[`ios_application`](https://github.com/bazelbuild/rules_apple/tree/main/doc)
rule to tell it how to build the application binary and the `.ipa` bundle.

Note: This tutorial presents a minimal use case of the Objective-C rules in
Bazel. For example, you have to use the `ios_application` rule to build
multi-architecture iOS apps.

Add the following to your `BUILD` file:

```python
objc_library(
    name = "UrlGetClasses",
    srcs = [
         "UrlGet/AppDelegate.m",
         "UrlGet/UrlGetViewController.m",
         "UrlGet/main.m",
    ],
    hdrs = glob(["UrlGet/*.h"]),
)
```

Note the name of the rule, `UrlGetClasses`.

### Add an ios_application rule

The
[`ios_application`](https://github.com/bazelbuild/rules_apple/tree/main/doc)
rule builds the application binary and creates the `.ipa` bundle file.

Add the following to your `BUILD` file:

```python
ios_application(
    name = "ios-app",
    bundle_id = "Google.UrlGet",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [":UrlGet/UrlGet-Info.plist"],
    launch_storyboard = "UrlGet/UrlGetViewController.xib",
    minimum_os_version = "15.0",
    visibility = ["//visibility:public"],
    deps = [":UrlGetClasses"],
)
```

Note: Please update the `minimum_os_version` attribute to the minimum
version of iOS that you plan to support.

Note how the `deps` attribute references the output of the `UrlGetClasses` rule
you added to the `BUILD` file above.

Now, save and close the file. You can compare your `BUILD` file to the
[completed example](https://github.com/bazelbuild/examples/blob/main/tutorial/ios-app/BUILD)
in the `main` branch of the GitHub repo.

## Build and deploy the app

You are now ready to build your app and deploy it to a simulator and onto an
iOS device.

Note: The app launches standalone but requires a backend server in order to
produce output. See the README file in the sample project directory to find out
how to build the backend server.

The built app is located in the `$WORKSPACE/bazel-bin` directory.

Completed `WORKSPACE` and `BUILD` files for this tutorial are located in the
[main branch](https://github.com/bazelbuild/examples/tree/main/tutorial)
of the GitHub repo. You can compare your work to the completed files for
additional help or troubleshooting.

### Build the app for the simulator

Make sure that your current working directory is inside your Bazel workspace:

```bash
cd $WORKSPACE
```

Now, enter the following to build the sample app:

```bash
bazel build //ios-app:ios-app
```

Bazel launches and builds the sample app. During the build process, its
output will appear similar to the following:

```bash
INFO: Found 1 target...
Target //ios-app:ios-app up-to-date:
  bazel-out/applebin_ios-ios_sim_arm64-fastbuild-ST-4e6c2a19403f/bin/ios-app/ios-app.ipa
INFO: Elapsed time: 0.141s, Critical Path: 0.00s
```

### Find the build outputs

The `.ipa` file and other outputs are located in the
`$WORKSPACE/bazel-out/applebin_ios-ios_sim_arm64-fastbuild-ST-4e6c2a19403f/bin/ios-app/ios-app.ipa` directory.

### Build the app in the simulator

`rules_apple` supports running an app directly in the iOS Simulator.
Replace `build` with `run` in the previous command to both build and
run the application:

```bash
bazel run //ios-app:ios-app
```

Note: [`--ios_simulator_device`](https://bazel.build/reference/command-line-reference#flag--ios_simulator_device) and [`--ios_simulator_version`](https://bazel.build/reference/command-line-reference#flag--ios_simulator_version) control which
version and device will be used when launching the app.

### Generate an Xcode project

There are a few community-provided solutions (such as [rules_xcodeproj](https://github.com/buildbuddy-io/rules_xcodeproj)
) to help generating Xcode projects. By doing so, you will be able to write,
debug, and test iOS/macOS/watchOS/tvOS applications as if you were using the
Xcode build system.

Let's see how to do so with `rules_xcodeproj`.

Open the `WORKSPACE` file again and add the following:

```starlark
http_archive(
    name = "rules_xcodeproj",
    sha256 = "7967b372bd1777214ce65c87a82ac0630150b7504b443de0315ea52e45758e0c",
    url = "https://github.com/buildbuddy-io/rules_xcodeproj/releases/download/1.3.3/release.tar.gz",
)

load(
    "@rules_xcodeproj//xcodeproj:repositories.bzl",
    "xcodeproj_rules_dependencies",
)

xcodeproj_rules_dependencies()
```

Add the following import at the top of the `BUILD` file:

```starlark
load(
    "@rules_xcodeproj//xcodeproj:defs.bzl",
    "top_level_target",
    "xcodeproj",
)
```

We can now define the rule that will generate the Xcode project:

```starlark
xcodeproj(
    name = "xcodeproj",
    build_mode = "bazel",
    project_name = "ios-app",
    tags = ["manual"],
    top_level_targets = [
        ":ios-app",
    ],
)
```

To generate the Xcode project, invoke this rule with the following command:

```bash
bazel run //ios-app:xcodeproj
```

You should be able to open the generated `ios-app.xcodeproj` (e.g. `xed ios-app.xcodeproj`) and do all the usual
operations of building and testing in Xcode.

### Build the app for a device

If you want to distribute your app or install it on a physical device,
you will need to correctly set up provisioning profiles and distribution certificates.
Feel free to skip this section or come back to it at a later point.

To build your app so that it installs and launches on an iOS device, Bazel needs
the appropriate provisioning profile for that device model. Do the following:

1. Go to your [Apple Developer Account](https://developer.apple.com/account)
   and download the appropriate provisioning profile for your device. See
   [Apple's documentation](https://developer.apple.com/library/ios/documentation/IDEs/Conceptual/AppDistributionGuide/MaintainingProfiles/MaintainingProfiles.html)
   for more information.

2. Move your profile into `$WORKSPACE`.

3. (Optional) Add your profile to your `.gitignore` file.

4. Add the following line to the `ios_application` target in your `BUILD` file:

   ```python
   provisioning_profile = "<your_profile_name>.mobileprovision",
   ```

Note: Ensure the profile is correct so that the app can be installed on a
device.

Now build the app for your device:

```bash
bazel build //ios-app:ios-app --ios_multi_cpus=arm64
```

This builds the app as a fat binary. To build for a specific device
architecture, designate it in the build options.

To build for a specific Xcode version, use the `--xcode_version` option. To
build for a specific SDK version, use the `--ios_sdk_version` option. The
`--xcode_version` option is sufficient in most scenarios.

To specify a minimum required iOS version, add the `minimum_os_version`
parameter to the `ios_application` build rule in your `BUILD` file.

You should also update the previously defined `xcodeproj` rule to specify
support for building for a device:

```starlark
xcodeproj(
    name = "xcodeproj",
    build_mode = "bazel",
    project_name = "ios-app",
    tags = ["manual"],
    top_level_targets = [
        top_level_target(":ios-app", target_environments = ["device", "simulator"]),
    ],
)
```

Note: A more advanced integration for provisioning profiles can be achieved using
the [`provisioning_profile_repository`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-apple.md#provisioning_profile_repository)
and [`local_provisioning_profile`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-apple.md#local_provisioning_profile)
rules.

### Install the app on a device

The easiest way to install the app on the device is to launch Xcode and use the
`Windows > Devices` command. Select your plugged-in device from the list on the
left, then add the app by clicking the **Add** (plus sign) button under
"Installed Apps" and selecting the `.ipa` file that you built.

If your app fails to install on your device, ensure that you are specifying the
correct provisioning profile in your `BUILD` file (step 4 in the previous
section).

If your app fails to launch, make sure that your device is part of your
provisioning profile. The `View Device Logs` button on the `Devices` screen in
Xcode may provide other information as to what has gone wrong.

## Further reading

For more details, see
[main branch](https://github.com/bazelbuild/examples/tree/main/tutorial)
of the GitHub repo.
