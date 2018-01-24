#!/bin/bash


# Copyright 2017 The Bazel Authors. All rights reserved.
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

set -eu

# Integration tests for Swift libraries.

function set_up() {
  mkdir -p ios
}

function tear_down() {
  rm -rf ios
}

function test_objc_depends_on_swift() {
  cat >ios/main.swift <<EOF
import Foundation

@objc public class Foo: NSObject {
  public func bar() -> Int { return 42; }
}
EOF

  cat >ios/app.m <<EOF
#import <UIKit/UIKit.h>
#import "ios/SwiftMain-Swift.h"

int main(int argc, char *argv[]) {
  @autoreleasepool {
    NSLog(@"%d", [[[Foo alloc] init] bar]);
    return UIApplicationMain(argc, argv, nil, nil);
  }
}
EOF

  cat >ios/BUILD <<EOF
load("@build_bazel_rules_apple//apple:swift.bzl",
     "swift_library")

swift_library(name = "SwiftMain",
              srcs = ["main.swift"])

objc_library(name = "app",
             srcs = ["app.m"],
             deps = [":SwiftMain"])

apple_binary(name = "bin",
             minimum_os_version = "8.0",
             platform_type = "ios",
             deps = [":app"])
EOF

  do_build ios //ios:bin || fail "should build"
}

function test_swift_imports_objc() {
  cat >ios/main.swift <<EOF
import Foundation
import ios_ObjcLib

public class SwiftClass {
  public func bar() -> String {
    return ObjcClass().foo()
  }
}
EOF

  cat >ios/ObjcClass.h <<EOF
#import <Foundation/Foundation.h>

#if !DEFINE_FOO
#error "Define is not passed in"
#endif

#if !COPTS_FOO
#error "Copt is not passed in
#endif

@interface ObjcClass : NSObject
- (NSString *)foo;
@end
EOF

  cat >ios/ObjcClass.m <<EOF
#import "ObjcClass.h"
@implementation ObjcClass
- (NSString *)foo { return @"Hello ObjcClass"; }
@end
EOF

  cat >ios/BUILD <<EOF
load("@build_bazel_rules_apple//apple:swift.bzl",
     "swift_library")

swift_library(name = "swift_lib",
              srcs = ["main.swift"],
              deps = [":ObjcLib"])

objc_library(name = "ObjcLib",
             hdrs = ['ObjcClass.h'],
             srcs = ['ObjcClass.m'],
             defines = ["DEFINE_FOO=1"])
EOF

  do_build ios --objccopt=-DCOPTS_FOO=1 --subcommands \
      //ios:swift_lib || fail "should build"
}

function test_swift_imports_swift() {
  cat >ios/main.swift <<EOF
import Foundation
import ios_util

public class SwiftClass {
  public func bar() -> String {
    return Utility().foo()
  }
}
EOF

  cat >ios/Utility.swift <<EOF
public class Utility {
  public init() {}
  public func foo() -> String { return "foo" }
}
EOF

  cat >ios/BUILD <<EOF
load("@build_bazel_rules_apple//apple:swift.bzl",
     "swift_library")

swift_library(name = "swift_lib",
              srcs = ["main.swift"],
              deps = [":util"])

swift_library(name = "util",
              srcs = ['Utility.swift'])
EOF

  do_build ios //ios:swift_lib || fail "should build"
}

function test_swift_compilation_mode_flags() {
  cat >ios/debug.swift <<EOF
// A trick to break compilation when DEBUG is not set.
func foo() {
  #if DEBUG
  var x: Int
  #endif
  x = 3
}
EOF

  cat >ios/BUILD <<EOF
load("@build_bazel_rules_apple//apple:swift.bzl",
     "swift_library")

swift_library(name = "swift_lib",
              srcs = ["debug.swift"])
EOF

  ! do_build ios -c opt //ios:swift_lib || fail "should not build"
  expect_log "error: use of unresolved identifier 'x'"

  do_build ios -c dbg //ios:swift_lib || fail "should build"
}

