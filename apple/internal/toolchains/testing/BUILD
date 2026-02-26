load(
    "//apple/build_settings:build_settings.bzl",
    "build_settings_labels",
)
load(
    "//apple/internal/toolchains:apple_toolchains.bzl",
    "apple_mac_tools_toolchain",
    "apple_xplat_tools_toolchain",
)

toolchain(
    name = "apple_xplat_toolchain",
    toolchain = ":xplat_tools_toolchain",
    toolchain_type = "//apple/internal/toolchains:apple_xplat_toolchain_type",
)

apple_xplat_tools_toolchain(
    name = "xplat_tools_toolchain",
    build_settings = build_settings_labels.all_labels,
    bundletool = "//tools/bundletool",
    bundletool_swift = "//tools/bundletool",
    plisttool = "//tools/plisttool:plisttool.par",
    swiftstdlibstubtool = "//tools/swiftstdlibstubtool",
    verifystringstool = "//tools/verifystringstool",
    versiontool = "//tools/versiontool",
)

toolchain(
    name = "mac_toolchain_declaration",
    toolchain = ":mac_tools_toolchain",
    toolchain_type = "//apple/internal/toolchains:mac_tools_toolchain_type",
)

apple_mac_tools_toolchain(
    name = "mac_tools_toolchain",
    bundletool_mac = "//tools/bundletool:bundletool_osx",
    clangrttool = "//tools/clangrttool:clangrttool_osx",
    codesigningtool = "//tools/codesigningtool:codesigntool_osx",
    dossier_codesigningtool = "//tools/dossier_codesigning_reader:dossier_code_sign_tool_swift_osx",
    environment_plist_tool = "//tools/environment_plist",
    imported_dynamic_framework_processor = "//tools/imported_dynamic_framework_processor:imported_framework_processor_osx",
    plisttool = "//tools/plisttool:plisttool.par",
    process_and_sign_template = "//tools/bundletool:process_and_sign_template",
    provisioning_profile_tool = "//tools/provisioning_profile_tool:provisioning_profile_tool_osx",
    signature_tool = "//tools/signaturetool:signature_tool_osx",
    swift_stdlib_tool = "//tools/swift_stdlib_tool:swift_stdlib_tool_osx",
    xcframework_processor_tool = "//tools/xcframework_processor_tool:xcframework_processor_tool_osx",
    xctoolrunner_alternative = "//tools/xctoolrunner:xctoolrunner_osx",
)
