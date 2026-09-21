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
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@bazel_skylib//lib:types.bzl",
    "types",
)
load(
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "AppleFrameworkBundleInfo",
    "new_appleresourceinfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:bundle_paths.bzl",
    "bundle_paths",
)
load(
    "@rules_cc//cc/common:cc_info.bzl",
    "CcInfo",
)

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

_KNOWN_BINARY_ATTRS = ["deps", "avoid_deps"]

def _get_attr_using_list(*, attr, nested_attr, split_attr_key = None):
    """Helper method to always get an attribute as a list within an existing list.

     Args:
        attr: The attributes object on the current context. Can be either a `ctx.attr/ctx.rule.attr`
            -like struct that has targets/lists as its values, or a `ctx.split_attr`-like struct
            with the dictionary fan-out corresponding to split key.
        nested_attr: List of nested attributes to collect values from.
        split_attr_keys: If defined, a 1:2+ transition key to merge values from.

    Returns:
        The found attribute's value within a list, if it is not already a list. Otherwise returns
            the attribute's value if it is a list, or an empty list if the attribute had no value.
    """
    value = getattr(attr, nested_attr)

    value_is_dict = types.is_dict(value)
    if not split_attr_key and value_is_dict:
        fail("Internal Error: Value returned for this attribute is a dictionary, but no split " +
             "attribute key was provided. Attribute was %s." % nested_attr)

    if split_attr_key and value:
        if not value_is_dict:
            fail("Internal Error: Found a split attribute key but the value returned is not a " +
                 "dictionary. Attribute was %s, split key was %s." % (nested_attr, split_attr_key))
        value = value.get(split_attr_key)
    if not value:
        return []
    elif types.is_list(value):
        return value
    else:
        return [value]

def _get_attr_as_list(*, attr, nested_attr, split_attr_keys):
    """Helper method to always get an attribute as a list, supporting 1:2+ transitions.

     Args:
        attr: The attributes object on the current context. Can be either a `ctx.attr/ctx.rule.attr`
            -like struct that has targets/lists as its values, or a `ctx.split_attr`-like struct
            with the dictionary fan-out corresponding to split key.
        nested_attr: List of nested attributes to collect values from.
        split_attr_keys: If `attr` is a 1:2+ transition, a list of 1:2+ transition keys to merge
            values from. Otherwise this must be an empty list.

    Returns:
        The found attribute's value as a list, if a value was found. Otherwise returns an empty
            list if no value was found.
    """
    attr_as_list = []

    if len(split_attr_keys) == 0:
        # If no split keys were defined, search the attribute directly. This is expected to
        # aggregate values across all keys if a 1:2+ transition has been applied to the attribute.
        attr_as_list.extend(_get_attr_using_list(
            attr = attr,
            nested_attr = nested_attr,
        ))
    else:
        # Search the attribute within each split key if any split keys were defined.
        for split_attr_key in split_attr_keys:
            attr_as_list.extend(_get_attr_using_list(
                attr = attr,
                nested_attr = nested_attr,
                split_attr_key = split_attr_key,
            ))
    return attr_as_list

