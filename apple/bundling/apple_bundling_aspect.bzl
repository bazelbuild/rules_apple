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

"""An aspect that collects information used during Apple bundling."""

load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundlingSwiftInfo",
    "AppleResourceBundleTargetData",
    "AppleResourceInfo",
    "AppleResourceSet",
    "apple_resource_set_utils",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "basename",
    "group_files_by_directory",
)
load(
    "@build_bazel_rules_apple//apple/bundling:bundling_support.bzl",
    "bundling_support",
)
load(
    "@build_bazel_rules_apple//common:providers.bzl",
    "providers",
)


def _attr_files(ctx, name):
  """Returns the list of files for the current target's attribute.

  This is a convenience function since the aspect context does not expose the
  same convenience `file`/`files` fields used in rule contexts.

  Args:
    ctx: The Skylark context.
    name: The name of the attribute.
  Returns:
    A list of Files.
  """
  return [f for t in getattr(ctx.rule.attr, name) for f in t.files]


def _handle_native_library_dependency(target, ctx):
  """Handles resources from an `objc_library` or `objc_bundle_library`.

  Args:
    target: The target to which the aspect is being applied.
    ctx: The Skylark context.
  Returns:
    A list of `AppleResourceSet` values that should be included in the list
    propagated by the `AppleResource` provider.
  """
  resource_sets = []
  bundles = getattr(ctx.rule.attr, "bundles", [])

  if ctx.rule.kind == "objc_bundle_library":
    product_name = bundling_support.bundle_name(ctx)
    # Can't use bundling_support.bundle_name_with_extension() because
    # objc_bundle_library is backed by native code at the moment and doesn't
    # expose the support needed.
    bundle_name = product_name + ".bundle"

    bundle_dir = bundle_name
    resource_bundle_target_data = AppleResourceBundleTargetData(
        target.label, bundle_name, product_name)

    infoplists = []
    if ctx.rule.attr.infoplist:
      infoplists.append(list(ctx.rule.attr.infoplist.files)[0])
    infoplists.extend(_attr_files(ctx, "infoplists"))

    # The "bundles" attribute of an objc_bundle_library indicates bundles that
    # should be nested inside that target's .bundle directory. Since we pass
    # transitive resources as a flat list based on their .bundle directory, we
    # must prepend the current target's {name}.bundle to the path so that the
    # files end up in the correct place.
    for p in providers.find_all(bundles, AppleResourceInfo):
      resource_sets.extend([
          apple_resource_set_utils.prefix_bundle_dir(rs, bundle_dir)
          for rs in p.resource_sets
      ])
  elif ctx.rule.kind == "objc_library":
    bundle_dir = None
    resource_bundle_target_data = None
    infoplists = []

    # The "bundles" attribute of an objc_library don't indicate a nesting
    # relationship, so simply bring them over as-is.
    for p in providers.find_all(bundles, AppleResourceInfo):
      resource_sets.extend(p.resource_sets)
  else:
    fail(("Internal consistency error: expected rule to be objc_library " +
          "objc_bundle_library, but got %s") % ctx.rule.kind)

  # Then, build the bundled_resources struct for the resources directly in the
  # current target.
  resources = depset(ctx.rule.files.asset_catalogs +
                     ctx.rule.files.datamodels +
                     ctx.rule.files.resources +
                     ctx.rule.files.storyboards +
                     ctx.rule.files.strings +
                     ctx.rule.files.xibs)
  structured_resources = depset(ctx.rule.files.structured_resources)

  # Only create the resource set if it's non-empty.
  if resources or infoplists or structured_resources:
    resource_sets.append(AppleResourceSet(
        bundle_dir=bundle_dir,
        infoplists=depset(infoplists),
        resource_bundle_target_data=resource_bundle_target_data,
        resources=resources,
        structured_resources=structured_resources,
    ))

  return resource_sets


def _handle_native_bundle_imports(bundle_imports):
  """Handles resources from an `objc_bundle` target.

  Args:
    bundle_imports: The list of `File`s in the bundle.
  Returns:
    A list of `AppleResourceSet` values that should be included in the list
    propagated by the `AppleResource` provider.
  """
  grouped_bundle_imports = group_files_by_directory(
      bundle_imports, ["bundle"], "bundle_imports")

  resource_sets = []

  # objc_bundles are copied verbatim into the bundle, preserving the directory
  # structure, but without any extra path prefixes before the ".bundle"
  # segment. We pass these along as a special case for the bundler to handle.
  for bundle_dir, files in grouped_bundle_imports.items():
    # We use basename in case the path to the bundle includes other segments
    # (like foo/bar/baz.bundle), which is allowed.
    resource_sets.append(AppleResourceSet(
        bundle_dir = basename(bundle_dir),
        objc_bundle_imports = depset(files),
        # We do NOT include resource_bundle_target_data here because
        # objc_bundle is too dumb of a copy, and you can have multiple targets
        # pick up files that are all in the SameNamed.bundle directory. The
        # build ends up merging those two .bundle directories to create on
        # bundle out of the combined contents (presumed already processed),
        # but that would break the requirement for resource_bundle_target_data,
        # where a single target is responsible for the contents of the bundle.
    ))

  return resource_sets


