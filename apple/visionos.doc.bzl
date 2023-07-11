"""# Bazel rules for creating visionOS applications and bundles."""

# Re-export original rules rather than their wrapper macros
# so that stardoc documents the rule attributes, not an opaque
# **kwargs argument.
load(
    "@build_bazel_rules_apple//apple/internal/testing:visionos_rules.bzl",
    _visionos_ui_test = "visionos_ui_test",
    _visionos_unit_test = "visionos_unit_test",
)
load(
    "@build_bazel_rules_apple//apple/internal:visionos_rules.bzl",
    _visionos_application = "visionos_application",
    _visionos_dynamic_framework = "visionos_dynamic_framework",
    _visionos_framework = "visionos_framework",
    _visionos_static_framework = "visionos_static_framework",
)
load(
    "@build_bazel_rules_apple//apple:visionos.bzl",
    _visionos_build_test = "visionos_build_test",
)

visionos_application = _visionos_application
visionos_dynamic_framework = _visionos_dynamic_framework
visionos_framework = _visionos_framework
visionos_static_framework = _visionos_static_framework
visionos_ui_test = _visionos_ui_test
visionos_unit_test = _visionos_unit_test
visionos_build_test = _visionos_build_test
