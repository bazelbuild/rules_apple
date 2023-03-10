# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Helper methods for assembling the test targets."""

# Attributes belonging to the bundling rules that should be removed from the test targets.
_BUNDLE_ATTRS = {
    x: None
    for x in [
        "additional_contents",
        "deps",
        "bundle_id",
        "bundle_name",
        "families",
        "frameworks",
        "infoplists",
        "linkopts",
        "minimum_os_version",
        "provisioning_profile",
        "resources",
        "test_host",
    ]
}

_SHARED_SUITE_TEST_ATTRS = {
    x: None
    for x in [
        "compatible_with",
        "deprecation",
        "distribs",
        "features",
        "licenses",
        "restricted_to",
        "tags",
        "testonly",
        "visibility",
    ]
}

def _assemble(name, bundle_rule, test_rule, runner = None, runners = None, **kwargs):
    """Assembles the test bundle and test targets.

    This method expects that either `runner` or `runners` is populated, but never both. If `runner`
    is given, then a single test target will be created under the given name. If `runners` is given
    then a test target will be created for each runner and a single `test_suite` target will be
    created under the given name, wrapping the created targets.

    The `kwargs` dictionary will contain both bundle and test attributes that this method will split
    accordingly.

    Attrs:
        name: The name of the test target or test suite to create.
        bundle_rule: The bundling rule to instantiate.
        test_rule: The test rule to instantiate.
        runner: A single runner target to use for the test target. Mutually exclusive with
            `runners`.
        runners: A list of runner targets to use for the test targets. Mutually exclusive with
            `runner`.
        **kwargs: The complete list of attributes to distribute between the bundle and test targets.
    """
    if runner != None and runners != None:
        fail("Can't specify both runner and runners.")
    elif not runner and not runners:
        fail("Must specify one of runner or runners.")

    test_bundle_name = name + ".__internal__.__test_bundle"

    test_attrs = {k: v for (k, v) in kwargs.items() if k not in _BUNDLE_ATTRS}
    bundle_attrs = {k: v for (k, v) in kwargs.items() if k in _BUNDLE_ATTRS}

    # Args to apply to the test and the bundle.
    for x in ("visibility", "tags", "features"):
        if x in test_attrs:
            bundle_attrs[x] = test_attrs[x]

    if "bundle_name" in kwargs:
        fail("bundle_name is not supported in test rules.")

    # Ideally this target should be private, but the outputs should not be private, so we're
    # explicitly using the same visibility as the test (or None if none was set).
    bundle_rule(
        name = test_bundle_name,
        bundle_name = name,
        test_bundle_output = "{}.zip".format(name),
        testonly = True,
        **bundle_attrs
    )

    if runner:
        test_rule(
            name = name,
            runner = runner,
            test_host = bundle_attrs.get("test_host"),
            deps = [":{}".format(test_bundle_name)],
            **test_attrs
        )
    elif runners:
        tests = []
        for runner in runners:
            test_name = "{}_{}".format(name, runner.rsplit(":", 1)[-1])
            tests.append(":{}".format(test_name))
            test_rule(
                name = test_name,
                runner = runner,
                test_host = bundle_attrs.get("test_host"),
                deps = [":{}".format(test_bundle_name)],
                **test_attrs
            )
        shared_test_suite_attrs = {k: v for (k, v) in test_attrs.items() if k in _SHARED_SUITE_TEST_ATTRS}
        native.test_suite(
            name = name,
            tests = tests,
            **shared_test_suite_attrs
        )

apple_test_assembler = struct(
    assemble = _assemble,
)
