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


def _matching_providers(target_or_targets, name):
  """Returns a list of providers with the given name from the given target(s).

  Args:
    target_or_targets: A target or list of targets whose providers should be
        searched.
    name: The name of the provider to return.
  Returns:
    A list of providers from the given targets. This list may have fewer
    elements than the given number of targets (including being empty) if not all
    targets propagate the provider.
  """
  if type(target_or_targets) == type([]):
    targets = target_or_targets
  else:
    targets = [target_or_targets]
  return [getattr(x, name) for x in targets if hasattr(x, name)]


# Define the loadable module that lists the exported symbols in this file.
provider_support = struct(
    matching_providers=_matching_providers,
)
