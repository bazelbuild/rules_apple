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

AppleBundleInfo = provider()
"""Provides information about an Apple bundle target.

This provider propagates general information about an Apple bundle that is not
specific to any particular bundle type.

Fields:
  archive: `File`. The archive that contains the built application.
  archive_root: `string`. The file system path (relative to the workspace root)
      where the signed bundle was constructed (before archiving). Other rules
      *should not* depend on this field; it is intended to support IDEs that
      want to read that path from the provider to avoid unzipping the output
      archive.
  bundle_id: `string`. The bundle identifier (i.e., `CFBundleIdentifier` in
      `Info.plist`) of the bundle.
  extension_safe: Boolean. True if the target propagating this provider was
      compiled and linked with -application-extension, restricting it to
      extension-safe APIs only.
  infoplist: `File`. The complete (binary-formatted) `Info.plist` file for the
      bundle.
  minimum_os_version: `string`. The minimum OS version (as a dotted version
      number like "9.0") that this bundle was built to support.
  product_type: `string`. The dot-separated product type identifier associated
      with the bundle (for example, `com.apple.product-type.application`).
  propagated_framework_files: `depset` of `File`s. Individual files that make up
      framework dependencies of the target but which are propagated to an
      embedding target instead of being bundled with the propagator. For
      example, an `ios_extension` propagates its frameworks to be bundled with
      the embedding `ios_application` rather than bundling the frameworks with
      the extension itself. (This mainly supports `objc_framework`, which
      propagates its contents as individual files instead of a zipped framework;
      see `propagated_framework_zips`.)
  propagated_framework_zips: `depset` of `File`s. Files that are zipped
      framework dependencies of the target but which are propagated to an
      embedding target instead of being bundled with the propagator. For
      example, an `ios_extension` propagates its frameworks to be bundled with
      the embedding `ios_application` rather than bundling the frameworks with
      the extension itself.
  root_merge_zips: `list` of `File`s. A list of any `.zip` files that should be
      merged into the root of the top-level bundle (such as `ios_application` or
      `tvos_application`) that embeds the target propagating this provider.
  uses_swift: Boolean. True if Swift is used by the target propagating this
      provider. This does not consider embedded bundles; for example, an
      Objective-C application containing a Swift extension would have this field
      set to true for the extension but false for the application.
"""


AppleBundlingSwiftInfo = provider()
"""Provides information about whether Swift needs to be bundled with a target.

The `AppleBundlingSwiftInfo` provider is used to indicate whether Swift is
required by any code in the bundle. Note that this only applies within the
bundle's direct dependencies (`deps`); it does not pass through
application/extension boundaries. For example, if an extension uses Swift but an
application does not, then the application does not "use Swift" as defined by
this provider.

Fields:
  uses_swift: Boolean. True if Swift is used by the target propagating this
      provider or by any of its transitive dependencies.
"""


AppleResourceInfo = provider()
"""Provides information about resources from transitive dependencies.

The `AppleResourceInfo` provider should be propagated by rules that want to
propagate resources--such as images, strings, Interface Builder files, and so
forth--to a depending application or extension. For example, `swift_library`
can provide attributes like `bundles`, `resources`, and `structured_resources`
that allow users to associate resources with the code that uses them.

Fields:
  resource_sets: `list` of `struct`s. Each `struct` is one defined by
      `AppleResourceSet` and the full list describes the transitive resources
      propagated by this rule.
"""


IosApplicationBundleInfo = provider()
"""Denotes that a target is an iOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS application bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is an iOS application should use this provider to describe that
requirement.
"""


IosExtensionBundleInfo = provider()
"""Denotes that a target is an iOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is an iOS application extension should use this
provider to describe that requirement.
"""


IosFrameworkBundleInfo = provider()
"""Denotes that a target is an iOS dynamic framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS dynamic framework
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an iOS dynamic framework should use this provider to describe
that requirement.
"""


IosXcTestBundleInfo = provider()
"""Denotes a target that is an iOS .xctest bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS .xctest bundle (and
not some other Apple bundle). Rule authors who with to require that a dependency
is an iOS .xctest bundle should use this provider to describe that requirement.
"""


MacosApplicationBundleInfo = provider()
"""Denotes that a target is a macOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS application bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS application should use this provider to describe that
requirement.
"""


MacosExtensionBundleInfo = provider()
"""Denotes that a target is a macOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is a macOS application extension should use this
provider to describe that requirement.
"""


SwiftInfo = provider()
"""Provides information about a Swift library.

Fields:
  transitive_defines: `depset` of `string`s. The set of conditional compilation
      flags defined by the propagating target and all of its transitive
      dependencies.
  transitive_libs: `depset` of `File`s. The set of static library files output
      by the propgating target and all of its transitive dependencies.
  transitive_modules: `depset` of `File`s. The set of `.swiftmodule` files
      output by the propagating target and all of its transitive dependencies.
"""


TvosApplicationBundleInfo = provider()
"""Denotes that a target is a tvOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a tvOS application bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a tvOS application should use this provider to describe that
requirement.
"""


TvosExtensionBundleInfo = provider()
"""Denotes that a target is a tvOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a tvOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is a tvOS application extension should use this
provider to describe that requirement.
"""


WatchosApplicationBundleInfo = provider()
"""Denotes that a target is a watchOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a watchOS application
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is a watchOS application should use this provider to describe that
requirement.
"""


WatchosExtensionBundleInfo = provider()
"""Denotes that a target is a watchOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a watchOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is a watchOS application extension should use this
provider to describe that requirement.
"""


def AppleResourceSet(bundle_dir=None,
                     infoplists=depset(),
                     objc_bundle_imports=depset(),
                     resources=depset(),
                     structured_resources=depset(),
                     structured_resource_zips=depset(),
                     swift_module=None):
  """Returns a new resource set to be propagated via `AppleResourceInfo`.

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
    `AppleResourceInfo` provider.
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
