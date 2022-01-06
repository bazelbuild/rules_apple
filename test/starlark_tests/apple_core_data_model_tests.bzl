# Copyright 2021 The Bazel Authors. All rights reserved.
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

"""apple_core_data_model Starlark tests."""

load(
    ":rules/analysis_target_outputs_test.bzl",
    "analysis_target_outputs_test",
)
load(
    "@bazel_skylib//lib:unittest.bzl",
    "analysistest",
    "asserts",
)
load(
    "@bazel_skylib//lib:new_sets.bzl",
    "sets",
)

def _analysis_registered_actions_and_mnemonic_impl(ctx):
    """Tests registers one action per data model file and a single mnemonic."""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    target_actions = analysistest.target_actions(env)
    target_files = target_under_test[DefaultInfo].files.to_list()
    target_mnemonics_set = sets.make([a.mnemonic for a in target_actions])
    target_mnemonics = sets.to_list(target_mnemonics_set)

    asserts.equals(env, len(target_files), len(target_actions))
    asserts.equals(env, 1, len(target_mnemonics))
    asserts.equals(env, "MomGenerate", target_mnemonics[0])
    return analysistest.end(env)

_analysis_registered_actions_and_mnemonic_test = analysistest.make(
    _analysis_registered_actions_and_mnemonic_impl,
)

def apple_core_data_model_test_suite(name):
    """Test suite for apple_bundle_version.

    Args:
      name: the base name to be used in things created by this macro
    """

    # Test outputs a directory (non-empty assertion is verified by xctoolrunner).
    analysis_target_outputs_test(
        name = "{}_outputs_swift_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:swift_data_model",
        expected_outputs = ["swift_datamodel.swift_data_model.coredata.sources"],
        tags = [name],
    )
    analysis_target_outputs_test(
        name = "{}_outputs_objc_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:objc_data_model",
        expected_outputs = ["objc_datamodel.objc_data_model.coredata.sources"],
        tags = [name],
    )
    analysis_target_outputs_test(
        name = "{}_outputs_swift_and_objc_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:combined_swift_objc_data_model",
        expected_outputs = [
            "swift_datamodel.combined_swift_objc_data_model.coredata.sources",
            "objc_datamodel.combined_swift_objc_data_model.coredata.sources",
        ],
        tags = [name],
    )

    # Test no code generation data model outputs empty folder (i.e. fails).
    analysis_target_outputs_test(
        name = "{}_has_no_outputs_no_code_generation_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:no_code_generation_data_model",
        expected_outputs = [],
        tags = [name],
    )

    # Test registered actions and mnemonics for Obj-C and Swift data models.
    _analysis_registered_actions_and_mnemonic_test(
        name = "{}_actions_swift_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:swift_data_model",
        tags = [name],
    )
    _analysis_registered_actions_and_mnemonic_test(
        name = "{}_actions_objc_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:objc_data_model",
        tags = [name],
    )
    _analysis_registered_actions_and_mnemonic_test(
        name = "{}_actions_swift_and_objc_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:combined_swift_objc_data_model",
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
