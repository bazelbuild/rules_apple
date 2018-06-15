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

"""Core resource propagation logic.

Resource are propagated using NewAppleResourceInfo, in which each field
(or bucket) contains data for resources that should be bundled inside
top-level Apple bundles (e.g. ios_application).

Each bucket contains a list of tuples with the following schema:

  (parent_dir, swift_module, resource_files)

  - parent_dir: This is the target path relative to the root of the bundle
    that will embed the resource_files. Each of the resource_files will
    be copied into a directory structure that matches parent_dir. If
    parent_dir is None, the resources will be placed in the root level.
    For structured resources where the relative path to the target must be
    preserved, parent_dir might look like "some/dir/path". For bundles,
    parent_dir might look like "Resource.bundle".
  - swift_module: This is the name of the Swift module, should the resources
    had been added through a swift_library rule. This is needed as some
    resource types require this value when being compiled (e.g. xibs).
  - resource_files: This is a depset of all the files that should be placed
    under parent_dir.

During propagation, each target will need to merge multiple NewAppleResourceInfo
providers coming from dependencies. Merging will then aggressively minimize
the tuples in order to only have one tuple per parent_dir per swift_module per
bucket.

This file provides methods to easily:
  - collect all resource files from the different rules and their attributes
  - bucketize each of the resources into specific buckets depending on their
    path
  - minimize the resulting tuples in order to minimize memory usage
"""

