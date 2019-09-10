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

Resource are propagated using AppleResourceInfo, in which each field (or bucket) contains data
for resources that should be bundled inside top-level Apple bundles (e.g. ios_application).

Each bucket contains a list of tuples with the following schema:

    (parent_dir, swift_module, resource_files)

    - parent_dir: This is the target path relative to the root of the bundle that will embed the
        resource_files. Each of the resource_files will be copied into a directory structure that
        matches parent_dir. If parent_dir is None, the resources will be placed in the root level.
        For structured resources where the relative path to the target must be preserved,
        parent_dir might look like "some/dir/path". For bundles, parent_dir might look like
        "Resource.bundle".
    - swift_module: This is the name of the Swift module, should the resources had been added
        through a swift_library rule. This is needed as some resource types require this value when
        being compiled (e.g. xibs).
    - resource_files: This is a depset of all the files that should be placed under parent_dir.

During propagation, each target will need to merge multiple AppleResourceInfo providers coming
from dependencies. Merging will then aggressively minimize the tuples in order to only have one
tuple per parent_dir per swift_module per bucket.

AppleResourceInfo also has a `owners` field which contains a map with the short paths of every
resource in the buckets as keys, and a depset of the targets that declare usage as owner of that
resource as values. This dictionary is meant to be used during the deduplication phase, to account
for each usage of the resources in the dependency graph and avoid deduplication if the resource is
used in code higher level bundles. With this, every target is certain that the resource they
reference will be packaged in the same bundle as the code they implement, ensuring that
`[NSBundle bundleForClass:[self class]]` will always return a bundle containing the requested
resource.

In some cases the value for certain keys in `owners` may be None. This value is used to signal that
the target referencing the resource should not be considered the owner, and that the next target in
the dependency chain that can own resources should set itself as the owner. A good example of this
is is the apple_bundle_import rule. This rule doesn't contain any code, so the resources represented
by these targets should not be bound to the apple_bundle_import target, as they should be marked as
being owned by the objc_library or swift_library targets that reference them.

The None values in the `owners` dictionary are then replaced with a default owner in the
`merge_providers` method, which should be called to merge a list of providers into a single
AppleResourceInfo provider to be returned as the provider of the target, and to bundle the
resources contained within in the top-level bundling rules.

This file provides methods to easily:
    - collect all resource files from the different rules and their attributes
    - bucketize each of the resources into specific buckets depending on their path
    - minimize the resulting tuples in order to minimize memory usage
