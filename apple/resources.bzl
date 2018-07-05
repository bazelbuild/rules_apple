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

"""Rules related to Apple resources and resource bundles."""

def objc_bundle_library(**kwargs):
    """Creates an `objc_bundle_library` target.

    This rule is a placeholder that will be updated after everyone has migrated
    to the Skylark rules and the native rule has been deleted.

    Args:
      **kwargs: Arguments that will be passed directly into the native
          `objc_bundle_library` rule.
    """
    native.objc_bundle_library(**kwargs)
