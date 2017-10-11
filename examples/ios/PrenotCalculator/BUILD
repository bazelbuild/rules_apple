# Copyright 2015 The Bazel Authors. All rights reserved.
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

load("//apple:ios.bzl", "ios_application")

licenses(["notice"])

ios_application(
    name = "PrenotCalculator",
    bundle_id = "com.example.prenot-calculator",
    families = ["iphone"],
    infoplists = ["PrenotCalculator-Info.plist"],
    minimum_os_version = "8.0",
    deps = [":PrenotCalculator_library"],
)

objc_library(
    name = "PrenotCalculator_library",
    srcs = [
        "AppDelegate.m",
        "CalculatedValues.m",
        "CalculatorViewController.m",
        "CoreData.m",
        "Equation.m",
        "Literal.m",
        "ValuesViewController.m",
        "main.m",
    ],
    hdrs = glob(
        ["**/*.h"],
        exclude = ["Expression.h"],
    ),
    bundles = [":PrenotCalculatorResources"],
    resources = glob(["DataModel.xcdatamodeld/**"]) + [
        "CalculatorViewController.xib",
    ],
    sdk_frameworks = ["CoreData"],
    deps = [":ExpressionPrebuilt"],
)

# A prebuilt library that contains multiple architectures.
# Currently compiled for: i386, x86_64, armv7.
objc_import(
    name = "ExpressionPrebuilt",
    hdrs = ["Expression.h"],
    archives = [
        "expression_prebuilt.a",
    ],
)

# Don't use this directly, instead use it to construct ExpressionPrebuilt and
# depend on that instead.
# You can build using the following command:
#    for i in armv7 arm64 i386 x86_64; \
#    do output/bazel build --xcode_version=7.2 --ios_sdk_version=9.2 --ios_cpu=$i examples/objc:ExpressionClasses; \
#    mv bazel-bin/examples/objc/libExpressionClasses.a bazel-bin/examples/objc/libExpressionClasses_$i.a; \
#    done; \
#    xcrun lipo -create bazel-bin/examples/objc/libExpressionClasses_{armv7,arm64,i386,x86_64}.a -output bazel-bin/examples/objc/expression_prebuilt.a \
#    cp bazel-bin/examples/objc/expression_prebuilt.a examples/objc/expression_prebuilt.a
# You may need to adjust the xcode_version and ios_sdk_versions as appropriate.
objc_library(
    name = "ExpressionClasses",
    srcs = [
        "Expression.m",
    ],
    hdrs = ["Expression.h"],
)

objc_bundle_library(
    name = "PrenotCalculatorResources",
    resources = glob(["Resources/**"]),
)