"""

load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleResourceInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:bundle_paths.bzl",
    "bundle_paths",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@bazel_skylib//lib:types.bzl",
    "types",
)

def _get_attr_as_list(attr, attribute):
    """Helper method to always get an attribute as a list."""
    value = getattr(attr, attribute)
    if not value:
        return []
    if types.is_list(value):
        return value
    return [value]

def _bucketize(
        resources,
        swift_module = None,
        owner = None,
        parent_dir_param = None,
        allowed_buckets = None):
    """Separates the given resources into resource bucket types.

    This method takes a list of resources and constructs a tuple object for each, placing it inside
    the correct bucket.

    The parent_dir is calculated from the parent_dir_param object. This object can either be None
    (the default), a string object, or a function object. If a function is provided, it should
    accept only 1 parameter, which will be the File object representing the resource to bucket. This
    mechanism gives us a simpler way to manage multiple use cases. For example, when used to
    bucketize structured resources, the parent_dir_param can be a function that returns the relative
    path to the owning package; or in an objc_library it can be None, signaling that these resources
    should be placed in the root level.

    If no bucket was detected based on the short path for a specific resource, it will be placed
    into the "unprocessed" bucket. Resources in this bucket will not be processed and will be copied
    as is. Once all resources have been placed in buckets, each of the lists will be minimized.

    Finally, it will return a AppleResourceInfo provider with the resources bucketed per type.

    Args:
        resources: List of resources to bucketize.
        swift_module: The Swift module name to associate to these resources.
        owner: An optional string that has a unique identifier to the target that should own the
            resources. If an owner should be passed, it's usually equal to `str(ctx.label)`.
        parent_dir_param: Either a string/None or a struct used to calculate the value of
            parent_dir for each resource. If it is a struct, it will be considered a partial
            context, and will be invoked with partial.call().
        allowed_buckets: List of buckets allowed for bucketing. Files that do not fall into these
            buckets will instead be placed into the "unprocessed" bucket. Defaults to `None` which
            means all buckets are allowed.

    Returns:
        A AppleResourceInfo provider with resources bucketized according to type.
    """
    buckets = {}
    owners = []
    unowned_resources = []

    # Transform the list of buckets to avoid into a set for faster lookup.
    allowed_bucket_set = {}
    if allowed_buckets:
        allowed_bucket_set = {k: None for k in allowed_buckets}

    for resource in resources:
        # Local cache of the resource short path since it gets used quite a bit below.
        resource_short_path = resource.short_path

        if owner:
            owners.append((resource_short_path, owner))
        else:
            unowned_resources.append(resource_short_path)

        if types.is_string(parent_dir_param) or parent_dir_param == None:
            parent = parent_dir_param
        else:
            parent = partial.call(parent_dir_param, resource)

        # Special case for localized. If .lproj/ is in the path of the resource (and the parent
        # doesn't already have it) append the lproj component to the current parent.
        if ".lproj/" in resource_short_path and (not parent or ".lproj" not in parent):
            lproj_path = bundle_paths.farthest_parent(resource_short_path, "lproj")
            parent = paths.join(parent or "", paths.basename(lproj_path))

        resource_swift_module = None
        resource_depset = depset([resource])

        # For each type of resource, place in appropriate bucket.
        if resource_short_path.endswith(".strings") or resource_short_path.endswith(".stringsdict"):
            bucket_name = "strings"
        elif resource_short_path.endswith(".storyboard"):
            bucket_name = "storyboards"
            resource_swift_module = swift_module
        elif resource_short_path.endswith(".xib"):
            bucket_name = "xibs"
            resource_swift_module = swift_module
        elif ".xcassets/" in resource_short_path or ".xcstickers/" in resource_short_path:
            bucket_name = "asset_catalogs"
        elif ".xcdatamodel" in resource_short_path or ".xcmappingmodel/" in resource_short_path:
            bucket_name = "datamodels"
            resource_swift_module = swift_module
        elif ".atlas" in resource_short_path:
            bucket_name = "texture_atlases"
        elif resource_short_path.endswith(".png"):
            # Process standalone pngs after asset_catalogs and texture_atlases so the latter can
            # bucketed correctly.
            bucket_name = "pngs"
        elif resource_short_path.endswith(".plist"):
            bucket_name = "plists"
        elif resource_short_path.endswith(".mlmodel"):
            bucket_name = "mlmodels"
        else:
            bucket_name = "unprocessed"

        # If the allowed bucket list is not empty, and the bucket is not allowed, change the bucket
        # to unprocessed instead.
        if allowed_bucket_set and bucket_name not in allowed_bucket_set:
            bucket_name = "unprocessed"
            resource_swift_module = None

        buckets.setdefault(
            bucket_name,
            default = [],
        ).append((parent, resource_swift_module, resource_depset))

    return AppleResourceInfo(
        owners = depset(owners),
        unowned_resources = depset(unowned_resources),
        **dict([(k, _minimize(b)) for k, b in buckets.items()])
    )

def _bucketize_typed(resources, bucket_type, owner = None, parent_dir_param = None):
    """Collects and bucketizes a specific type of resource.

    Adds the given resources directly into a AppleResourceInfo provider under the field named in
    bucket_type. This avoids the sorting mechanism that `bucketize` does, while grouping resources
    together using parent_dir_param.

    Args:
        resources: List of resources to place in bucket_type.
        bucket_type: The AppleResourceInfo field under which to collect the resources.
        owner: An optional string that has a unique identifier to the target that should own the
            resources. If an owner should be passed, it's usually equal to `str(ctx.label)`.
        parent_dir_param: Either a string/None or a struct used to calculate the value of
            parent_dir for each resource. If it is a struct, it will be considered a partial
            context, and will be invoked with partial.call().

    Returns:
        A AppleResourceInfo provider with resources in the given bucket.
    """
    typed_bucket = []
    owners = []
    unowned_resources = []

    for resource in resources:
        resource_short_path = resource.short_path
        if owner:
            owners.append((resource_short_path, owner))
        else:
            unowned_resources.append(resource_short_path)

        if types.is_string(parent_dir_param) or parent_dir_param == None:
            parent = parent_dir_param
        else:
            parent = partial.call(parent_dir_param, resource)

        if ".lproj/" in resource_short_path and (not parent or ".lproj" not in parent):
            lproj_path = bundle_paths.farthest_parent(resource_short_path, "lproj")
            parent = paths.join(parent or "", paths.basename(lproj_path))

        typed_bucket.append((parent, None, depset(direct = [resource])))

    return AppleResourceInfo(
        owners = depset(owners),
        unowned_resources = depset(unowned_resources),
        **{bucket_type: _minimize(typed_bucket)}
    )

def _bundle_relative_parent_dir(resource, extension):
    """Returns the bundle relative path to the resource rooted at the bundle.

    Looks for the first instance of a folder with the suffix specified by `extension`, and then
    returns the directory path to the file within the bundle. For example, for a resource with path
    my/package/Contents.bundle/directory/foo.txt and `extension` equal to `"bundle"`, it would
    return Contents.bundle/directory.

    Args:
        resource: The resource for which to calculate the bundle relative path.
        extension: The bundle extension to use when finding the relative path.

    Returns:
        The bundle relative path, rooted at the outermost bundle.
    """
    bundle_path = bundle_paths.farthest_parent(resource.short_path, extension)
    bundle_relative_path = paths.relativize(resource.short_path, bundle_path)

    parent_dir = paths.basename(bundle_path)
    bundle_relative_dir = paths.dirname(bundle_relative_path).strip("/")
    if bundle_relative_dir:
        parent_dir = paths.join(parent_dir, bundle_relative_dir)
    return parent_dir

def _collect(attr, res_attrs = []):
    """Collects all resource attributes present in the given attributes.

    Iterates over the given res_attrs attributes collecting files to be processed as resources.
    These are all placed into a list, and then returned.

    Args:
        attr: The attributes object as returned by ctx.attr (or ctx.rule.attr) in the case of
            aspects.
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

