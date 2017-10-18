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

AppleBundleInfo = provider(
    doc="""
Provides information about an Apple bundle target.

This provider propagates general information about an Apple bundle that is not
specific to any particular bundle type.
""",
    fields={
        "archive": "`File`. The archive that contains the built application.",
        "archive_root": """
`string`. The file system path (relative to the workspace root)
where the signed bundle was constructed (before archiving). Other rules
*should not* depend on this field; it is intended to support IDEs that
want to read that path from the provider to avoid unzipping the output
archive.
""",
        "bundle_dir": "`File`. The directory that represents the bundle.",
        "bundle_id": """
`string`. The bundle identifier (i.e., `CFBundleIdentifier` in
`Info.plist`) of the bundle.
""",
        "bundle_name": """
`string`. The name of the bundle, without the extension.
""",
        "bundle_extension": """
`string`. The bundle extension.
""",
        "extension_safe": """
Boolean. True if the target propagating this provider was
compiled and linked with -application-extension, restricting it to
extension-safe APIs only.
""",
        "infoplist": """
`File`. The complete (binary-formatted) `Info.plist` file for the bundle.
""",
        "minimum_os_version": """
`string`. The minimum OS version (as a dotted version
number like "9.0") that this bundle was built to support.
""",
        "product_type": """
`string`. The dot-separated product type identifier associated
with the bundle (for example, `com.apple.product-type.application`).
""",
        "propagated_framework_files": """
`depset` of `File`s. Individual files that make up
framework dependencies of the target but which are propagated to an
embedding target instead of being bundled with the propagator. For
example, an `ios_extension` propagates its frameworks to be bundled with
the embedding `ios_application` rather than bundling the frameworks with
the extension itself. (This mainly supports `objc_framework`, which
propagates its contents as individual files instead of a zipped framework;
see `propagated_framework_zips`.)
""",
        "propagated_framework_zips": """
`depset` of `File`s. Files that are zipped
framework dependencies of the target but which are propagated to an
embedding target instead of being bundled with the propagator. For
example, an `ios_extension` propagates its frameworks to be bundled with
the embedding `ios_application` rather than bundling the frameworks with
the extension itself.
""",
        "root_merge_zips": """
`list` of `File`s. A list of any `.zip` files that should be
merged into the root of the top-level bundle (such as `ios_application` or
`tvos_application`) that embeds the target propagating this provider.
""",
        "uses_swift": """
Boolean. True if Swift is used by the target propagating this
provider. This does not consider embedded bundles; for example, an
Objective-C application containing a Swift extension would have this field
set to true for the extension but false for the application.
"""
    },
)

AppleBundlingSwiftInfo = provider(
    doc="""
Provides information about whether Swift needs to be bundled with a target.

The `AppleBundlingSwiftInfo` provider is used to indicate whether Swift is
required by any code in the bundle. Note that this only applies within the
bundle's direct dependencies (`deps`); it does not pass through
application/extension boundaries. For example, if an extension uses Swift but an
application does not, then the application does not "use Swift" as defined by
this provider.
""",
    fields={
        "uses_swift": """
Boolean. True if Swift is used by the target propagating this
provider or by any of its transitive dependencies.
""",
    }
)

AppleBundleVersionInfo = provider(
    doc="Provides versioning information for an Apple bundle.",
    fields={
        "version_file": """
A `File` containing JSON-formatted text describing the version
number information propagated by the target. It contains two keys:
`build_version`, which corresponds to `CFBundleVersion`; and
`short_version_string`, which corresponds to `CFBundleShortVersionString`.
"""
    }
)

