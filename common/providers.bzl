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

"""Support functions for working with providers in build rules."""

def _find_all(target_or_targets, provider_ref):
    """Returns a list with all of the given provider from one or more targets.

    Args:
      target_or_targets: A target or list of targets whose providers should be
          searched. This argument may also safely be None, which causes the empty
          list to be returned.
      provider_ref: The reference to the provider to return.

    Returns:
      A list of providers from the given targets. This list may have fewer
      elements than the given number of targets (including being empty) if not all
      targets propagate the provider.
    """
    if not target_or_targets:
        return []

    if type(target_or_targets) == type([]):
        targets = target_or_targets
    else:
        targets = [target_or_targets]

    return [x[provider_ref] for x in targets if provider_ref in x]

# Define the loadable module that lists the exported symbols in this file.
providers = struct(
    find_all = _find_all,
)
