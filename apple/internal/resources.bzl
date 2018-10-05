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

Resource are propagated using NewAppleResourceInfo, in which each field (or bucket) contains data
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

During propagation, each target will need to merge multiple NewAppleResourceInfo providers coming
from dependencies. Merging will then aggressively minimize the tuples in order to only have one
tuple per parent_dir per swift_module per bucket.

NewAppleResourceInfo also has a `owners` field which contains a map with the short paths of every
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
is is the objc_bundle rule. This rule doesn't contain any code, so the resources represented by
these targets should not be bound to the objc_bundle target, as they should be marked as being owned
by the objc_library or swift_library targets that reference them.

The None values in the `owners` dictionary are then replaced with a default owner in the
`merge_providers` method, which should be called to merge a list of providers into a single
NewAppleResourceInfo provider to be returned as the provider of the target, and to bundle the
resources contained within in the top-level bundling rules.

This file provides methods to easily:
    - collect all resource files from the different rules and their attributes
    - bucketize each of the resources into specific buckets depending on their path
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
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)

NewAppleResourceInfo = provider(
    doc = "Provider that propagates buckets of resources that are differentiated by type.",
    fields = {
        "asset_catalogs": "Resources that need to be embedded into Assets.car.",
        "datamodels": "Datamodel files.",
        "infoplists": """Plist files to be merged and processed. Plist files that should not be
merged into the root Info.plist should be propagated in `plists`. Because of this, infoplists should
only be bucketed with the `bucketize_typed` method.""",
        "plists": "Resource Plist files that should not be merged into Info.plist",
        "pngs": "PNG images which are not bundled in an .xcassets folder.",
        # TODO(b/113252360): Remove this once we can correctly process Fileset files.
        "resource_zips": "ZIP files that need to be extracted into the resources bundle location.",
        "storyboards": "Storyboard files.",
        "strings": "Localization strings files.",
        "texture_atlases": "Texture atlas files.",
        "unprocessed": "Generic resources not mapped to the other types.",
        "xibs": "XIB Interface files.",
        "owners": """Map of resource short paths to a depset of strings that represent targets that
declare ownership of that resource.""",
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

def _bucketize(
        resources,
        swift_module = None,
        owner = None,
        parent_dir_param = None,
        avoid_buckets = None):
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

    Finally, it will return a NewAppleResourceInfo provider with the resources bucketed per type.

    Args:
        resources: List of resources to bucketize.
        swift_module: The Swift module name to associate to these resources.
        owner: An optional string that has a unique identifier to the target that should own the
            resources. If an owner should be passed, it's usually equal to `str(ctx.label)`.
        parent_dir_param: Either a string or a struct used to calculate the value of parent_dir for
            each resource. If it is a struct, it will be considered a partial context, and will be
            invoked with partial.call().
        avoid_buckets: List of buckets to avoid when bucketing. Used to mark certain file types to
            avoid being processed, as they will fall into the "unprocessed" bucket.

    Returns:
        A NewAppleResourceInfo provider with resources bucketized according to type.
    """
    buckets = {}
    owners = {}
    owner_depset = None

    # Transform the list of buckets to avoid into a set for faster lookup.
    avoid_bucket_set = {}
    if avoid_buckets:
        avoid_bucket_set = {k: None for k in avoid_buckets}

    if owner:
        # By using one depset reference, we can save memory for the cases where multiple resources
        # only have one owner.
        owner_depset = depset(direct = [owner])
    for resource in resources:
        # Local cache of the resource short path since it gets used quite a bit below.
        resource_short_path = resource.short_path

        owners[resource_short_path] = owner_depset
        if str(type(parent_dir_param)) == "struct":
            parent = partial.call(parent_dir_param, resource)
        else:
            parent = parent_dir_param

        # Special case for localized. If .lproj/ is in the path of the resource (and the parent
        # doesn't already have it) append the lproj component to the current parent.
        if ".lproj/" in resource_short_path and (not parent or ".lproj" not in parent):
            lproj_path = path_utils.farthest_directory_matching(resource_short_path, "lproj")
            parent = paths.join(parent or "", paths.basename(lproj_path))

        # For each type of resource, place in appropriate bucket.
        if resource_short_path.endswith(".strings"):
            buckets.setdefault(
                "strings",
                default = [],
            ).append((parent, None, depset(direct = [resource])))
        elif resource_short_path.endswith(".storyboard"):
            buckets.setdefault(
                "storyboards",
                default = [],
            ).append((parent, swift_module, depset(direct = [resource])))
        elif resource_short_path.endswith(".xib"):
            buckets.setdefault(
                "xibs",
                default = [],
            ).append((parent, swift_module, depset(direct = [resource])))
        elif ".xcassets/" in resource_short_path or ".xcstickers/" in resource_short_path:
            buckets.setdefault(
                "asset_catalogs",
                default = [],
            ).append((parent, None, depset(direct = [resource])))
        elif ".xcdatamodel" in resource_short_path or ".xcmappingmodel/" in resource_short_path:
            buckets.setdefault(
                "datamodels",
                default = [],
            ).append((parent, swift_module, depset(direct = [resource])))
        elif ".atlas" in resource_short_path:
            buckets.setdefault(
                "texture_atlases",
                default = [],
            ).append((parent, None, depset(direct = [resource])))
        elif not "pngs" in avoid_bucket_set and resource_short_path.endswith(".png"):
            # Process standalone pngs last so that special resource types that use png can be
            # bucketed correctly.

            buckets.setdefault(
                "pngs",
                default = [],
            ).append((parent, None, depset(direct = [resource])))
        elif resource_short_path.endswith(".plist"):
            buckets.setdefault(
                "plists",
                default = [],
            ).append((parent, None, depset(direct = [resource])))
        else:
            buckets.setdefault(
                "unprocessed",
                default = [],
            ).append((parent, None, depset(direct = [resource])))

    return NewAppleResourceInfo(
        owners = owners,
        **dict([(k, _minimize(b)) for k, b in buckets.items()])
    )

def _bucketize_typed(resources, bucket_type, owner = None, parent_dir_param = None):
    """Collects and bucketizes a specific type of resource.

    Adds the given resources directly into a NewAppleResourceInfo provider under the field named in
    bucket_type. This avoids the sorting mechanism that `bucketize` does, while grouping resources
    together using parent_dir_param.

    Args:
        resources: List of resources to place in bucket_type.
        bucket_type: The NewAppleResourceInfo field under which to collect the resources.
        owner: An optional string that has a unique identifier to the target that should own the
            resources. If an owner should be passed, it's usually equal to `str(ctx.label)`.
        parent_dir_param: Either a string or a struct used to calculate the value of parent_dir for
            each resource. If it is a struct, it will be considered a partial context, and will be
            invoked with partial.call().

    Returns:
        A NewAppleResourceInfo provider with resources in the given bucket.
    """
    typed_bucket = []
    owners = {}
    owner_depset = None
    if owner:
        # By using one depset reference, we can save memory for the cases where multiple resources
        # only have one owner.
        owner_depset = depset(direct = [owner])
    for resource in resources:
        resource_short_path = resource.short_path
        owners[resource_short_path] = owner_depset
        if str(type(parent_dir_param)) == "struct":
            parent = partial.call(parent_dir_param, resource)
        else:
            parent = parent_dir_param

        if ".lproj/" in resource_short_path and (not parent or ".lproj" not in parent):
            lproj_path = path_utils.farthest_directory_matching(resource_short_path, "lproj")
            parent = paths.join(parent or "", paths.basename(lproj_path))

        typed_bucket.append((parent, None, depset(direct = [resource])))
    return NewAppleResourceInfo(owners = owners, **{bucket_type: _minimize(typed_bucket)})

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
    bundle_path = path_utils.farthest_directory_matching(resource.short_path, extension)
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
    """Merges multiple NewAppleResourceInfo providers into one.

    Args:
        providers: The list of providers to merge. This method will fail unless there is at least 1
            provider in the list.
        default_owner: The default owner to be used for resources which have a None value in the
            `owners` dictionary. May be None, in which case no owner is marked.
        validate_all_resources_owned: Whether to validate that all resources are owned. This is
            useful for top-level rules to ensure that the resources in NewAppleResourceInfo that
            they are propagating are fully owned. If default_owner is set, this attribute does
            nothing, as by definition the resources will all have a default owner.

    Returns:
        A NewAppleResourceInfo provider with the results of the merge of the given providers.
    """
    if not providers:
        fail(
            "merge_providers should be called with a non-empty list of providers. This is most " +
            "likely a bug in rules_apple, please file a bug with reproduction steps.",
        )

    if len(providers) == 1:
        return providers[0]

    buckets = {}
    owners = {}
    default_owner_depset = None
    if default_owner:
        # By using one depset reference, we can save memory for the cases where multiple resources
        # only have one owner.
        default_owner_depset = depset(direct = [default_owner])
    for provider in providers:
        # Get the initialized fields in the provider, with the exception of to_json and to_proto,
        # which are not desireable for our use case.
        fields = _populated_resource_fields(provider)
        for field in fields:
            buckets.setdefault(
                field,
                default = [],
            ).extend(getattr(provider, field))
        for resource_path, resource_owners in provider.owners.items():
            collected_owners = owners.get(resource_path)
            transitive = []
            if collected_owners:
                transitive.append(collected_owners)

            # If there is no owner marked for this resource, use the default_owner as an owner, if
            # it exists.
            if resource_owners:
                transitive.append(resource_owners)
            elif default_owner_depset:
                transitive.append(default_owner_depset)
            elif validate_all_resources_owned:
                fail(
                    "The given providers have a resource that doesn't have an owner, and " +
                    "validate_all_resources_owned was set. This is most likely a bug in " +
                    "rules_apple, please file a bug with reproduction steps.",
                )
            if transitive:
                # If there is only one transitive depset, avoid creating a new depset, just
                # propagate it.
                if len(transitive) == 1:
                    final_depset = transitive[0]
                else:
                    final_depset = depset(transitive = transitive)
            else:
                final_depset = None
            owners[resource_path] = final_depset

    return NewAppleResourceInfo(
        owners = owners,
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

def _nest_bundles(provider_to_nest, nesting_bundle_dir):
    """Nests resources in a NewAppleResourceInfo provider under a new parent bundle directory.

    This method is mostly used by rules that create resource bundles in order to nest other resource
    bundle targets within themselves. For instance, objc_bundle_library supports the bundles
    attribute, through which other objc_bundle_library or objc_bundle targets can be added. In these
    use cases, the dependency bundles are added as nested bundles into the dependent bundle.

    This method prepends the parent_dir field in the buckets with the given
    nesting_bundle_dir argument.

    Args:
        provider_to_nest: A NewAppleResourceInfo provider with the resources to nest.
        nesting_bundle_dir: The new bundle directory under which to bundle the resources.

    Returns:
        A new NewAppleResourceInfo provider with the resources nested under nesting_bundle_dir.
    """
    nested_provider_fields = {}
    for field in _populated_resource_fields(provider_to_nest):
        nested_provider_fields[field] = [
            (paths.join(nesting_bundle_dir, parent_dir or ""), swift_module, files)
            for parent_dir, swift_module, files in getattr(provider_to_nest, field)
        ]

    return NewAppleResourceInfo(
        owners = provider_to_nest.owners,
        **nested_provider_fields
    )

def _populated_resource_fields(provider):
    """Returns a list of field names of the provider's resource buckets that are non empty."""

    # TODO(b/36412967): Remove the to_json and to_proto elements of this list.
    return [f for f in dir(provider) if f not in ["owners", "to_json", "to_proto"]]

def _structured_resources_parent_dir(resource, parent_dir):
    """Returns the package relative path for the parent directory of a resource.

    Args:
        resource: The resource for which to calculate the package relative path.
        parent_dir: Parent directory to prepend to the package relative path.

    Returns:
        The package relative path to the parent directory of the resource.
    """
    package_relative = path_utils.owner_relative_path(resource)
    path = paths.dirname(package_relative).rstrip("/")
    return paths.join(parent_dir or "", path or "") or None

resources = struct(
    bucketize = _bucketize,
    bucketize_typed = _bucketize_typed,
    bundle_relative_parent_dir = _bundle_relative_parent_dir,
    collect = _collect,
    merge_providers = _merge_providers,
    minimize = _minimize,
    nest_bundles = _nest_bundles,
    populated_resource_fields = _populated_resource_fields,
    structured_resources_parent_dir = _structured_resources_parent_dir,
)
