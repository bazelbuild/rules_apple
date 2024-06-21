# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Implementation of apple_resource_bundle rule."""

load(
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "new_appleresourcebundleinfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:resources.bzl",
    "resources",
)
load(
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)
load(
    "@build_bazel_rules_apple//apple/internal:outputs.bzl",
    "outputs",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_attrs.bzl",
    "rule_attrs",
)
load(
    "@build_bazel_rules_apple//apple/internal:transition_support.bzl",
    "transition_support",
)

def _apple_resource_bundle_impl(_ctx):
    # Owner to attach to the resources as they're being bucketed.
    owner = None

    bundle_name = "{}.bundle".format(ctx.attr.bundle_name or ctx.label.name)
    bundle_id = ctx.attr.bundle_id or None

    apple_resource_infos = []
    process_args = {
        "actions": ctx.actions,
        "apple_mac_toolchain_info": ctx.attr._mac_toolchain[AppleMacToolsToolchainInfo],
        "bundle_id": bundle_id,
        "product_type": None,
        "rule_label": ctx.label,
    }

    infoplists = resources.collect(
        attr = ctx.attr,
        res_attrs = ["infoplists"],
    )
    if infoplists:
        bucketized_owners, unowned_resources, buckets = resources.bucketize_typed_data(
            bucket_type = "infoplists",
            owner = owner,
            parent_dir_param = bundle_name,
            resources = infoplists,
            **bucketize_args
        )
        apple_resource_infos.append(
            resources.process_bucketized_data(
                bucketized_owners = bucketized_owners,
                buckets = buckets,
                platform_prerequisites = struct(),  # ME: Unsure what to do with this
                processing_owner = owner,
                unowned_resources = unowned_resources,
                **process_args
            ),
        )

    resource_files = resources.collect(
        attr = ctx.attr,
        res_attrs = ["resources"],
    )

    if resource_files:
        bucketized_owners, unowned_resources, buckets = resources.bucketize_data(
            resources = resource_files,
            owner = owner,
            parent_dir_param = bundle_name,
            **bucketize_args
        )
        apple_resource_infos.append(
            resources.process_bucketized_data(
                bucketized_owners = bucketized_owners,
                buckets = buckets,
                platform_prerequisites = struct(),  # ME: Unsure what to do with this
                processing_owner = owner,
                unowned_resources = unowned_resources,
                **process_args
            ),
        )

    structured_files = resources.collect(
        attr = ctx.attr,
        res_attrs = ["structured_resources"],
    )
    if structured_files:
        if bundle_name:
            structured_parent_dir_param = partial.make(
                resources.structured_resources_parent_dir,
                parent_dir = bundle_name,
            )
        else:
            structured_parent_dir_param = partial.make(
                resources.structured_resources_parent_dir,
            )

        # Avoid processing PNG files that are referenced through the structured_resources
        # attribute. This is mostly for legacy reasons and should get cleaned up in the future.
        bucketized_owners, unowned_resources, buckets = resources.bucketize_data(
            allowed_buckets = ["strings", "plists"],
            owner = owner,
            parent_dir_param = structured_parent_dir_param,
            resources = structured_files,
            **bucketize_args
        )
        apple_resource_infos.append(
            resources.process_bucketized_data(
                bucketized_owners = bucketized_owners,
                buckets = buckets,
                platform_prerequisites = struct(),  # ME: Unsure what to do with this
                processing_owner = owner,
                unowned_resources = unowned_resources,
                **process_args
            ),
        )

    apple_mac_toolchain_info = ctx.attr._mac_toolchain[AppleMacToolsToolchainInfo]
    apple_xplat_toolchain_info = ctx.attr._xplat_toolchain[AppleXPlatToolsToolchainInfo]

    processor_partials = [
        partials.apple_bundle_info_partial(
            actions = ctx.actions,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            executable_name = "executable_name",
            label_name = ctx.label.name,
            platform_prerequisites = struct(),  # ME: Unsure what to do with this
            product_type = "product_type",
            rule_descriptor = "rule_descriptor",
        ),
        partials.resources_partial(
            actions = ctx.actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            executable_name = "executable_name",
            launch_storyboard = None,
            platform_prerequisites = struct(),  # ME: Unsure what to do with this
            resource_deps = ctx.attr.resources + ctx.attr.structured_resources,
            rule_descriptor = "rule_descriptor",
            rule_label = label,
            # targets_to_avoid = ctx.attr.frameworks,
            top_level_infoplists = ctx.attr.infoplists,
            top_level_resources = ctx.attr.resources,
            version = ctx.attr.version,
            version_keys_required = False,
        ),
    ]

    processor_result = processor.process(
        actions = ctx.actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_name = bundle_name,
        partials = processor_partials,
        platform_prerequisites = struct(),  # ME: Unsure what to do with this
        rule_descriptor = "rule_descriptor",
        rule_label = ctx.label,
    )

    return [
        # TODO(b/122578556): Remove this ObjC provider instance.
        apple_common.new_objc_provider(),
        CcInfo(),
        new_appleresourcebundleinfo(),
        DefaultInfo(
            files = processor_result.output_files,
        ),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                processor_result.output_groups,
            )
        ),
    ].extend(resources.merge_providers(
        default_owner = owner,
        providers = apple_resource_infos,
    )) + processor_result.providers

