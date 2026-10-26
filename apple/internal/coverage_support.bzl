# Copyright 2026 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Support for collecting the binaries that `llvm-cov` needs to report coverage for Apple tests.

The coverage mapping data for an Apple test is spread across several Mach-O images: the test
bundle's binary, its test host's binary, and the binary of every framework that they embed. Bazel's
coverage support (`collect_coverage.sh`) expects to be told about all of them through the
`TEST_BINARIES_FOR_LLVM_COV` environment variable, and has no standard provider to collect them
transitively. Bundling rules that embed other bundles propagate a private provider with the binaries
of the bundles that they embed, so that the test rule can read the full set from the test bundle.
"""

load(
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "AppleBundleInfo",
)

visibility("@build_bazel_rules_apple//apple/...")

_AppleCoverageBinariesInfo = provider(
    doc = """
Private provider for the binaries of a bundle and of the bundles that it embeds (or, for test
bundles, of its test host), which `llvm-cov` needs to report coverage. Only propagated when coverage
collection is enabled.
""",
    fields = {
        "binaries": """
A `depset` of `File`s referencing the unbundled binaries (`AppleBundleInfo.binary`) of this bundle
and the bundles that it depends on for coverage.
""",
    },
)

def _covered_binaries(target):
    """Returns the binaries that `llvm-cov` needs for the given bundle target.

    Args:
        target: A target that propagates `AppleBundleInfo`.

    Returns:
        A `depset` of `File`s, or `None` if the target has no binaries to report. Bundling rules
        that don't embed other bundles don't propagate the private provider, in which case this
        falls back to the target's own `AppleBundleInfo.binary`.
    """
    if _AppleCoverageBinariesInfo in target:
        return target[_AppleCoverageBinariesInfo].binaries
    if AppleBundleInfo in target and target[AppleBundleInfo].binary:
        return depset([target[AppleBundleInfo].binary])
    return None

def _coverage_binaries_info(*, binary, coverage_enabled, covered_binaries_targets):
    """Returns the providers that propagate binaries for coverage from a bundling rule.

    Args:
        binary: The `File` of the bundle's own unbundled binary (`AppleBundleInfo.binary`), or
            `None` if the bundle has no binary.
        coverage_enabled: Whether coverage collection is enabled, from
            `ctx.configuration.coverage_enabled`.
        covered_binaries_targets: A list of bundle targets whose binaries must be reported with this
            bundle's binary; for example, the bundle's `frameworks` and, for test bundles, its
            `test_host`.

    Returns:
        A list with the private provider if coverage collection is enabled, or an empty list.
    """
    if not coverage_enabled:
        return []

    transitive_binaries = []
    for target in covered_binaries_targets:
        target_binaries = _covered_binaries(target)
        if target_binaries != None:
            transitive_binaries.append(target_binaries)

    return [
        _AppleCoverageBinariesInfo(
            binaries = depset(
                direct = [binary] if binary else [],
                transitive = transitive_binaries,
            ),
        ),
    ]

coverage_support = struct(
    coverage_binaries_info = _coverage_binaries_info,
    covered_binaries = _covered_binaries,
)