def _bucketize(
        *,
        allowed_buckets = None,
        owner = None,
        parent_dir_param = None,
        resources,
        swift_module = None):
    """Separates the given resources into resource bucket types and returns an AppleResourceInfo.

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
        allowed_buckets: List of buckets allowed for bucketing. Files that do not fall into these
            buckets will instead be placed into the "unprocessed" bucket. Defaults to `None` which
            means all buckets are allowed.
        owner: An optional string that has a unique identifier to the target that should own the
            resources. If an owner should be passed, it's usually equal to `str(ctx.label)`.
        parent_dir_param: Either a string/None or a function used to calculate the value of
            parent_dir for each resource. If it is a function, it will be considered a bundling task
            context, and will be invoked with ().
        resources: List of resources to bucketize.
        swift_module: The Swift module name to associate to these resources.

    Returns:
        An AppleResourceInfo provider with resources bucketized according to type.
    """
    buckets = {}
    owners = []
    unowned_resources = []

    # Transform the list of buckets to avoid into a set for faster lookup.
    allowed_bucket_set = {}
    if allowed_buckets:
        allowed_bucket_set = {k: None for k in allowed_buckets}

    for target in resources:
        for resource in target.files.to_list():
            # Local cache of the resource short path since it gets used quite a bit below.
            resource_short_path = resource.short_path

            if owner:
                owners.append((resource_short_path, owner))
            else:
                unowned_resources.append(resource_short_path)

            if types.is_string(parent_dir_param) or parent_dir_param == None:
                parent = parent_dir_param
            else:
                parent = parent_dir_param(resource = resource)

            # Special case for localized. If .lproj/ is in the path of the resource (and the parent
            # doesn't already have it) append the lproj component to the current parent.
            if ".lproj/" in resource_short_path and (not parent or ".lproj" not in parent):
                lproj_path = bundle_paths.farthest_parent(resource_short_path, "lproj")
                parent = paths.join(parent or "", paths.basename(lproj_path))

            resource_swift_module = None
            resource_depset = depset([resource])

            # For each type of resource, place in the appropriate bucket.
            if AppleFrameworkBundleInfo in target:
                if ".dSYM" in resource_short_path or resource.extension == "linkmap":
                    # Never ever bundle dSYMs or linkmaps since they should never, ever belong in
                    # resource processing. This goes for any "framework" outputs that do not belong
                    # in the shipping framework bundle itself.
                    continue
                bucket_name = "framework"
            elif (resource_short_path.endswith(".mergeable.strings")):
                bucket_name = "mergeable_strings"
            elif (resource_short_path.endswith(".strings") or
                  resource_short_path.endswith(".stringsdict")):
                bucket_name = "strings"
            elif resource_short_path.endswith(".storyboard"):
                bucket_name = "storyboards"
                resource_swift_module = swift_module
            elif resource_short_path.endswith(".xib"):
                bucket_name = "xibs"
                resource_swift_module = swift_module
            elif (".icon/" in resource_short_path or
                  ".xcassets/" in resource_short_path):
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
            elif ".xcstickers/" in resource_short_path:
                fail("""
.xcstickers for sticker packs are not supported, but one was found from {target}

Found at: {resource_short_path}
""".format(target = str(target.label), resource_short_path = resource_short_path))
            else:
                bucket_name = "unprocessed"

            # If the allowed bucket list is not empty, and the bucket is not allowed, change the
            # bucket to unprocessed instead.
            if allowed_bucket_set and bucket_name not in allowed_bucket_set:
                bucket_name = "unprocessed"
                resource_swift_module = None

            buckets.setdefault(bucket_name, []).append(
                (parent, resource_swift_module, resource_depset),
            )

    return new_appleresourceinfo(
        owners = depset(owners),
        unowned_resources = depset(unowned_resources),
        **dict([(k, _minimize(bucket = b)) for k, b in buckets.items()])
    )

