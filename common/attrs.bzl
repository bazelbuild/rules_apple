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

"""Support functions for working with rule attributes and struct fields."""

# Using a provider as a sentinel here ensures that we always get a unique value
# that can't be equal to anything else the user might pass in. See the
# documentation for `attrs.get` for more on this value.
_private_fallback = provider()

def _get(obj, attr_name, default = None):
    """Safely gets the value of an attribute on an object.

    Args:
      obj: The object whose attribute should be retrieved.
      attr_name: The name of the attribute to retrieve.
      default: The default value to return if the attribute was not found. If this
          argument is equal to `attrs.private_fallback`, then the function will
          look for a field of the same name but prefixed with an underscore (a
          technique used to provide hard-coded defaults in rule declarations). If
          the underscore-prefixed version of the attribute does not exist, this is
          considered an internal consistency error and the function will fail.

    Returns:
      The value of the attribute, or the default if the attribute is not set.
    """
    if hasattr(obj, attr_name):
        return getattr(obj, attr_name, default)

    if default == _private_fallback:
        private_name = "_" + attr_name
        if hasattr(obj, private_name):
            return getattr(obj, private_name)

        fail(("Internal error: Attribute '%s' was not defined publicly on the " +
              "rule so it must be defined privately, but it was not") % attr_name)

    return default

def _get_as_list(obj, attr_name, default = None):
    """Safely gets the value of an attribute on an object, wrapped in a list.

    Args:
      obj: The object whose attribute should be retrieved.
      attr_name: The name of the attribute to retrieve.
      default: The default value to return if the attribute was not found. If this
          argument is equal to `attrs.private_fallback`, then the function will
          look for a field of the same name but prefixed with an underscore (a
          technique used to provide hard-coded defaults in rule declarations). If
          the underscore-prefixed version of the attribute does not exist, this is
          considered an internal consistency error and the function will fail.

    Returns:
      A list with value of the attribute, or a list with the default if the
      attribute is not set. If the attribute was already a list, it will return
      that list.
    """
    value = _get(obj, attr_name, default = default)
    if type(value) == type([]):
        return value
    return [value]

# Define the loadable module that lists the exported symbols in this file.
attrs = struct(
    get = _get,
    get_as_list = _get_as_list,
    private_fallback = _private_fallback,
)
