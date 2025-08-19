# Bazel Tutorial: Build an iOS App

This tutorial will cover how to build a simple iOS application using Bazel.

## What You'll Learn

In this tutorial, you learn how to:

- Set up a Bazel [workspace](https://bazel.build/concepts/build-ref#workspace) and build files to declare a basic iOS application
- Use Bazel to build and run the app in an iOS simulator
- Use Bazel to build and run the app on an iOS device
- Create an Xcode project to continue working on your iOS application

## Set Up Your Environment

To get started, you'll need to install Bazel and Xcode first.

### Install Bazel

Follow the [installation instructions](https://bazel.build/install) to install Bazel and its dependencies.

### Install Xcode

Download and install [Xcode](https://developer.apple.com/xcode/downloads/). Xcode contains the compilers, SDKs, and other tools required by Bazel to build Apple applications.

## Set Up a Workspace

A [workspace](https://bazel.build/concepts/build-ref#workspace) is a directory that contains the source files for one or more software projects, as well as a `MODULE.bazel` file and `BUILD` files that contain the instructions that Bazel uses to build the software. The workspace may also contain symbolic links to output directories.

A workspace directory can be located anywhere on your filesystem and is denoted by the presence of the `MODULE.bazel` file at its root.

### Create a MODULE.bazel file

Start by creating a directory that will contain your workspace. Name it `rules-apple-example`, and set it as the current directory:

```bash
mkdir rules-apple-example
cd rules-apple-example
```

Run `touch MODULE.bazel` to create the file, then open it in your preferred text editor. Add the following code snippet to the file:

```starlark
module(name = "rules-apple-example", version = "")

bazel_dep(name = "apple_support", version = "1.22.1")
bazel_dep(name = "rules_apple", version = "4.0.1")
bazel_dep(name = "rules_swift", version = "3.0.2")
```

These three `bazel_dep`s are versions available on the [Bazel Central Registry](https://registry.bazel.build/)

- [`apple_support`](https://registry.bazel.build/modules/apple_support) is responsible for registering Xcode and the platform SDKs as a Bazel toolchain.
- [`rules_apple`](https://registry.bazel.build/modules/rules_apple) is this repository, and provides rules for packaging and running code on Apple platforms.
- [`rules_swift`](https://registry.bazel.build/modules/rules_swift) provides build rules and utilities for compiling and testing Swift code.

> [!NOTE]
> Always use the latest releases of the rules in your MODULE.bazel to minimize incompatibility with newer releases of Bazel and Xcode. You can find release information for each `bazel_dep` at <https://registry.bazel.build>.

### Add Some Swift Code

Create a new directory named `Sources` by executing `mkdir Sources` in your terminal. This directory will contain a basic Swift source file for a simple iOS application built in SwiftUI.

Run `touch Sources/BazelApp.swift` to create the file, then open it in your preferred text editor. Add the following code snippet to the file:

```swift
import SwiftUI

@main
struct BazelApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Hello from Bazel!")
        }
    }
}
```

> [!TIP]
>
> [mattrobmattrob/bazel-ios-swiftui-template](https://github.com/mattrobmattrob/bazel-ios-swiftui-template) contains a template for a SwiftUI iOS application that builds with Bazel if you want to speed up this process for future usages.

### Create a BUILD File

A Bazel workspace is made up of directories called [packages](https://bazel.build/concepts/build-ref#packages). A package is a directory containing a [`BUILD` file](https://bazel.build/concepts/build-files) and can contain any number of sources or subpackages. `BUILD` files contain specifications for [targets](https://bazel.build/concepts/build-ref#targets) that you use Bazel to build, run, or test.

Run `touch BUILD` to create a file, then open it in your preferred text editor.

Then, add load statements to bring the [rules](https://bazel.build/reference/glossary#rule) you will be using into scope:

```starlark
load("@rules_apple//apple:ios.bzl", "ios_application")
load("@rules_swift//swift:swift.bzl", "swift_library")
```

Next, declare a `swift_library` target using the rule you just loaded:

```starlark
swift_library(
    name = "lib",
    srcs = glob(["Sources/*.swift"]),
)
```

This rule informs Bazel how to build your Swift source code prior to packaging it. Note the name of the target, `lib`, which can be referenced with the label `//:lib` (or simply `lib` when running Bazel in the current directory). Also note the [`glob`](https://bazel.build/reference/be/functions#glob) function passed to the `srcs` attribute, which will automatically add all files in `Sources` with the `.swift` extension to the library.

Finally, you're going to set up an `ios_application` target in much the same way. You will be using this target to build the iOS application as an `.ipa`. Create another directory next to `Sources` named `Resources` and create an `Info.plist` in that directory. You may use [this example Info.plist](/examples/ios/HelloWorldSwift/Info.plist) as a reference to populate your new `Info.plist`.

Then, below the `swift_library`, add the following code snippet to the file:

```starlark
ios_application(
    name = "iOSApp",
    bundle_id = "build.bazel.rules-apple-example",
    families = ["iphone", "ipad"],
    infoplists = ["Resources/Info.plist"],
    minimum_os_version = "17.0",
    deps = [":lib"],
)
```

Observe how the `deps` attribute references the `lib` target you declared earlier. This is one of the ways Bazel expresses dependencies between targets. Additionally, you may update the `minimum_os_version` attribute to whatever minimum OS version you plan to support.

With that, you're now ready to run your app!

## Build and Run the App

To build the app you just created, execute the following:

```shell
bazel build //:iOSApp
```

Bazel will build the app and package it into an uncompressed `.ipa` targeting the Simulator. Once it's finished, you should see output similar to the following:

```shell
INFO: Found 1 target...
Target //:iOSApp up-to-date:
  bazel-bin/iOSApp.ipa
INFO: Elapsed time: 1.999s, Critical Path: 1.89s
```

The `bazel-bin/iOSApp.ipa` in the above output refers to one of the outputs of the build command – namely the `.ipa` you just built with Bazel! This file is also available in a subdirectory of `bazel-out`, under a path resembling `bazel-out/ios-sim_arm64-min17.0-applebin_ios-ios_sim_arm64-fastbuild-ST-b6790d224f6d/bin/iOSApp.ipa`.

To run this app in a simulator, replace the `build` command above with `run`:

```shell
bazel run //:iOSApp
```

> [!TIP]
> Use [`--ios_simulator_device`](https://bazel.build/reference/command-line-reference#flag--ios_simulator_device) and [`--ios_simulator_version`](https://bazel.build/reference/command-line-reference#flag--ios_simulator_version) to control the run destination used to launch the app.

## Generate an Xcode project

[rules_xcodeproj](https://github.com/MobileNativeFoundation/rules_xcodeproj) is the de-facto solution for generating Xcode projects for Bazel workspaces. These generated projects build with Bazel under-the-hood, giving you access to remote cache and other Bazel features within Xcode.

First, in your `MODULE.bazel` file, add the following code snippet:

```starlark
bazel_dep(name = "rules_xcodeproj", version = "3.0.0")
```

Next, at the top of your `BUILD` file, add the following code snippet:

```starlark
load("@rules_xcodeproj//xcodeproj:defs.bzl", "top_level_target", "xcodeproj")
```

Finally, at the bottom of the same `BUILD` file, add the following code snippet:

```starlark
xcodeproj(
    name = "xcodeproj",
    project_name = "iOSApp",
    tags = ["manual"],
    top_level_targets = [
        top_level_target(
            ":iOSApp",
            target_environments = ["device", "simulator"],
        ),
    ],
)
```

To generate the Xcode project, invoke this rule by executing the following command:

```bash
bazel run //:xcodeproj
```

You should be able to open the generated `iOSApp.xcodeproj` in Xcode (e.g. with `xed iOSApp.xcodeproj`) to perform all the usual operations of building and testing in Xcode.

## Build and Run the App on an iOS Device

Building an iOS application to run on iOS devices requires some additional setup to ensure the app can be codesigned properly. The steps below will guide you through the process of integrating provisioning information with Bazel, but presumes that your Apple Developer account is set up to provision apps for your device, and your system has codesigning identities installed.

1. Go to the [Apple Developer Center](https://developer.apple.com/account). Download the appropriate [provisioning profile](https://developer.apple.com/library/ios/documentation/IDEs/Conceptual/AppDistributionGuide/MaintainingProfiles/MaintainingProfiles.html) for your device.
2. Move your provisioning profile into your workspace directory.
   1. Provisioning profiles do not contain sensitive signing information, so don't worry about them lingering on your system. If you'd rather not track them in version control, add the path to a `.gitignore` (if using Git).
3. In your `BUILD` file, add the following code snippet **to your `ios_application` target**:

   ```starlark
   provisioning_profile = "<your_profile_name>.mobileprovision",
   ```

4. Build the app for device:

```shell
bazel build //:iOSApp --ios_multi_cpus=arm64
```

The [`--ios_multi_cpus`](https://bazel.build/reference/command-line-reference#flag--ios_multi_cpus) flag controls the architecture(s) of the built application. The default unspecified value for `ios_application` is `ios_sim_arm64` (or `ios_x86_64` if your host is an Intel Mac). A full list of possible options can be found [here](https://github.com/bazelbuild/apple_support/blob/master/configs/platforms.bzl).

> [!TIP]
> rules_apple provides a pair of more advanced integrations for exposing provisioning profiles to Bazel, with the [`provisioning_profile_repository`](/doc/rules-apple.md#provisioning_profile_repository) and [`local_provisioning_profile`](/doc/rules-apple.md#local_provisioning_profile) rules.

Similar to the simulator, you can install and run the app on a physical iOS device by replacing the `build` command above with `run`:

```bash
bazel run //:iOSApp --ios_multi_cpus=arm64
```

rules_apple wraps devicectl in a tool to find any attached devices with an OS version greater than or equal to the `minimum_os_version` of the `ios_application`. You may use `--@rules_apple//apple/build_settings:ios_device` to specify a particular device. The flag accepts device UUIDs, ECIDs, UDIDs, serial numbers, names, or DNS names.

> [!TIP]
> Use `xcrun devicectl list devices` to list the devices available to devicectl.

Another method to install the app on a connected device is using Xcode. Launch Xcode, and open the **Devices and Simulators** window under the **Window** menu item. Select your connected device from the list, click the **Add** (plus sign) button under **Installed Apps**, and select the `.ipa` you built. If your app fails to install on your device, ensure that your provisioning profile is valid and configured for your device. If your app fails to launch, the **View Device Logs** button may provide more insight into why.

## Further Reading

Check out the [examples/](/examples) we have in rules_apple, as well as those in [rules_swift](https://github.com/bazelbuild/rules_swift/tree/master/examples) and [rules_xcodeproj](https://github.com/MobileNativeFoundation/rules_xcodeproj/tree/main/examples).

Make sure to also check out the other articles we have under [doc/](/doc) – in particular [common_info](/doc/common_info.md).

Finally, check out [How to migrate an iOS app to Bazel](https://brentley.dev/how-to-migrate-an-ios-app-to-bazel/), written by @brentleyjones. 
