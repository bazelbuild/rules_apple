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

"""Defines providers and related types used throughout the bundling rules.

These providers are part of the public API of the bundling rules. Other rules
that want to propagate information to the bundling rules or that want to
consume the bundling rules as their own inputs should use these to handle the
relevant information that they need.
"""

# TODO(b/34879141): Convert these to declared providers.
def AppleBundlingSwift(uses_swift=False):
  """Returns a new `AppleBundlingSwift` provider.

  The `AppleBundlingSwift` provider is used to indicate whether Swift is
  required by any code in the bundle. Note that this only applies within
  the bundle's direct dependencies (`deps`); it does not pass through
  application/extension boundaries. For example, if an extension uses
  Swift but an application does not, then the application does not "use
  Swift" as defined by this provider.

  Args:
    uses_swift: True if Swift is used by the target propagating this
        provider or by any of its transitive dependencies.
  Returns:
    A new `AppleBundlingSwift` provider.
  """
  return struct(uses_swift=uses_swift)


def AppleResource(resource_sets=[]):
  """Returns a new `AppleResource` provider.

  The `AppleResource` provider should be propagated by rules that want to
  propagate resources--such as images, strings, Interface Builder files, and so
  forth--to a depending application or extension. For example, `swift_library`
  can provide attributes like `bundles`, `resources`, and
  `structured_resources` that allow users to associate resources with the code
  that uses them.

  Args:
    resource_sets: A list of structs (each returned by `AppleResourceSet`)
        that describe the transitive resources propagated by this rule.
  Returns:
    A new `AppleResource` provider.
  """
  return struct(resource_sets=resource_sets)


def AppleResourceSet(bundle_dir=None,
                     infoplists=depset(),
                     objc_bundle_imports=depset(),
                     resources=depset(),
                     structured_resources=depset(),
                     structured_resource_zips=depset(),
                     swift_module=None):
  """Returns a new resource set to be propagated via `apple_resource`.

  Args:
    bundle_dir: The path within the final bundle (relative to its resources
        root) where the resources should be stored. For example, a resource
        bundle rule would specify something of the form `"Foo.bundle"` here;
        library rules that propagate resources to the application itself
        should specify `None` (or omit it, as `None` is the default).
    infoplists: A `depset` of `File`s representing plists that should be
        merged to produce the `Info.plist` for the bundle.
    objc_bundle_imports: A `depset` of `File`s representing resources that
        came from an `objc_bundle` target and need to have their paths stripped
        of any segments before the `"*.bundle"` name.
    resources: A `depset` of `File`s representing resources that should be
        processed (if they are a known type) or copied (if the type is not
        recognized) and placed in the bundle at the location specified by
        `bundle_dir`. The relative paths to these files are ignored, with the
        exception that files contained in a directory named `"*.lproj"` will
        be placed in a directory of the same name in the final bundle.
    structured_resources: A `depset` of `File`s representing resources that
        should be copied into the bundle without any processing at the location
        specified by `bundle_dir`. The relative paths of these files are
        preserved.
    structured_resource_zips: A `depset` of `File`s representing ZIP archives
        whose contents should unzipped into the bundle without any processing
        at the location specified by `bundle_dir`. The directory structure
        within the archive is preserved.
    swift_module: The name of the Swift module with which these resources are
        associated. Some resource types, such as Interface Builder files or
        Core Data models, require the Swift module to be specified during
        compilation so that the classes they reference can be found at runtime.
        If this value is `None`, then the resources are not associated with a
        Swift module (for example, resources attached to Objective-C rules) and
        the name of the main application/extension/framework will be passed to
        the resource tool instead.
  Returns:
    A struct containing a set of resources that can be propagated by the
    `apple_resource` provider.
  """
  return struct(bundle_dir=bundle_dir,
                infoplists=infoplists,
                objc_bundle_imports=objc_bundle_imports,
                resources=resources,
                structured_resources=structured_resources,
                structured_resource_zips=structured_resource_zips,
                swift_module=swift_module)


def _apple_resource_set_utils_minimize(resource_sets):
  """Minimizes a list of resource sets by merging similar elements.

  Two or more resource sets can be merged if their `bundle_dir` and
  `swift_module` values are the same, which means that they can be passed to
  the same resource processing tool invocation. The list returned by this
  function represents the minimal possible list after merging such sets.

  The main Apple bundler will minimize the list of transitive resource sets
  before processing resources, but other rules that propagate resource sets are
  advised to call this function as well after collecting their transitive
  resources to avoid propagating a large number of minimizable sets to their
  dependers.

  Args:
    resource_sets: The list of `AppleResourceSet` values that should be merged.
  Returns:
    The minimal possible list after merging `AppleResourceSet` values with
    the same `bundle_dir` and `swift_module`.
  """
  minimized_dict = {}

  for current_set in resource_sets:
    key = (current_set.bundle_dir, current_set.swift_module)
    existing_set = minimized_dict.get(key)

    if existing_set:
      new_set = AppleResourceSet(
          bundle_dir=existing_set.bundle_dir,
          infoplists=existing_set.infoplists + current_set.infoplists,
          objc_bundle_imports=(existing_set.objc_bundle_imports +
                               current_set.objc_bundle_imports),
          resources=existing_set.resources + current_set.resources,
          structured_resources=(existing_set.structured_resources +
                                current_set.structured_resources),
          structured_resource_zips=(existing_set.structured_resource_zips +
                                    current_set.structured_resource_zips),
          swift_module=existing_set.swift_module,
      )
    else:
      new_set = current_set

    minimized_dict[key] = new_set

  return minimized_dict.values()


def _apple_resource_set_utils_prefix_bundle_dir(resource_set, prefix):
  """Returns an equivalent resource set with a new path prepended to it.

  This function should be used by rules that allow nested bundles; for example,
  a resource bundle that contains other resource bundles must prepend its own
  `bundle_dir` to the `bundle_dir`s of its child bundles to ensure that the
  files are bundled in the correct location.

  For example, if `resource_set` has a `bundle_dir` of `"Foo.bundle"` and
  `prefix` is `"Bar.bundle"`, the returned resource set will have a
  `bundle_dir` equal to `"Bar.bundle/Foo.bundle"`. Likewise, if `resource_set`
  had a `bundle_dir` of `None`, then the new `bundle_dir` would be
  `"Bar.bundle"`.

  Args:
    resource_set: The `AppleResourceSet` whose `bundle_dir` should be prefixed.
    prefix: The path that should be prepended to the existing `bundle_dir`.
  Returns:
    A new `AppleResourceSet` whose `bundle_dir` has been prefixed with the
    given path.
  """
  nested_dir = prefix
  if resource_set.bundle_dir:
    nested_dir += "/" + resource_set.bundle_dir

  return AppleResourceSet(
      bundle_dir=nested_dir,
      infoplists=resource_set.infoplists,
      objc_bundle_imports=resource_set.objc_bundle_imports,
      resources=resource_set.resources,
      structured_resources=resource_set.structured_resources,
      structured_resource_zips=resource_set.structured_resource_zips,
      swift_module=resource_set.swift_module,
  )


# Export the module containing helper functions for resource sets.
apple_resource_set_utils = struct(
    minimize=_apple_resource_set_utils_minimize,
    prefix_bundle_dir=_apple_resource_set_utils_prefix_bundle_dir,
)
