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

"""Support functions for testing Apple apps."""


# List of objc provider fields that are whitelisted to be passed into the
# xctest_app provider's objc provider. This list needs to stay in sync with
# bazel's ReleaseBundlingSupport.java#xcTestAppProvider method.
_WHITELISTED_TEST_OBJC_PROVIDER_FIELDS = [
    "define", "dynamic_framework_file", "framework_dir",
    "dynamic_framework_dir", "framework_search_paths", "header", "include",
    "sdk_dylib", "sdk_framework", "source", "static_framework_file",
    "weak_sdk_framework"]


# TODO(b/36513269): Remove xctest_app_provider once everyone has migrated out
# of native ios_application. This will be replaced by a test specific provider
# coming directly from apple_binary.
def _new_xctest_app_provider(ctx):
  """Returns a newly configured xctest_app provider for the given context."""

  test_objc_params = {}
  for field in _WHITELISTED_TEST_OBJC_PROVIDER_FIELDS:

    if not hasattr(ctx.attr.binary.objc, field):
      # Skip missing attributes from objc provider. This enables us to add
      # fields yet to be released into the list of whitelisted fields that
      # should be propagated by the xctest objc provider.
      continue

    # This is safe to do because the list of fields is static and
    # non-configurable, and because the non presence of a value is signaled by
    # an empty set. Fields that do not yet exist are already filtered at this
    # point.
    field_value = depset(getattr(ctx.attr.binary.objc, field))
    if field_value:
      destination_field = field

      # Filter out swift sdk_dylibs propagated, those are needed only if the
      # tests depend on swift. If it doesn't propagating them will break as the
      # linker will not be able to find them; the necessary linkopt comes from
      # swift_library. If tests require swift dylibs, they will need to
      # explicitly add them to their deps.
      if field == "sdk_dylib":
        field_value = depset([x for x in field_value
                              if not x.startswith("swift")])
        if not field_value:
          # If there are no more values, prevent setting an empty set.
          continue

      # In order to prevent double linking of frameworks in tests, we need to
      # move the framework_dir paths into just search paths in order for tests
      # to compile against the headers.
      if field == "framework_dir" or field == "dynamic_framework_dir":
        destination_field = "framework_search_paths"

      # Merge current values with the values from the binary's objc provider.
      test_objc_params[destination_field] = test_objc_params.get(
          destination_field, depset()) + field_value

  return apple_common.new_xctest_app_provider(
      bundle_loader=ctx.file.binary,
      ipa=ctx.outputs.archive,
      objc_provider=apple_common.new_objc_provider(**test_objc_params))


# Define the loadable module that lists the exported symbols in this file.
test_support = struct(
    new_xctest_app_provider=_new_xctest_app_provider,
)
