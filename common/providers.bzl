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


def _find_all(target_or_targets, name_or_provider):
  """Returns a list with all of the given provider from one or more targets.

  This function supports legacy providers (referenced by name) and modern
  providers (referenced by their provider object).

  Args:
    target_or_targets: A target or list of targets whose providers should be
        searched. This argument may also safely be None, which causes the empty
        list to be returned.
    name_or_provider: The string name of the legacy provider or the reference
        to a modern provider to return.

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

  # If name_or_provider is a string, find it as a legacy provider.
  if type(name_or_provider) == type(""):
    return [getattr(x, name_or_provider) for x in targets
            if hasattr(x, name_or_provider)]

  # Otherwise, find it as a modern provider.
  return [x[name_or_provider] for x in targets if name_or_provider in x]


# Define the loadable module that lists the exported symbols in this file.
providers = struct(
    find_all=_find_all,
)
