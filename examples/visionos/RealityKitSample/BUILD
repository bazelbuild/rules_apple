load("@bazel_skylib//rules:build_test.bzl", "build_test")
load(
    "@build_bazel_rules_swift//swift:swift_library.bzl",
    "swift_library",
)
load(
    "//apple:versioning.bzl",
    "apple_bundle_version",
)
load("//apple:visionos.bzl", "visionos_application")

licenses(["notice"])

swift_library(
    name = "ExampleRKContent",
    srcs = [
        "Sources/ExampleRKContent.swift",
    ],
    aspect_hints = ["//apple/hints:realitykit_library_hint"],
    data = [
        "ExampleRKContent.rkassets/Immersive.usda",
        "ExampleRKContent.rkassets/Materials/GridMaterial.usda",
        "ExampleRKContent.rkassets/Scene.usda",
    ],
    module_name = "ExampleRKContent",
)

swift_library(
    name = "SampleImmersiveVisionOSAppSources",
    srcs = [
        "Sources/AppModel.swift",
        "Sources/ContentView.swift",
        "Sources/ImmersiveView.swift",
        "Sources/SampleImmersiveVisionOSApp.swift",
        "Sources/ToggleImmersiveSpaceButton.swift",
    ],
    deps = [
        ":ExampleRKContent",
    ],
)

apple_bundle_version(
    name = "RealityKitSampleVersion",
    build_version = "1",
    short_version_string = "1.0",
)

visionos_application(
    name = "RealityKitSample",
    app_icons = ["//examples/resources:VisionAppIcon.xcassets"],
    bundle_id = "com.example.hello-world",
    infoplists = [":Info.plist"],
    minimum_os_version = "2.0",
    version = ":RealityKitSampleVersion",
    deps = [":SampleImmersiveVisionOSAppSources"],
)

build_test(
    name = "RealityKitSampleBuildTest",
    tags = [
    ],
    targets = [
        ":RealityKitSample",
    ],
)