apple_resource_bundle = rule(
    implementation = _apple_resource_bundle_impl,
    attrs = [
        rule_attrs.common_bundle_attrs(deps_cfg = transition_support.apple_platform_split_transition),
        rule_attrs.common_tool_attrs(),
        rule_attrs.infoplist_attrs(),
        rule_attrs.platform_attrs(
            platform_type = "ios",
            add_environment_plist = True,
        ),
        {
            "bundle_id": attr.string(
                doc = """
    The bundle ID for this target. It will replace `$(PRODUCT_BUNDLE_IDENTIFIER)` found in the files
    from defined in the `infoplists` paramter.
    """,
            ),
            "bundle_name": attr.string(
                doc = """
    The desired name of the bundle (without the `.bundle` extension). If this attribute is not set,
    then the `name` of the target will be used instead.
    """,
            ),
            "infoplists": attr.label_list(
                allow_empty = True,
                allow_files = True,
                doc = """
    A list of `.plist` files that will be merged to form the `Info.plist` that represents the extension.
    At least one file must be specified.
    Please see [Info.plist Handling](/doc/common_info.md#infoplist-handling") for what is supported.

    Duplicate keys between infoplist files
    will cause an error if and only if the values conflict.
    Bazel will perform variable substitution on the Info.plist file for the following values (if they
    are strings in the top-level dict of the plist):

    ${BUNDLE_NAME}: This target's name and bundle suffix (.bundle or .app) in the form name.suffix.
    ${PRODUCT_NAME}: This target's name.
    ${TARGET_NAME}: This target's name.
    The key in ${} may be suffixed with :rfc1034identifier (for example
    ${PRODUCT_NAME::rfc1034identifier}) in which case Bazel will replicate Xcode's behavior and replace
    non-RFC1034-compliant characters with -.
    """,
            ),
            "resources": attr.label_list(
                allow_empty = True,
                allow_files = True,
                doc = """
    Files to include in the resource bundle. Files that are processable resources, like .xib,
    .storyboard, .strings, .png, and others, will be processed by the Apple bundling rules that have
    those files as dependencies. Other file types that are not processed will be copied verbatim. These
    files are placed in the root of the resource bundle (e.g. `Payload/foo.app/bar.bundle/...`) in most
    cases. However, if they appear to be localized (i.e. are contained in a directory called *.lproj),
    they will be placed in a directory of the same name in the app bundle.

    You can also add other `apple_resource_bundle` and `apple_bundle_import` targets into `resources`,
    and the resource bundle structures will be propagated into the final bundle.
    """,
            ),
            "structured_resources": attr.label_list(
                allow_empty = True,
                allow_files = True,
                doc = """
    Files to include in the final resource bundle. They are not processed or compiled in any way
    besides the processing done by the rules that actually generate them. These files are placed in the
    bundle root in the same structure passed to this argument, so `["res/foo.png"]` will end up in
    `res/foo.png` inside the bundle.
    """,
            ),
        },
    ],
    doc = """
This rule encapsulates a target which is provided to dependers as a bundle. An
`apple_resource_bundle`'s resources are put in a resource bundle in the top
level Apple bundle dependent. apple_resource_bundle targets need to be added to
library targets through the `data` attribute.
""",
)
