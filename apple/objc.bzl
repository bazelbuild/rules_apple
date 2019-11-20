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

"""Bazel rules for Objective-C."""

load(
    "@build_bazel_rules_apple//apple/internal:objc_rules.bzl",
    _objc_category_linkage_file = "objc_category_linkage_file",
)

def objc_category_library(name, **kwargs):
    """Builds a library of Objective-C categories.

    Objective-C categories require special linkage, especially in an environment
    where -ObjC is not being passed as a linker flag. This rule enforces proper
    linkage for Objective-C categories in all cases.

    It also defines a unique symbol so that the linker does not generate
    warnings at link time for static libraries with no symbols in them
    (Objective-C categories do not generate symbols on their own).

    The file names in `srcs` are expected to conform to standard Objective-C
    conventions for categories; that is `PREFoo+bar.m` where `PREFoo` is the
    class that the category `bar` is being added to.

    Args:
      name: The name of the library.
      **kwargs: Additional arguments passed directly to the objc_library rule.
    """
    if kwargs.get("alwayslink") != None:
        fail("alwayslink is default for objc_category_library")
    for src in kwargs.get("srcs", default = []):
        if src.find("+") == -1:
            fail("only categories in objc_category_library", src)
    for src in kwargs.get("non_arc_srcs", default = []):
        if src.find("+") == -1:
            fail("only categories in objc_category_library", src)

    unique_symbol_file = "{}_UniqueSymbol".format(name)
    _objc_category_linkage_file(name = unique_symbol_file)
    kwargs["srcs"] = kwargs.get("srcs", []) + [":{}.c".format(unique_symbol_file)]
    native.objc_library(name = name, alwayslink = True, **kwargs)
