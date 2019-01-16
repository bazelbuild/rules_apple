#!/bin/bash

# Copyright 2018 The Bazel Authors. All rights reserved.
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

# Integration tests for bundling simple macOS kernel extensions.

function set_up() {
  mkdir -p app
}

function tear_down() {
  rm -rf app
}

# Required for OSS testing, as the kernel test is disabled and the test
# runner chokes when there are no tests in the suite.
# TODO(b/117147764): Remove this empty test.
function test_pass() {
  :
}

function disabled_test_kernel_extension() {  # Blocked on b/117147764
  mkdir -p kext

  cat > kext/kext-builder_info.cc <<EOF
#include <mach/mach_types.h>

extern "C" {
extern kern_return_t _start(kmod_info_t *ki, void *data);
extern kern_return_t _stop(kmod_info_t *ki, void *data);

__attribute__((visibility("default")))
KMOD_EXPLICIT_DECL(com.google.kext_builder, "1.0.0d1", _start,
                   _stop) __private_extern__ kmod_start_func_t *_realmain = 0;
__private_extern__ kmod_stop_func_t *_antimain = 0;
__private_extern__ int _kext_apple_cc = __APPLE_CC__;
}
EOF

  cat > kext/KextBuilder.h <<EOF
#include <IOKit/IOService.h>
#include <libkern/OSKextLib.h>

class com_google_KextBuilder : public IOService {
  OSDeclareDefaultStructors(com_google_KextBuilder);

public:
  ///  Called by the kernel when the kext is loaded
  bool start(IOService *provider) override;

  ///  Called by the kernel when the kext is unloaded
  void stop(IOService *provider) override;
};
EOF

cat > kext/KextBuilder.cc <<EOF
#include "KextBuilder.h"

#include <IOKit/IOLib.h>

#define super IOService
#define KextBuilder com_google_KextBuilder

OSDefineMetaClassAndStructors(com_google_KextBuilder, IOService);

bool KextBuilder::start(IOService *provider) {
  if (!super::start(provider)) return false;
  registerService();
  IOLog("Loaded, version %s.", OSKextGetCurrentVersionString());
  return true;
}

void KextBuilder::stop(IOService *provider) {
  IOLog("Unloaded.");
  super::stop(provider);
}

#undef super
EOF

  cat > kext/kext-builder-Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$(EXECUTABLE_NAME)</string>
  <key>CFBundleIdentifier</key>
  <string>com.google.kext-builder</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$(PRODUCT_NAME)</string>
  <key>CFBundlePackageType</key>
  <string>KEXT</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>IOKitPersonalities</key>
  <dict/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2018 Google. All rights reserved.</string>
  <key>OSBundleLibraries</key>
  <dict/>
</dict>
</plist>
EOF

  cat > kext/BUILD <<EOF
load("@build_bazel_rules_apple//apple:macos.bzl", "macos_kernel_extension")

cc_library(
    name = "kext-builder_lib",
    srcs = [
        "KextBuilder.cc",
        "KextBuilder.h",
        "kext-builder_info.cc",
    ],
    copts = [
        "-mkernel",
        "-fapple-kext",
        "-I__BAZEL_XCODE_SDKROOT__/System/Library/Frameworks/Kernel.framework/PrivateHeaders",
        "-I__BAZEL_XCODE_SDKROOT__/System/Library/Frameworks/Kernel.framework/Headers",
    ],
    alwayslink = 1,
)

macos_kernel_extension(
    name = "kext-builder",
    bundle_id = "com.google.kext-builder",
    infoplists = ["kext-builder-Info.plist"],
    minimum_os_version = "10.13",
    deps = [":kext-builder_lib"],
)
EOF

  do_build macos //kext:kext-builder || fail "Should build"

  assert_zip_contains "test-bin/kext/kext-builder.zip" "kext-builder.kext/"
  unzip "test-bin/kext/kext-builder.zip" -d $TEST_TMPDIR
  file $TEST_TMPDIR/kext-builder.kext/Contents/MacOS/kext-builder > $TEST_TMPDIR/bundle_file.out
  assert_contains "kext bundle" $TEST_TMPDIR/bundle_file.out

  file -b $TEST_TMPDIR/kext-builder.kext/Contents/Info.plist > $TEST_TMPDIR/infoplist_type.out
  assert_contains "XML 1.0 document text" $TEST_TMPDIR/infoplist_type.out
}

run_suite "macos_kernel_extension bundling tests"