def _merge_providers(providers, default_owner = None, validate_all_resources_owned = False):
    """Merges multiple AppleResourceInfo providers into one.

    Args:
        providers: The list of providers to merge. This method will fail unless there is at least 1
            provider in the list.
        default_owner: The default owner to be used for resources which have a None value in the
            `owners` dictionary. May be None, in which case no owner is marked.
        validate_all_resources_owned: Whether to validate that all resources are owned. This is
            useful for top-level rules to ensure that the resources in AppleResourceInfo that
            they are propagating are fully owned. If default_owner is set, this attribute does
            nothing, as by definition the resources will all have a default owner.

    Returns:
        A AppleResourceInfo provider with the results of the merge of the given providers.
    """
    if not providers:
        fail(
            "merge_providers should be called with a non-empty list of providers. This is most " +
            "likely a bug in rules_apple, please file a bug with reproduction steps.",
        )

    if not default_owner and validate_all_resources_owned == False and len(providers) == 1:
        # Short path to avoid the merging and validation loops if the loop won't change the owners
        # mapping nor validate that all resources are marked as owned.
        return providers[0]

    buckets = {}

    for provider in providers:
        # Get the initialized fields in the provider, with the exception of to_json and to_proto,
        # which are not desireable for our use case.
        fields = _populated_resource_fields(provider)
        for field in fields:
            buckets.setdefault(
                field,
                default = [],
            ).extend(getattr(provider, field))

    # unowned_resources is a depset of resource paths.
    unowned_resources = depset(transitive = [provider.unowned_resources for provider in providers])

    # owners is a depset of (resource_path, owner) pairs.
    transitive_owners = [provider.owners for provider in providers]

    # If owner is set, this rule now owns all previously unowned resources.
    if default_owner:
        transitive_owners.append(
            depset([(resource, default_owner) for resource in unowned_resources.to_list()]),
        )
        unowned_resources = depset()
    elif validate_all_resources_owned:
        if unowned_resources.to_list():
            fail(
                "The given providers have a resource that doesn't have an owner, and " +
                "validate_all_resources_owned was set. This is most likely a bug in " +
                "rules_apple, please file a bug with reproduction steps.",
            )

    return AppleResourceInfo(
        owners = depset(transitive = transitive_owners),
        unowned_resources = unowned_resources,
        **dict([(k, _minimize(v)) for (k, v) in buckets.items()])
    )

