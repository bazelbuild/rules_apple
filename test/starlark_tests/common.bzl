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

"""Common build definitions used by test fixtures."""

visibility("//test/starlark_tests/...")

# Common tags that prevent the test fixtures from actually being built (i.e.,
# their actions executed) when running `bazel test` to do analysis testing.
_fixture_tags = [
    "manual",
    "nobuilder",
    "notap",
]

# The current min_deployment_target for iOS is version 15.0, based on Xcode 27 on Apple's Xcode
# Support page: https://developer.apple.com/support/xcode/, and it is what Apple builds backport
# compatibility libraries with. Anything earlier than 15.0 is likely not going to work with the
#current toolchain.
_min_os_ios = struct(
    app_intents_package_support = "17.0",
    app_intents_support = "16.0",
    cpp_typed_allocator_simulator_support = "18.0",
    icon_bundle_required = "26.0",
    min_deployment_target = "15.0",
    nplus1 = "16.0",
    span_in_os = "26.0",
    test_mismatch_high_threshold = "17.0",
    ui_image_variable_value_support = "16.0",
    widget_configuration_intents_support = "16.0",
)

# The current min_deployment_target for macOS is version 12.0, based on Xcode 27 on Apple's Xcode
# Support page: https://developer.apple.com/support/xcode/
_min_os_macos = struct(
    app_intents_package_support = "14.0",
    app_intents_support = "13.0",
    icon_bundle_required = "26.0",
    min_deployment_target = "12.0",
    nplus1 = "13.0",
    os_27_mandates = "27.0",
)

# The current min_deployment_target for tvOS is version 15.0, based on Xcode 27 on Apple's Xcode
# Support page: https://developer.apple.com/support/xcode/
_min_os_tvos = struct(
    app_intents_package_support = "17.0",
    app_intents_support = "16.0",
    min_deployment_target = "15.0",
    nplus1 = "16.0",
)

_min_os_visionos = struct(
    min_deployment_target = "1.0",
)

# The current min_deployment_target for watchOS is version 9.0, based on Xcode 27 on Apple's Xcode
# Support page: https://developer.apple.com/support/xcode/
_min_os_watchos = struct(
    app_intents_package_support = "10.0",
    app_intents_support = "9.0",
    arm64_support = "26.0",
    icon_bundle_required = "26.0",
    min_deployment_target = "9.0",
    nplus1 = "10.0",
    os_27_mandates = "27.0",
)

def _extract_xcframework_cmd(name):
    cmd = """
rm -rf $(@D)/%{name}
mkdir -p $(@D)/%{name}
has_zip_extracted=0
for f in $(SRCS); do
  if [[ "$$f" == *.xcframework.zip ]]; then
     if unzip -tq "$$f" >&2; then
       unzip -qq -n "$$f" -d $(@D)/%{name}
       has_zip_extracted=1
     else
       echo "Error: Couldn't unzip $$f" >&2
       exit 1
     fi
  fi
done

for f in $(SRCS); do
  if [[ "$$f" == *.xcframework ]] && [ -d "$$f" ] && [ "$$has_zip_extracted" -eq 0 ]; then
    cp -rL "$$f" $(@D)/%{name}/
  fi
done

outs=($(OUTS))
first_out="$${outs[0]}"
if [[ "$$first_out" == *.xcframework/* ]]; then
  src_xcfw=$$(find $(@D)/%{name} -name "*.xcframework" -type d | head -n 1)
  dest_xcfw="$${first_out%%.xcframework/*}.xcframework"
  if [ "$$src_xcfw" != "$$dest_xcfw" ]; then
    cp -a "$$src_xcfw/." "$$dest_xcfw/"
  fi
  expected_arch=""
  for out_file in $(OUTS); do
      if [[ "$$out_file" == *.xcframework/*-*/* ]]; then
          expected_arch=$$(echo "$$out_file" | sed -E 's|.*\\.xcframework/([^/]+)/.*|\\1|')
          break
      fi
  done

  if [ -n "$$expected_arch" ]; then
      actual_arch=$$(ls "$$dest_xcfw" | grep -E "^(macos|ios|tvos|watchos|xros)-" | head -n 1)
      if [ -n "$$actual_arch" ] && [ "$$actual_arch" != "$$expected_arch" ]; then
          if [ ! -e "$$dest_xcfw/$$expected_arch" ]; then
              cp -a "$$dest_xcfw/$$actual_arch" "$$dest_xcfw/$$expected_arch" || true
          fi
      fi
  fi

  # For macOS frameworks, tree artifact copies lose symlinks.
  # Replace missing outs (which were symlinks) with dummy files to satisfy Bazel.
  for out_file in $(OUTS); do
      if [ ! -e "$$out_file" ]; then
          mkdir -p "$$(dirname "$$out_file")"
          echo "dummy" > "$$out_file"
      fi
  done

elif [[ "$$first_out" == *.framework/* ]]; then
  src_fw=$$(find $(@D)/%{name} -name "*.framework" -type d | head -n 1)
  dest_fw="$${first_out%%.framework/*}.framework"
  if [ "$$src_fw" != "$$dest_fw" ]; then
    cp -a "$$src_fw/." "$$dest_fw/"
  fi
elif [[ "$$first_out" == *.xctest/* ]]; then
  src_fw=$$(find $(@D)/%{name} -name "*.xctest" -type d | head -n 1)
  dest_fw="$${first_out%%.xctest/*}.xctest"
  if [ "$$src_fw" != "$$dest_fw" ]; then
    cp -a "$$src_fw/." "$$dest_fw/"
  fi
else
  for out_file in $(OUTS); do
    if [ ! -f "$$out_file" ] && [ ! -d "$$out_file" ]; then
      fname="$$(basename "$$out_file")"
      found_file=$$(find $(@D)/%{name} -name "$$fname" \\( -type f -o -type l \\) | head -n 1)
      if [ -n "$$found_file" ]; then
        cp -L "$$found_file" "$$out_file"
      else
        echo "Error: Expected output file $$fname not found in extracted bundle %{name}" >&2
        exit 1
      fi
    fi
  done
fi
"""
    return cmd.replace("%{name}", name)

common = struct(
    extract_xcframework_cmd = _extract_xcframework_cmd,
    fixture_tags = _fixture_tags,
    min_os_ios = _min_os_ios,
    min_os_macos = _min_os_macos,
    min_os_tvos = _min_os_tvos,
    min_os_visionos = _min_os_visionos,
    min_os_watchos = _min_os_watchos,
)
