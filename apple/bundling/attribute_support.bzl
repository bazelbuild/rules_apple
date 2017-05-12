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

"""Support functions for working with rule attributes."""


def _get(obj, attr_name, default=None):
  """Gets the value of an attribute defined either publicly or privately.

  The bundler uses public/private attribute pairs when some rules need to allow
  an attribute to be configurable by the user but when other rules fix it to a
  constant value.

  This function gets the value of the attribute in either case, using the
  following logic:

  - If the attribute is defined publicly, return its value or the default if it
    is not set.
  - If the attribute is defined privately, return its fixed value.
  - Fail if the attribute is not defined at all (this is an internal consistency
    error).

  Args:
    obj: The object whose attribute should be retrieved.
    attr_name: The name of the attribute to retrieve.
    default: The default value to return if the attribute was defined publicly
        but was not set.
  Returns: The value of the attribute, or the default if the attribute is public
      and unset.
  """
  if hasattr(obj, attr_name):
    return getattr(obj, attr_name, default)

  private_name = "_" + attr_name
  if hasattr(obj, private_name):
    return getattr(obj, private_name)

  fail(("Internal error: Attribute '%s' was not defined publicly on the rule " +
        "so it must be defined privately, but it was not" % attr_name))


# Define the loadable module that lists the exported symbols in this file.
attribute_support = struct(
    get=_get,
)
