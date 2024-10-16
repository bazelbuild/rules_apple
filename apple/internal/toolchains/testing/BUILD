load(
    "//apple/internal/toolchains:apple_toolchains.bzl",
    "apple_mac_tools_toolchain",
)

toolchain(
    name = "mac_toolchain_declaration",
    toolchain = ":mac_tools_toolchain",
    toolchain_type = "//apple/internal/toolchains:mac_tools_toolchain_type",
)

apple_mac_tools_toolchain(
    name = "mac_tools_toolchain",
    bundletool_experimental = "//tools/bundletool:bundletool_experimental",
    clangrttool = "//tools/clangrttool:clangrttool_osx",
    codesigningtool = "//tools/codesigningtool:codesigntool_osx",
    dossier_codesigningtool = "//tools/dossier_codesigningtool",
    dsym_info_plist_template = "//apple/internal/templates:dsym_info_plist_template",
    environment_plist_tool = "//tools/environment_plist",
    imported_dynamic_framework_processor = "//tools/imported_dynamic_framework_processor:imported_framework_processor_osx",
    plisttool = "//tools/plisttool",
    process_and_sign_template = "//tools/bundletool:process_and_sign_template",
    provisioning_profile_tool = "//tools/provisioning_profile_tool",
    signature_tool = "//tools/signaturetool:signature_tool_osx",
    swift_stdlib_tool = "//tools/swift_stdlib_tool",
    xcframework_processor_tool = "//tools/xcframework_processor_tool:xcframework_processor_tool_osx",
    xctoolrunner = "//tools/xctoolrunner",
)
