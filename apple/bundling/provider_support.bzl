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


def _binary_or_deps_providers(ctx, name):
  """Returns the providers with the given name for a target's binary or deps.

  Some Apple bundling rules unconditionally take a binary, some conditionally
  can take a binary or omit it, and some unconditionally don't take a binary
  under any circumstances. Because of these differences, we may need to access
  dependencies' providers from either the `binary` attribute or the `deps`.
  This function checks for the existence of a binary first and, if present,
  returns the matching providers from that target. Otherwise, it returns the
  matching providers from the direct `deps` of that target. (It is the
  responsibility of those deps' rules/aspects to propagate information
  transitively as needed.)

  Args:
    ctx: The Skylark context.
    name: The name of the provider to return.
  Returns:
    A list of providers from the current target's binary or deps.
  """
  if hasattr(ctx.attr, "binary") and ctx.attr.binary:
    return _matching_providers([ctx.attr.binary], name)
  return _matching_providers(ctx.attr.deps, name)


def _matching_providers(targets, name):
  """Returns a list of providers with the given name from a list of targets.

  Args:
    targets: The list of targets whose providers should be searched.
    name: The name of the provider to return.
  Returns:
    A list of providers from the given targets. This list may have fewer
    elements than `targets` (including being empty) if not all targets
    propagate the named provider.
  """
  return [getattr(x, name) for x in targets if hasattr(x, name)]


# Define the loadable module that lists the exported symbols in this file.
provider_support = struct(
    binary_or_deps_providers=_binary_or_deps_providers,
    matching_providers=_matching_providers,
)