def _handle_unknown_objc_provider(objc):
  """Handles resources from a target that propagates an `objc` provider.

  This method is called as a last resort for targets not already handled
  elsewhere (like `objc_library`), since some users are currently propagating
  resources by creating their own `objc` provider.

  Args:
    objc: The `objc` provider.
  Returns:
    An `AppleResourceSet` value that should be included in the list propagated
    by the `AppleResource` provider.
  """
  resources = (objc.asset_catalog +
               objc.storyboard +
               objc.strings +
               objc.xcdatamodel +
               objc.xib)

  # Only create the resource set if it's non-empty.
  if not (resources or objc.bundle_file or objc.merge_zip):
    return None

  # Assume that any bundlable files whose bundle paths are just their basenames
  # had their paths flattened (if they were nested to begin with) and they can
  # be treated as resources.
  resources += [bf.file for bf in objc.bundle_file
                if bf.bundle_path == bf.file.basename]

  # Bundlable files whose bundle paths are not just their basenames should be
  # treated as structured resources to preserve those paths.
  structured_resources = depset([bf.file for bf in objc.bundle_file
                                 if bf.bundle_path != bf.file.basename])

  return AppleResourceSet(
      resources=resources,
      structured_resources=structured_resources,
      structured_resource_zips=objc.merge_zip,
  )


def _transitive_apple_resource_info(target, ctx):
  """Builds the `AppleResourceInfo` provider to be propagated.

  Args:
    target: The target to which the aspect is being applied.
    ctx: The Skylark context.
  Returns:
    An `AppleResourceInfo` provider.
  """
  resource_sets = []

  # If the rule has deps, propagate the transitive info from this target's
  # dependencies.
  deps = getattr(ctx.rule.attr, "deps", [])
  resource_providers = providers.find_all(deps, AppleResourceInfo)
  for p in resource_providers:
    resource_sets.extend(p.resource_sets)

  if ctx.rule.kind in ("objc_library", "objc_bundle_library"):
    resource_sets.extend(_handle_native_library_dependency(target, ctx))
  elif ctx.rule.kind == "objc_bundle":
    bundle_imports = ctx.rule.files.bundle_imports
    resource_sets.extend(_handle_native_bundle_imports(bundle_imports))
  elif not resource_providers:
    # Handle arbitrary objc providers, but only if we haven't gotten resource
    # sets for the target or its deps already. This lets us handle "resource
    # leaf nodes" (custom rules that return resources via the objc provider)
    # until they migrate to AppleResource, but without pulling in duplicated
    # information from the transitive objc providers on the way back up
    # (because we'll have already gotten that information in the form we want
    # from the transitive AppleResource providers).
    if hasattr(target, "objc"):
      resource_set = _handle_unknown_objc_provider(target.objc)
      if resource_set:
        resource_sets.append(resource_set)

  minimized = apple_resource_set_utils.minimize(resource_sets)
  return AppleResourceInfo(resource_sets=minimized)


def _transitive_apple_bundling_swift_info(target, ctx):
  """Builds the `AppleBundlingSwiftInfo` provider to be propagated.

  Args:
    target: The target to which the aspect is being applied.
    ctx: The Skylark context.
  Returns:
    An `AppleBundlingSwiftInfo` provider, or `None` if nothing should be
    propagated for this target.
  """
  uses_swift = hasattr(target, "swift")

  # If the target itself doesn't use Swift, check its deps.
  if not uses_swift:
    deps = getattr(ctx.rule.attr, "deps", [])
    swift_info_providers = providers.find_all(deps, AppleBundlingSwiftInfo)
    uses_swift = any([p.uses_swift for p in swift_info_providers])

  return AppleBundlingSwiftInfo(uses_swift=uses_swift)


def _apple_bundling_aspect_impl(target, ctx):
  """Implementation of `apple_bundling_aspect`.

  This implementation fans out the handling of each of its providers to a
  separate function.

  Args:
    target: The target on which the aspect is being applied.
    ctx: The Skylark context.
  Returns:
    A list of providers for the aspect. Refer to the rule documentation for a
    description of these providers.
  """
  providers = []

  # We can't provide AppleResourceInfo if the rule already provides it; if it
  # does so, it's that rule's responsibility to propagate the resources from
  # transitive dependencies.
  if AppleResourceInfo not in target:
    apple_resource_info = _transitive_apple_resource_info(target, ctx)
    if apple_resource_info:
      providers.append(apple_resource_info)

  apple_bundling_swift_info = _transitive_apple_bundling_swift_info(target, ctx)
  if apple_bundling_swift_info:
    providers.append(apple_bundling_swift_info)

  return providers


apple_bundling_aspect = aspect(
    implementation = _apple_bundling_aspect_impl,
    attr_aspects = ["bundles", "deps"],
)
"""
This aspect walks the dependency graph through the `deps` attribute and
collects information needed during the bundling process. For example, we
determine whether Swift is used anywhere within the dependency chain, and for
resources that need to be associated with a module when compiled (data models,
storyboards, and XIBs), we annotate those resources with that information as
well.

This aspect may propagate the `AppleResourceInfo` and `AppleBundlingSwiftInfo`
providers. Refer to the documentation for those providers for a description of
the fields they contain.
"""