function test_swift_defines() {
  touch ios/dummy.swift

  cat >ios/main.swift <<EOF
import Foundation

public class SwiftClass {
  public func bar() {
    #if !FLAG
    let x: String = 1 // Invalid statement, should throw compiler error when FLAG is not set
    #endif

    #if !DEP_FLAG
    let x: String = 2 // Invalid statement, should throw compiler error when DEP_FLAG is not set
    #endif
  }
}
EOF

  cat >ios/BUILD <<EOF
load("@build_bazel_rules_apple//apple:swift.bzl",
     "swift_library")

swift_library(name = "dep_lib",
              srcs = ["dummy.swift"],
              defines = ["DEP_FLAG"])

swift_library(name = "swift_lib",
              srcs = ["main.swift"],
              defines = ["FLAG"],
              deps = [":dep_lib"])
EOF

  do_build ios //ios:swift_lib || fail "should build"
}

function test_swift_no_object_file_collisions() {
  touch ios/foo.swift

  cat >ios/BUILD <<EOF
load("@build_bazel_rules_apple//apple:swift.bzl",
     "swift_library")

swift_library(name = "Foo",
              srcs = ["foo.swift"])
swift_library(name = "Bar",
              srcs = ["foo.swift"])
EOF

  do_build ios //ios:{Foo,Bar} || fail "should build"
}

function test_minimum_os_passed_to_swiftc() {
  touch ios/foo.swift

  cat >ios/BUILD <<EOF
load("@build_bazel_rules_apple//apple:swift.bzl",
     "swift_library")

swift_library(name = "foo",
              srcs = ["foo.swift"])
EOF

  do_build ios --ios_minimum_os=9.0 --announce_rc \
      //ios:foo || fail "should build"

  # Get the min OS version encoded as "version" argument of
  # LC_VERSION_MIN_IPHONEOS load command in Mach-O
  MIN_OS=$(otool -l test-genfiles/ios/foo/_objs/ios_foo.a | \
      grep -A 3 LC_VERSION_MIN_IPHONEOS | grep version | cut -d " " -f4)
  assert_equals $MIN_OS "9.0"
}

function test_swift_copts() {
  cat >ios/main.swift <<EOF
import Foundation

public class SwiftClass {
  public func bar() {
    #if !FLAG
    let x: String = 1 // Invalid statement, should throw compiler error when FLAG is not set
    #endif

    #if !CMD_FLAG
    let y: String = 1 // Invalid statement, should throw compiler error when CMD_FLAG is not set
    #endif
  }
}
EOF

cat >ios/BUILD <<EOF
load("@build_bazel_rules_apple//apple:swift.bzl",
     "swift_library")

swift_library(name = "swift_lib",
              srcs = ["main.swift"],
              copts = ["-DFLAG"])
EOF

  do_build ios --swiftcopt=-DCMD_FLAG \
      //ios:swift_lib || fail "should build"
}

function test_swift_bitcode() {
  cat >ios/main.swift <<EOF
func f() {}
EOF

cat >ios/BUILD <<EOF
load("@build_bazel_rules_apple//apple:swift.bzl",
     "swift_library")

swift_library(name = "swift_lib",
              srcs = ["main.swift"])
EOF

  ARCHIVE=test-genfiles/ios/swift_lib/_objs/ios_swift_lib.a

  # No bitcode
  do_build ios --ios_multi_cpus=arm64 \
      //ios:swift_lib >$TEST_log 2>&1 || fail "should build"
  ! otool -l $ARCHIVE | grep __bitcode -sq \
      || fail "expected a.o to not contain bitcode"

  # Bitcode marker
  do_build ios --apple_bitcode=embedded_markers --ios_multi_cpus=arm64 \
      //ios:swift_lib || fail "should build"
  # Bitcode marker has a length of 1.
  assert_equals $(size -m $ARCHIVE | grep __bitcode | cut -d: -f2 | tr -d ' ') "1"

  # Full bitcode
  do_build ios --apple_bitcode=embedded --ios_multi_cpus=arm64 \
      //ios:swift_lib || fail "should build"
  otool -l $ARCHIVE | grep __bitcode -sq \
      || fail "expected a.o to contain bitcode"

  # Bitcode disabled because of simulator architecture
  do_build ios --apple_bitcode=embedded --ios_multi_cpus=x86_64 \
      //ios:swift_lib || fail "should build"
  ! otool -l $ARCHIVE | grep __bitcode -sq \
      || fail "expected a.o to not contain bitcode"
}