AppleExtraOutputsInfo = provider(
    doc="""
Provides information about extra outputs that should be produced from the build.

This provider propagates supplemental files that should be produced as outputs
even if the bundle they are associated with is not a direct output of the rule.
For example, an application that contains an extension will build both targets
but only the application will be a rule output. However, if dSYM bundles are
also being generated, we do want to produce the dSYMs for *both* application and
extension as outputs of the build, not just the dSYMs of the explicit target
being built (the application).
""",
    fields={
        "files": """
`depset` of `File`s. These files will be propagated from embedded bundles (such
as frameworks and extensions) to the top-level bundle (such as an application)
to ensure that they are explicitly produced as outputs of the build.
""",
    },
)

AppleResourceInfo = provider(
    doc="""
Provides information about resources from transitive dependencies.

The `AppleResourceInfo` provider should be propagated by rules that want to
propagate resources--such as images, strings, Interface Builder files, and so
forth--to a depending application or extension. For example, `swift_library`
can provide attributes like `bundles`, `resources`, and `structured_resources`
that allow users to associate resources with the code that uses them.
""",
    fields={
        "resource_sets": """
`list` of `struct`s. Each `struct` is one defined by
`AppleResourceSet` and the full list describes the transitive resources
propagated by this rule.
""",
    }
)


IosApplicationBundleInfo = provider(
    doc="""
Denotes that a target is an iOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS application bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is an iOS application should use this provider to describe that
requirement.
"""
)


IosExtensionBundleInfo = provider(
    doc="""
Denotes that a target is an iOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is an iOS application extension should use this
provider to describe that requirement.
"""
)


IosFrameworkBundleInfo = provider(
    doc="""
Denotes that a target is an iOS dynamic framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS dynamic framework
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an iOS dynamic framework should use this provider to describe
that requirement.
"""
)


IosStaticFrameworkBundleInfo = provider(
    doc="""
Denotes that a target is an iOS static framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS static framework
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an iOS static framework should use this provider to describe
that requirement.
"""
)


IosXcTestBundleInfo = provider(
    doc="""
Denotes a target that is an iOS .xctest bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS .xctest bundle (and
not some other Apple bundle). Rule authors who wish to require that a dependency
is an iOS .xctest bundle should use this provider to describe that requirement.
"""
)


MacosApplicationBundleInfo = provider(
    doc="""
Denotes that a target is a macOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS application bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS application should use this provider to describe that
requirement.
"""
)


MacosBundleBundleInfo = provider(
    doc="""
Denotes that a target is a macOS loadable bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS loadable bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS loadable bundle should use this provider to describe that
requirement.
"""
)


MacosExtensionBundleInfo = provider(
    doc="""
Denotes that a target is a macOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is a macOS application extension should use this
provider to describe that requirement.
"""
)


MacosXcTestBundleInfo = provider(
    doc="""
Denotes a target that is a macOS .xctest bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS .xctest bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS .xctest bundle should use this provider to describe that
requirement.
"""
)


SwiftInfo = provider(
    doc="""
Provides information about a Swift library.

Fields:
  direct_lib: `File`. The single static library that was produced by compiling
      the propagating target. (Contrast with `transitive_libs`.)
  direct_module: `File`. The single `.swiftmodule` file that was produced by
      compiling the propagating target. (Contrast with `transitive_modules`.)
  transitive_defines: `depset` of `string`s. The set of conditional compilation
      flags defined by the propagating target and all of its transitive
      dependencies.
  transitive_libs: `depset` of `File`s. The set of static library files output
      by the propagating target and all of its transitive dependencies.
  transitive_modules: `depset` of `File`s. The set of `.swiftmodule` files
      output by the propagating target and all of its transitive dependencies.
"""
)


TvosApplicationBundleInfo = provider(
    doc="""
Denotes that a target is a tvOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a tvOS application bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a tvOS application should use this provider to describe that
requirement.
"""
)


TvosExtensionBundleInfo = provider(
    doc="""
Denotes that a target is a tvOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a tvOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is a tvOS application extension should use this
provider to describe that requirement.
"""
)


WatchosApplicationBundleInfo = provider(
    doc="""
Denotes that a target is a watchOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a watchOS application
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is a watchOS application should use this provider to describe that
requirement.
"""
)