load(
    "@build_bazel_rules_apple//common:path_utils.bzl",
    "path_utils",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

NewAppleResourceInfo = provider(
    doc = """
Provider that propagates buckets of resources that are differentiated by
resource type.
""",
    fields = {
        "generic": "Generic resources not mapped to the other types.",
        "png": "PNG images which are not bundled in an .xcassets folder.",
        "storyboards": "Storyboard files.",
        "strings": "Localization strings files.",
        "xcassets": "Resources that need to be embedded into Assets.car.",
        "xibs": "XIB Interface files.",
    },
)

def _get_attr_as_list(attr, attribute):
  """Helper method to always get an attribute as a list."""
  value = getattr(attr, attribute)
  if not value:
    return []
  if type(value) == type([]):
    return value
  return [value]

def _bucketize(resources, swift_module=None, parent_dir_param=None):
  """Separates the given resources into resource bucket types.

  This method takes a list of resources and constructs a tuple object for
  each, placing it inside the correct bucket.

  The parent_dir is calculated from the parent_dir_param object. This object
  can either be None (the default), a string object, or a function object. If a
  function is provided, it should accept only 1 parameter, which will be the
  File object representing the resource to bucket. This mechanism gives us a
  simpler way to manage multiple use cases. For example, when used to bucketize
  structured resources, the parent_dir_param can be a function that returns the
  relative path to the owning package; or in an objc_library it can be None,
  signaling that these resources should be placed in the root level.

  Once all resources have been placed in buckets, each of the lists will be
  minimized.

  Finally, it will return a NewAppleResourceInfo provider with the resources
  bucketed per type.

  Args:
    resources: List of resources to bucketize.
    swift_module: The Swift module name to associate to these resources.
    parent_dir_param: Either a string or a function used to calculate the value
      of parent_dir for each resource.

  Returns:
    A NewAppleResourceInfo provider with resources bucketized according to type.
  """
  buckets = {}
  for resource in resources:
    if str(type(parent_dir_param)) == "function":
      parent = parent_dir_param(resource)
    else:
      parent = parent_dir_param

    # For each type of resource, place in appropriate bucket.
    # TODO(kaipi): Missing many types of resources, this is just a starting
    # point.

    # Special case for localized. If .lproj/ is in the path of the resource
    # (and the parent doesn't already have it) append the lproj component to
    # the current parent.
    if ".lproj/" in resource.short_path and (not parent or ".lproj" not in parent):
      lproj_path = path_utils.farthest_directory_matching(
          resource.short_path, "lproj"
      )
      parent = paths.join(parent or "", paths.basename(lproj_path))

    if resource.short_path.endswith(".strings"):
      buckets.setdefault(
          "strings", default=[]
      ).append((parent, None, depset([resource])))
    elif resource.short_path.endswith(".storyboard"):
      buckets.setdefault(
          "storyboards", default=[]
      ).append((parent, swift_module, depset([resource])))
    elif resource.short_path.endswith(".xib"):
      buckets.setdefault(
          "xibs", default=[]
      ).append((parent, swift_module, depset([resource])))
    elif ".xcassets/" in resource.short_path:
      buckets.setdefault(
          "xcassets", default=[]
      ).append((parent, None, depset([resource])))
    elif resource.short_path.endswith(".png"):
      buckets.setdefault(
          "png", default=[]
      ).append((parent, None, depset([resource])))
    else:
      buckets.setdefault(
          "generic", default=[]
      ).append((parent, None, depset([resource])))

  return NewAppleResourceInfo(
      **dict([(k, _minimize(b)) for k, b in buckets.items()])
  )

def _collect(attr, res_attrs=[]):
  """Collects all resource attributes present in the given attributes.

  Iterates over the given res_attrs attributes collecting files to be processed
  as resources. These are all placed into a list, and then returned.

  Args:
    attr: The attributes object as returned by ctx.attr (or ctx.rule.attr) in
      the case of aspects.
    res_attrs: List of attributes to iterate over collecting resources.

  Returns:
    A list with all the collected resources for the target represented by attr.
  """
  if not res_attrs:
    return []

  files = []
  for res_attr in res_attrs:
    if hasattr(attr, res_attr):
      file_groups = [
          x.files.to_list()
          for x in _get_attr_as_list(attr, res_attr)
          if x.files
      ]
      for file_group in file_groups:
        files.extend(file_group)
  return files

def _merge_providers(providers):
  """Merges multiple NewAppleResourceInfo providers into one.

  Args:
    providers: The list of providers to merge. This method will fail unless
      there is at least 1 provider in the list.

  Returns:
    A NewAppleResourceInfo provider with the results of the merge of the given
    providers.
  """
  if not providers:
    fail("merge should be called with a non-empty list of providers. This " +
         "is most likely a bug in rules_apple, please file a bug with " +
         "reproduction steps.")

  if len(providers) == 1:
    return providers[0]

  buckets = {}
  for provider in providers:
    # Get the initialized fields in the provider, with the exception of
    # to_json and to_proto, which are not desireable for our use case.
    # TODO(b/36412967): Remove this filtering and just use dir().
    fields = [
        f for f in dir(provider)
        if f not in ["to_json", "to_proto"]
    ]
    for field in fields:
      buckets.setdefault(
          field, default=[]
      ).extend(getattr(provider, field))

  minimized = dict([(k, _minimize(v)) for (k, v) in buckets.items()])
  return NewAppleResourceInfo(**minimized)

def _minimize(bucket):
  """Minimizes the given list of tuples into the smallest subset possible.

  Takes the list of tuples that represent one resource bucket, and minimizes it
  so that 2 tuples with resources that should be placed under the same location
  are merged into 1 tuple.

  For tuples to be merged, they need to have the same parent_dir and swift_module.

  Args:
    bucket: List of tuples to be minimized.

  Returns:
    A list of minimized tuples.
  """
  resources_by_key = {}

  # Use these maps to keep track of the parent_dir and swift_module values.
  parent_dir_by_key = {}
  swift_module_by_key = {}

  for parent_dir, swift_module, resources in bucket:
    key = "_".join([parent_dir or "@root", swift_module or "@root"])
    if parent_dir:
      parent_dir_by_key[key] = parent_dir
    if swift_module:
      swift_module_by_key[key] = swift_module

    resources_by_key.setdefault(
        key, default=[]
    ).append(resources)

  return [
      (parent_dir_by_key.get(k, None),
       swift_module_by_key.get(k, None),
       depset(transitive=r))
      for k, r in resources_by_key.items()
  ]

resources = struct(
    bucketize=_bucketize,
    collect=_collect,
    merge_providers=_merge_providers,
    minimize=_minimize,
)
