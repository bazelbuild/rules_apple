"""Compatibility macro for the iOS xctestrun test runner."""

load(
    "//apple/testing/default_runner:apple_xctestrun_runner.bzl",
    "apple_xctestrun_runner",
)

def ios_xctestrun_runner(name, **kwargs):
    """Compatibility alias. Use apple_xctestrun_runner instead.

    Args:
      name: Name for the runner target.
      **kwargs: Additional keyword arguments forwarded to apple_xctestrun_runner.
    """
    apple_xctestrun_runner(name = name, **kwargs)
