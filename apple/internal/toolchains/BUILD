licenses(["notice"])

toolchain_type(
    name = "mac_tools_toolchain_type",
    visibility = ["//apple/internal:__pkg__"],
)

toolchain(
    name = "mac_toolchain_declaration",
    toolchain = "//apple/internal:mac_tools_toolchain",
    toolchain_type = ":mac_tools_toolchain_type",
)

toolchain_type(
    name = "apple_xplat_toolchain_type",
    visibility = ["//apple/internal:__pkg__"],
)

toolchain(
    name = "apple_xplat_toolchain",
    toolchain = "//apple/internal:xplat_tools_toolchain",
    toolchain_type = ":apple_xplat_toolchain_type",
)
