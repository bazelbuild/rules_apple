"""Compatibility macro for the iOS xctestrun test runner."""

load(
    "//apple/testing/default_runner:apple_xctestrun_runner.bzl",
    "apple_xctestrun_runner",
)

def ios_xctestrun_runner(name, **kwargs):
    """Compatibility alias. Use apple_xctestrun_runner instead."""
    apple_xctestrun_runner(name = name, **kwargs)