function test_swift_name_validation() {
  touch ios/main.swift
  touch ios/main.m

  cat >ios/BUILD <<EOF
load("@build_bazel_rules_apple//apple:swift.bzl",
     "swift_library")

swift_library(name = "swift-lib",
              srcs = ["main.swift"])
EOF

  ! do_build ios //ios:swift-lib || fail "should fail"
  expect_log "Error in target '//ios:swift-lib'"

  cat >ios/BUILD <<EOF
load("@build_bazel_rules_apple//apple:swift.bzl",
     "swift_library")

objc_library(name = "bad-dep", srcs = ["main.m"])

swift_library(name = "swift_lib",
              srcs = ["main.swift"], deps=[":bad-dep"])
EOF

  ! do_build ios //ios:swift_lib || fail "should fail"
  expect_log "Error in target '//ios:bad-dep'"
}

function test_swift_ast_is_recorded() {
  touch ios/main.swift
  cat >ios/dep.swift <<EOF
import UIKit
// Add dummy code so that Swift symbols are exported into final binary, which
// will cause runtime libraries to be packaged into the IPA
class X: UIViewController {}
EOF

  cat >ios/main.m <<EOF
#import <UIKit/UIKit.h>

int main(int argc, char *argv[]) {
  @autoreleasepool {
    return UIApplicationMain(argc, argv, nil, nil);
  }
}
EOF

  cat >ios/BUILD <<EOF
load("@build_bazel_rules_apple//apple:swift.bzl",
     "swift_library")

swift_library(name = "dep",
              srcs = ["dep.swift"])

swift_library(name = "swift_lib",
              srcs = ["main.swift"],
              deps = [":dep"])

objc_library(name = "main",
             srcs = ["main.m"])

apple_binary(name = "bin",
             minimum_os_version = "8.0",
             platform_type = "ios",
             deps = [":main", ":swift_lib"])
EOF

  do_build ios --subcommands //ios:bin || fail "should build"
  expect_log "-Xlinker -add_ast_path -Xlinker [^/]*-out/[^/]*/genfiles/ios/dep/_objs/ios_dep\.swiftmodule"
  expect_log "-Xlinker -add_ast_path -Xlinker [^/]*-out/[^/]*/genfiles/ios/swift_lib/_objs/ios_swift_lib\.swiftmodule"
}

function test_swiftc_script_mode() {
  touch ios/foo.swift

  cat >ios/top.swift <<EOF
print() // Top level expression outside of main.swift, should fail.
EOF

  cat >ios/main.swift <<EOF
import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {}

#if swift(>=3)
UIApplicationMain(
  CommandLine.argc,
  UnsafeMutableRawPointer(CommandLine.unsafeArgv)
    .bindMemory(
      to: UnsafeMutablePointer<Int8>.self,
      capacity: Int(CommandLine.argc)),
  nil,
  NSStringFromClass(AppDelegate.self)
)
#else
UIApplicationMain(
  Process.argc, UnsafeMutablePointer<UnsafeMutablePointer<CChar>>(Process.unsafeArgv),
  nil, NSStringFromClass(AppDelegate)
)
#endif
EOF

cat >ios/BUILD <<EOF
load("@build_bazel_rules_apple//apple:swift.bzl",
     "swift_library")

swift_library(name = "main_should_compile_as_script",
              srcs = ["main.swift", "foo.swift"])
swift_library(name = "top_should_not_compile_as_script",
              srcs = ["top.swift"])
swift_library(name = "single_source_should_compile_as_library",
              srcs = ["foo.swift"])
EOF

  do_build ios \
      //ios:single_source_should_compile_as_library \
      //ios:main_should_compile_as_script || fail "should build"

  ! do_build ios \
      //ios:top_should_not_compile_as_script || fail "should not build"
  expect_log "ios/top.swift:1:1: error: expressions are not allowed at the top level"
}