WatchosExtensionBundleInfo = provider(
    doc="""
Denotes that a target is a watchOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a watchOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is a watchOS application extension should use this
provider to describe that requirement.
"""
)


def AppleResourceSet(bundle_dir=None,
                     infoplists=depset(),
                     objc_bundle_imports=depset(),
                     resource_bundle_label=None,
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
    resource_bundle_label: The `Label` of the target that is defining a
        resource bundle with these resources. If the resources aren't
        in a resource bundle (because they are from an objc_library,
        directly in an app, etc.), then this will not be set.
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
                resource_bundle_label=resource_bundle_label,
                resources=resources,
                structured_resources=structured_resources,
                structured_resource_zips=structured_resource_zips,
                swift_module=swift_module)


def _apple_resource_set_utils_minimize(resource_sets,
                                       framework_resource_sets=[],
                                       dedupe_unbundled=False):
  """Minimizes and reduces a list of resource sets.

  This both merges similar resource set elements and subtracts all resources
  already defined in framework resource sets.

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
    framework_resource_sets: The list of "AppleResourceSet" values which contain
        resources already included in framework bundles. Resources present
        in these sets will not be included in the returned list.
    dedupe_unbundled: If false, resources that have no bundle directory will
        not be subtracted. False by default.
  Returns:
    The minimal possible list after merging `AppleResourceSet` values with
    the same `bundle_dir` and `swift_module`.
  """
  framework_minimized_dict = _apple_resource_set_dict(framework_resource_sets)
  if not dedupe_unbundled:
    framework_minimized_dict_without_unbundled = {}
    for (bundle_dir, swift_module), value in framework_minimized_dict.items():
      if bundle_dir:
        key = (bundle_dir, swift_module)
        framework_minimized_dict_without_unbundled[key] = value
    framework_minimized_dict = framework_minimized_dict_without_unbundled
  minimized_dict = _apple_resource_set_dict(resource_sets,
                                            framework_minimized_dict)

  return [_dedupe_resource_set_files(rs) for rs in minimized_dict.values()]


def _apple_resource_set_dict(resource_sets, avoid_resource_dict={}):
  """Returns a minimal map of resource sets, omitting specified resources.

  Map keys are `(bundle_dir, swift_module)` of the resource set; multiple
  resource sets with the same key will be combined into a single resource
  set of that key.

  Any resources present under a given key in `avoid_resource_dict` will be
  omitted from that keyed resource set in the returned value.

  Args:
    resource_sets: The list of `AppleResourceSet` values for the map.
    avoid_resource_dict: A map of `AppleResourceSet` values already keyed by
        `(bundle_dir, swift_module)` that should be omitted from the output
  Returns:
    A minimal map from `(bundle_dir, swift_module)` to `AppleResourceSet`
    containing the resources in `resource_sets` minus the resources in
    `avoid_resource_dict`.
  """
  minimized_dict = {}

  for current_set in resource_sets:
    key = (current_set.bundle_dir, current_set.swift_module)
    existing_set = minimized_dict.get(key)
    avoid_set = avoid_resource_dict.get(key)

    avoid_objc_bundle_imports = depset()
    avoid_resources = depset()
    avoid_structured_resources = depset()
    avoid_structured_resource_zips = depset()

    if avoid_set:
      avoid_objc_bundle_imports = avoid_set.objc_bundle_imports
      avoid_resources = avoid_set.resources
      avoid_structured_resources = avoid_set.structured_resources
      avoid_structured_resource_zips = avoid_set.structured_resource_zips

    resource_bundle_label = current_set.resource_bundle_label

    if existing_set:
      if existing_set.resource_bundle_label:
        if resource_bundle_label:
          if resource_bundle_label != existing_set.resource_bundle_label:
            fail(("Internal error: AppleResourceSets with different "
                  + "resource_bundle_labels?! (%r: %r vs %r)") %
                 (current_set.bundle_dir, str(resource_bundle_label),
                  str(existing_set.resource_bundle_label)))
        else:
          resource_bundle_label = existing_set.resource_bundle_label
      infoplists = existing_set.infoplists + current_set.infoplists
      objc_bundle_imports = (existing_set.objc_bundle_imports
                             + current_set.objc_bundle_imports)
      resources = existing_set.resources + current_set.resources
      structured_resources = (existing_set.structured_resources
                              + current_set.structured_resources)
      structured_resource_zips = (existing_set.structured_resource_zips
                                  + current_set.structured_resource_zips)
    else:
      infoplists = current_set.infoplists
      objc_bundle_imports = current_set.objc_bundle_imports
      resources = current_set.resources
      structured_resources = current_set.structured_resources
      structured_resource_zips = current_set.structured_resource_zips

    new_set = AppleResourceSet(
        bundle_dir=current_set.bundle_dir,
        infoplists=infoplists,
        objc_bundle_imports=_filter_files(objc_bundle_imports,
                                          avoid_objc_bundle_imports),
        resource_bundle_label=resource_bundle_label,
        resources=_filter_files(resources,
                                avoid_resources),
        structured_resources=_filter_files(structured_resources,
                                           avoid_structured_resources),
        structured_resource_zips=_filter_files(structured_resource_zips,
                                               avoid_structured_resource_zips),
        swift_module=current_set.swift_module,
    )

    minimized_dict[key] = new_set

  return minimized_dict


