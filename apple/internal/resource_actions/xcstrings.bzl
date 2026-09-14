"""xcstrings related actions."""

load(
    "@apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "//apple/internal/utils:xctoolrunner.bzl",
    xctoolrunner_support = "xctoolrunner",
)

def compile_xcstrings(
        *,
        actions,
        mac_exec_group,
        input_file,
        output_dir,
        platform_prerequisites,
        xctoolrunner):
    args = [
        "xcstringstool",
        "compile",
        "--output-directory",
        xctoolrunner_support.prefixed_path(output_dir.path),
        xctoolrunner_support.prefixed_path(input_file.path),
    ]

    apple_support.run(
        actions = actions,
        apple_fragment = platform_prerequisites.apple_fragment,
        arguments = args,
        exec_group = mac_exec_group,
        executable = xctoolrunner,
        inputs = [input_file],
        mnemonic = "CompileXCStrings",
        outputs = [output_dir],
        xcode_config = platform_prerequisites.xcode_version_config,
    )