# Test that it's possible to import Clang module of a target that contains private headers.
function test_import_module_with_private_hdrs() {
  touch ios/Foo.h ios/Foo_Private.h

  cat >ios/main.swift <<EOF
import ios_lib
EOF

  cat >ios/BUILD <<EOF
load("@build_bazel_rules_apple//apple:swift.bzl",
     "swift_library")

objc_library(name = "lib",
             srcs = ["Foo_Private.h"],
             hdrs = ["Foo.h"])

swift_library(name = "swiftmodule",
              srcs = ["main.swift"],
              deps = [":lib"])
EOF
  do_build ios //ios:swiftmodule || fail "should build"
}

function test_swift_wmo_short() {
  echo 'class SwiftClass { func bar() -> Int { return 1 } }' > ios/main.swift

  cat >ios/BUILD <<EOF
load("@build_bazel_rules_apple//apple:swift.bzl",
     "swift_library")

swift_library(name = "swift_lib_copt_wmo_short",
              srcs = ["main.swift"],
              copts = ["-wmo"])
EOF

  do_build ios //ios:swift_lib_copt_wmo_short -s || fail "should build"
  expect_log "-num-threads"
  expect_log "-wmo"
}

function test_swift_wmo_long() {
  echo 'class SwiftClass { func bar() -> Int { return 1 } }' > ios/main.swift

cat >ios/BUILD <<EOF
load("@build_bazel_rules_apple//apple:swift.bzl",
     "swift_library")

swift_library(name = "swift_lib_copt_wmo_short_long",
              srcs = ["main.swift"],
              copts = ["-whole-module-optimization"])
EOF

  do_build ios //ios:swift_lib_copt_wmo_short_long -s || fail "should build"
  expect_log "-num-threads"
  expect_log "-whole-module-optimization"
}

function test_swift_wmo_flag() {
  echo 'class SwiftClass { func bar() -> Int { return 1 } }' > ios/main.swift

  cat >ios/BUILD <<EOF
load("@build_bazel_rules_apple//apple:swift.bzl",
     "swift_library")

swift_library(name = "swift_lib_copt_wmo_flag",
              srcs = ["main.swift"])
EOF

  do_build ios //ios:swift_lib_copt_wmo_flag -s \
      --swift_whole_module_optimization || fail "should build"
  expect_log "-num-threads"
  expect_log "-whole-module-optimization"
}

function test_swift_dsym() {
  cat >ios/main.swift <<EOF
import Foundation

public class SwiftClass {
  public func bar() -> String { return "foo" } }
EOF

  cat >ios/BUILD <<EOF
load("@build_bazel_rules_apple//apple:swift.bzl",
     "swift_library")

swift_library(name = "swift_lib",
              srcs = ["main.swift"])
EOF

  do_build ios -c opt --apple_generate_dsym \
      //ios:swift_lib || fail "should build"

  # Verify that debug info is present.
  dwarfdump -R test-genfiles/ios/swift_lib/_objs/ios_swift_lib.a \
      | grep -sq "__DWARF" \
      || fail "should contain DWARF data"
}

# Verifies that a swift module's name has no prefixes when it is defined at the root of
# the workspace.
function test_swift_module_name_at_root() {
  echo 'public class SwiftClass { func bar() -> Int { return 1 } }' > dep.swift
  echo 'import swift_module_name_at_root_dep' > main.swift

  cat >BUILD <<EOF
load("@build_bazel_rules_apple//apple:swift.bzl",
     "swift_library")

swift_library(name = "swift_module_name_at_root_dep",
              srcs = ["dep.swift"])
swift_library(name = "swift_module_name_at_root",
              srcs = ["main.swift"],
              deps = [":swift_module_name_at_root_dep"])
EOF

  do_build ios //:swift_module_name_at_root -s || fail "should build"

  rm dep.swift
  rm main.swift
  rm BUILD
}

run_suite "swift_library tests"