def _filter_files(files, avoid_files):
  """Returns a depset containing files minus avoid_files."""
  avoid_short_paths = {f.short_path: None for f in avoid_files.to_list()}
  return depset([f for f in files if f.short_path not in avoid_short_paths])


def _dedupe_files(files):
  """Deduplicates files based on their short paths.

  Args:
    files: The set of `File`s that should be deduplicated based on their short
        paths.
  Returns:
    The `depset` of `File`s where duplicate short paths have been removed by
    arbitrarily removing all but one from the set.
  """
  short_path_to_files_mapping = {}

  for f in files:
    short_path = f.short_path
    if short_path not in short_path_to_files_mapping:
      short_path_to_files_mapping[short_path] = f

  return depset(short_path_to_files_mapping.values())


def _dedupe_resource_set_files(resource_set):
  """Deduplicates the files in a resource set based on their short paths.

  It is possible to have genrules that produce outputs that will be used later
  as resource inputs to other rules (and not just genrules, in fact, but any
  rule that produces an output file), and these rules register separate actions
  for each split configuration when a target is built for multiple
  architectures. If we don't deduplicate those files, the outputs of both sets
  of actions will be sent to the resource processor and it will attempt to put
  the compiled results in the same intermediate file location.

  Therefore, we deduplicate resources that have the same short path, which
  ensures (due to action pruning) that only one set of actions will be executed
  and only one output will be generated. This implies that the genrule must
  produce equivalent content for each configuration. This is likely OK, because
  if the output is actually architecture-dependent, then the actions need to
  produce those outputs with names that allow the bundler to distinguish them.

  Args:
    resource_set: The resource set whose `infoplists`, `resources`,
        `structured_resources`, and `structured_resource_zips` should be
        deduplicated.
  Returns:
    A new resource set with duplicate files removed.
  """
  return AppleResourceSet(
      bundle_dir=resource_set.bundle_dir,
      infoplists=_dedupe_files(resource_set.infoplists),
      objc_bundle_imports=_dedupe_files(resource_set.objc_bundle_imports),
      resource_bundle_label=resource_set.resource_bundle_label,
      resources=_dedupe_files(resource_set.resources),
      structured_resources=_dedupe_files(resource_set.structured_resources),
      structured_resource_zips=_dedupe_files(
          resource_set.structured_resource_zips),
      swift_module=resource_set.swift_module,
  )


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
      resource_bundle_label=resource_set.resource_bundle_label,
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