def _bucketize_typed(
        *,
        bucket_type,
        expect_files = False,
        owner = None,
        parent_dir_param = None,
        resources):
    """Collects and bucketizes a specific type of resource and returns an AppleResourceInfo.

    Adds the given resources directly into a tuple under the field named in bucket_type. This avoids
    the sorting mechanism that `bucketize` does, while grouping resources together using
    parent_dir_param when available.

    Args:
        bucket_type: The AppleResourceInfo field under which to collect the resources.
        expect_files: Boolean. Wheither to expect that the List of resources is a list of Files,
            instead of Targets.
        owner: An optional string that has a unique identifier to the target that should own the
            resources. If an owner should be passed, it's usually equal to `str(ctx.label)`.
        parent_dir_param: Either a string/None or a struct used to calculate the value of
            parent_dir for each resource. If it is a struct, it will be considered a bundling task
            context, and will be invoked with ().
        resources: List of resources to place in bucket_type.

    Returns:
        An AppleResourceInfo provider with resources in the given bucket.
    """
    typed_bucket = []
    owners = []
    unowned_resources = []

    all_resources = []

    if expect_files:
        all_resources = resources
    else:
        all_resources = [f for t in resources for f in t.files.to_list()]

    for resource in all_resources:
        resource_short_path = resource.short_path
        if owner:
            owners.append((resource_short_path, owner))
        else:
            unowned_resources.append(resource_short_path)

        if types.is_string(parent_dir_param) or parent_dir_param == None:
            parent = parent_dir_param
        else:
            parent = parent_dir_param(resource)

        if ".lproj/" in resource_short_path and (not parent or ".lproj" not in parent):
            lproj_path = bundle_paths.farthest_parent(resource_short_path, "lproj")
            parent = paths.join(parent or "", paths.basename(lproj_path))

        typed_bucket.append((parent, None, depset(direct = [resource])))

    return new_appleresourceinfo(
        owners = depset(owners),
        unowned_resources = depset(unowned_resources),
        **dict([(bucket_type, _minimize(bucket = typed_bucket))])
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

def _validate_target_to_collect(*, binary_attr, res_attr, rule_label, target):
    """Validates that the given target can be collected as a resource.

    Args:
        binary_attr: Whether the attribute is known to be a binary attribute.
        res_attr: The resource attribute being collected from.
        rule_label: The label of the rule being analyzed.
        target: The target being collected.
    """

    # Avoid validation for attributes that are expected to safely handle library files.
    if binary_attr:
        return

    # Avoid collecting targets that generate library files (static or dynamic) as
    # resources from known resource-only attributes (e.g. "data", "resources").
    if CcInfo in target:
        libraries_found = [
            library
            for linker_input in target[CcInfo].linking_context.linker_inputs.to_list()
            for library in linker_input.libraries
        ]
        if libraries_found:
            fail("""
Error: {parent_target} has a static or dynamic library coming from a target referenced from the \
resource-only attribute `{res_attr}`:

{target}

This is not supported. Attempting to build resources from this target may lead to a static library \
or dynamic library being bundled in an unexpected location, which is not supported by the App Store.

Please move the dependency on {target} to the `deps` attribute of {parent_target}.""".format(
                parent_target = str(rule_label),
                target = str(target.label),
                res_attr = res_attr,
            ))

def _collect(
        *,
        attr,
        res_attrs = [],
        rule_label,
        skip_library_validation = False,
        split_attr_keys = []):
    """Collects all resource attributes present in the given attributes.

    Iterates over the given res_attrs attributes to be processed as resources.
    These are all placed into a list, and then returned.

    Args:
        attr: The attributes object on the current context. Can be either a `ctx.attr/ctx.rule.attr`
            -like struct that has targets/lists as its values, or a `ctx.split_attr`-like struct
            with the dictionary fan-out corresponding to split key.
        res_attrs: List of attributes to iterate over collecting resources.
        rule_label: The label of the rule being analyzed.
        skip_library_validation: Whether to skip validation of targets that generate libraries.
        split_attr_keys: If defined, a list of 1:2+ transition keys to merge values from.

    Returns:
        A list of all targets collected from the rule attr.
    """
    if not res_attrs:
        return []

    targets_with_files = []
    for res_attr in res_attrs:
        if not hasattr(attr, res_attr):
            continue

        targets_for_attr = _get_attr_as_list(
            attr = attr,
            nested_attr = res_attr,
            split_attr_keys = split_attr_keys,
        )
        if not targets_for_attr:
            continue

        binary_attr = True if res_attr in _KNOWN_BINARY_ATTRS else False
        for target in targets_for_attr:
            if not target.files:
                # Target does not export any File interfaces, ignore.
                continue
            if not skip_library_validation:
                _validate_target_to_collect(
                    binary_attr = binary_attr,
                    res_attr = res_attr,
                    rule_label = rule_label,
                    target = target,
                )
            targets_with_files.append(target)

    return targets_with_files

def _merge_providers(*, default_owner = None, providers, validate_all_resources_owned = False):
    """Merges multiple AppleResourceInfo providers into one.

    Args:
        default_owner: The default owner to be used for resources which have a None value in the
            `owners` dictionary. May be None, in which case no owner is marked.
        providers: The list of providers to merge. This method will fail unless there is at least 1
            provider in the list.
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
        fields = _populated_resource_fields(provider)
        for field in fields:
            buckets.setdefault(field, []).extend(getattr(provider, field))

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

    return new_appleresourceinfo(
        owners = depset(transitive = transitive_owners),
        unowned_resources = unowned_resources,
        **dict([(k, _minimize(bucket = v)) for (k, v) in buckets.items()])
    )

def _minimize(*, bucket):
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
        key = "%s_%s" % (parent_dir or "@root", swift_module or "@root")

        if parent_dir:
            parent_dir_by_key[key] = parent_dir
        if swift_module:
            swift_module_by_key[key] = swift_module

        # TODO(b/184668988): Audit Starlark performance of `dict.setdefault` vs. if/else statements.
        # Particularly for the resource aspect, using if/else statements yielded better results than
        # using `dict.setdefault` (from apple/internal/resources.bzl).
        if key in resources_by_key:
            resources_by_key[key].append(resources)
        else:
            resources_by_key[key] = [resources]

    return [
        (parent_dir_by_key.get(k, None), swift_module_by_key.get(k, None), depset(transitive = r))
        for k, r in resources_by_key.items()
    ]

def _nest_in_bundle(*, provider_to_nest, nesting_bundle_dir):
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

    return new_appleresourceinfo(
        owners = provider_to_nest.owners,
        unowned_resources = provider_to_nest.unowned_resources,
        **nested_provider_fields
    )

def _populated_resource_fields(provider):
    """Returns a list of field names of the provider's resource buckets that are non empty."""
    return [
        f
        for f in dir(provider)
        if f not in ["owners", "unowned_resources"]
    ]

def _structured_resources_parent_dir(*, parent_dir = None, resource):
    """Returns the package relative path for the parent directory of a resource.

    Args:
        parent_dir: Parent directory to prepend to the package relative path.
        resource: The resource for which to calculate the package relative path.

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