def _minimize(bucket):
    """Minimizes the given list of tuples into the smallest subset possible.

    Takes the list of tuples that represent one resource bucket, and minimizes it so that 2 tuples
    with resources that should be placed under the same location are merged into 1 tuple.

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
            key,
            default = [],
        ).append(resources)

    return [
        (parent_dir_by_key.get(k, None), swift_module_by_key.get(k, None), depset(transitive = r))
        for k, r in resources_by_key.items()
    ]

def _nest_in_bundle(provider_to_nest, nesting_bundle_dir):
    """Nests resources in a AppleResourceInfo provider under a new parent bundle directory.

    This method is mostly used by rules that create resource bundles in order to nest other resource
    bundle targets within themselves. For instance, apple_resource_bundle supports nesting other
    bundles through the resources attribute. In these use cases, the dependency bundles are added as
    nested bundles into the dependent bundle.

    This method prepends the parent_dir field in the buckets with the given
    nesting_bundle_dir argument.

    Args:
        provider_to_nest: A AppleResourceInfo provider with the resources to nest.
        nesting_bundle_dir: The new bundle directory under which to bundle the resources.

    Returns:
        A new AppleResourceInfo provider with the resources nested under nesting_bundle_dir.
    """
    nested_provider_fields = {}
    for field in _populated_resource_fields(provider_to_nest):
        for parent_dir, swift_module, files in getattr(provider_to_nest, field):
            if parent_dir:
                nested_parent_dir = paths.join(nesting_bundle_dir, parent_dir)
            else:
                nested_parent_dir = nesting_bundle_dir
            nested_provider_fields.setdefault(field, []).append(
                (nested_parent_dir, swift_module, files),
            )

    return AppleResourceInfo(
        owners = provider_to_nest.owners,
        unowned_resources = provider_to_nest.unowned_resources,
        **nested_provider_fields
    )

def _populated_resource_fields(provider):
    """Returns a list of field names of the provider's resource buckets that are non empty."""

    # TODO(b/36412967): Remove the to_json and to_proto elements of this list.
    return [
        f
        for f in dir(provider)
        if f not in ["owners", "unowned_resources", "to_json", "to_proto"]
    ]

def _structured_resources_parent_dir(resource, parent_dir = None):
    """Returns the package relative path for the parent directory of a resource.

    Args:
        resource: The resource for which to calculate the package relative path.
        parent_dir: Parent directory to prepend to the package relative path.

    Returns:
        The package relative path to the parent directory of the resource.
    """
    package_relative = bundle_paths.owner_relative_path(resource)
    if resource.is_directory:
        path = package_relative
    else:
        path = paths.dirname(package_relative).rstrip("/")
    return paths.join(parent_dir or "", path or "") or None

resources = struct(
    bucketize = _bucketize,
    bucketize_typed = _bucketize_typed,
    bundle_relative_parent_dir = _bundle_relative_parent_dir,
    collect = _collect,
    merge_providers = _merge_providers,
    minimize = _minimize,
    nest_in_bundle = _nest_in_bundle,
    populated_resource_fields = _populated_resource_fields,
    structured_resources_parent_dir = _structured_resources_parent_dir,
)
