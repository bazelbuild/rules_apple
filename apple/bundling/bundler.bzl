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

"""Core bundling support used by the Apple rules.

This file is only meant to be imported by the platform-specific top-level rules
(ios.bzl, tvos.bzl, and so forth).
"""

load(
    "@bazel_skylib//lib:paths.bzl",
    "paths"
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "AppleExtraOutputsInfo",
    "AppleResourceInfo",
    "AppleResourceSet",
    "apple_resource_set_utils",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "group_files_by_directory",
    "optionally_prefixed_path",
)
load(
    "@build_bazel_rules_apple//apple/bundling:binary_support.bzl",
    "binary_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:bitcode_actions.bzl",
    "bitcode_actions",
)
load(
    "@build_bazel_rules_apple//apple/bundling:bundling_support.bzl",
    "bundling_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:clang_support.bzl",
    "clang_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:codesigning_support.bzl",
    "codesigning_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:debug_symbol_actions.bzl",
    "debug_symbol_actions",
)
load(
    "@build_bazel_rules_apple//apple/bundling:entitlements.bzl",
    "AppleEntitlementsInfo",
)
load(
    "@build_bazel_rules_apple//apple/bundling:file_actions.bzl",
    "file_actions",
)
load(
    "@build_bazel_rules_apple//apple/bundling:file_support.bzl",
    "file_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:plist_actions.bzl",
    "plist_actions",
)
load(
    "@build_bazel_rules_apple//apple/bundling:product_actions.bzl",
    "product_actions",
)
load(
    "@build_bazel_rules_apple//apple/bundling:product_support.bzl",
    "product_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:resource_actions.bzl",
    "resource_actions",
)
load(
    "@build_bazel_rules_apple//apple/bundling:swift_actions.bzl",
    "swift_actions",
)
load(
    "@build_bazel_rules_apple//apple/bundling:swift_support.bzl",
    "swift_support",
)
load(
    "@build_bazel_rules_apple//common:attrs.bzl",
    "attrs",
)
load(
    "@build_bazel_rules_apple//common:providers.bzl",
    "providers",
)


# Directories inside .frameworks that should not be included in final
# application/extension bundles.
_FRAMEWORK_DIRS_TO_EXCLUDE = [
    "Headers", "Modules", "PrivateHeaders",
]


# Resource sets with None for their bundle_dir represent resources that belong
# in the root of the bundle, as opposed to a .bundle subdirectory. This matches
# the default value for AppleResourceSet's `bundle_dir` (in providers.bzl).
_ROOT_BUNDLE_DIR = None


# A private provider used by the bundler to propagate AppleResourceSet
# information between frameworks and the bundles that depend on them. This is
# used during resource de-duping.
_ResourceBundleInfo = provider()


def _bundlable_files_for_control(bundlable_files):
  """Converts a list of bundlable files to be used by bundler.py.

  Bundlable files are stored during the initial analysis with their `src` as
  the `File` artifact so that they can be passed as inputs to other actions.
  But when writing out the control file for the bundling script, we need to
  write out the path names. This function applies that simple conversion.

  Args:
    bundlable_files: A list of bundlable file values.
  Returns:
    A list representing the same bundlable files, but with the `File` objects
    replaced by their paths.
  """
  return [bundling_support.bundlable_file(bf.src.path,
                                          bf.dest if bf.dest else "",
                                          bf.executable)
          for bf in bundlable_files]


def _convert_native_bundlable_file(bf, bundle_dir=_ROOT_BUNDLE_DIR):
  """Transforms bundlable file values obtained from an `objc` provider.

  The native `objc` provider returns bundlable files as a struct with two keys:
  `file` to represent the file being bundled and `bundle_path` for the path
  inside the bundle where it should be placed. These rules use a different
  format, so this function converts the native format to the one we need.

  This list can also contain Skylark bundlable files (as returned by
  `bundling_support.bundlable_file`); they will be returned with the
  `bundle_dir` prepended to their destination.

  TODO(b/33618143): Remove this when the native bundlable file type is
  removed.

  Args:
    bf: A bundlable file, potentially from a native provider.
    bundle_dir: If provided, a directory path that will be prepended to the
        `bundle_path` of the bundlable file's destination path.
  Returns:
    A list of bundlable file values corresponding to the inputs, as returned by
    `bundling_support.bundlable_file`.
  """
  if hasattr(bf, "file") and hasattr(bf, "bundle_path"):
    return bundling_support.bundlable_file(
        bf.file, optionally_prefixed_path(bf.bundle_path, bundle_dir))
  else:
    return bundling_support.bundlable_file(
        bf.src, optionally_prefixed_path(bf.dest, bundle_dir), bf.executable)


def _bundlable_dynamic_framework_files(ctx, files):
  """Computes the set of bundlable files for framework dependencies.

  The `files` argument passed into this function is expected to be a set of
  `File`s from the `dynamic_framework_file` key of a dependency's `objc`
  provider. This function then returns a set of bundlable files that dictates
  where the framework files should go in the final application/extension
  bundle, excluding any files that don't need to be packaged with the final
  product (such as headers).

  Args:
    ctx: The Skylark context.
    files: A `depset` of `File`s inside .framework folders that should be merged
        into the bundle.
  Returns:
    A list of bundlable file structs corresponding to the files that should be
    copied into the bundle.
  """
  bundle_files = []

  grouped_files = group_files_by_directory(files, ["framework"], "deps")
  for framework, framework_files in grouped_files.items():
    framework_name = paths.basename(framework)
    for f in framework_files:
      relative_path = paths.relativize(f.path, framework)
      first_segment = relative_path.partition("/")[0]
      if first_segment not in _FRAMEWORK_DIRS_TO_EXCLUDE:
        bundle_files.append(bundling_support.contents_file(
            ctx, f, "Frameworks/%s/%s" % (framework_name, relative_path)))

  return bundle_files


def _validate_attributes(ctx, bundle_id):
  """Validates the target's attributes and fails the build if any are invalid.

  Args:
    ctx: The Skylark context.
    bundle_id: The bundle_id to use for this target.
  """
  families = platform_support.families(ctx)
  allowed_families = ctx.attr._allowed_families
  for family in families:
    if family not in allowed_families:
      fail(("One or more of the provided device families \"%s\" is not in the " +
            "list of allowed device families \"%s\"") % (
                families, allowed_families))

  if (getattr(ctx.attr, "extension_safe", False) or
      getattr(ctx.attr, "_extension_safe", False)):
    for framework in getattr(ctx.attr, "frameworks", []):
      if not framework[AppleBundleInfo].extension_safe:
        print(("The target %s is for an extension but its framework " +
               "dependency %s is not marked extension-safe. Specify " +
               "'extension_safe = 1' on the framework target. This " +
               "will soon cause a build failure.") % (
                   ctx.label, framework.label))

  if not ctx.attr.minimum_os_version:
    # TODO(b/38006810): Once the minimum OS command line flags are deprecated,
    # update this message to use the SDK version instead.
    minimum_os = platform_support.minimum_os(ctx)
    platform_type = platform_support.platform_type(ctx)
    print(("The target %s does not specify its minimum OS version, so %s " +
           "from the --%s_minimum_os setting will be used. Please set one " +
           "for this target specifically by using the minimum_os_version " +
           "attribute (for example, 'minimum_os_version = \"9.0\"').") %
          (ctx.label, minimum_os, platform_type))

  # bundle_id is optional for some rules, hence nil check.
  if bundle_id != None:
    bundling_support.validate_bundle_id(bundle_id)


def _dedupe_bundle_merge_files(bundlable_files):
  """Deduplicates bundle files by destination.

  No two resources should be destined for the same location within the
  bundle unless they come from the same root-relative source. This removes
  duplicates but fails if two different source files are to end up at the same
  bundle path.

  Args:
    bundlable_files: The list of bundlable files to deduplicate.
  Returns:
    A list of bundle files with duplicates purged.
  """
  deduped_bundlable_files = []
  path_to_files = {}
  for bf in bundlable_files:
    this_file = bf.src

    if not bf.contents_only:
      other_bf = path_to_files.get(bf.dest)
      if other_bf:
        if other_bf.src.short_path != this_file.short_path:
          fail(("Multiple files would be placed at \"%s\" in the bundle, " +
                "which is not allowed: [%s,%s]") % (bf.dest,
                                                    this_file.short_path,
                                                    other_bf.src.short_path))
      else:
        deduped_bundlable_files.append(bf)
        path_to_files[bf.dest] = bf
    else:
      deduped_bundlable_files.append(bf)

  return deduped_bundlable_files


def _safe_files(ctx, name):
  """Safely returns files from an attribute, or the empty set.

  Args:
    ctx: The Skylark context.
    name: The attribute name.
  Returns:
    The `depset` of `File`s if the attribute exists, or an empty set otherwise.
  """
  return depset(getattr(ctx.files, name, []))


def _is_ipa(ctx):
  """Returns a value indicating whether the target is an IPA.

  This function returns True for "releasable" artifacts that are archived as
  IPAs, such as iOS and tvOS applications. It returns False for "intermediate"
  bundles, like iOS extensions or watchOS applications (which must be embedded
  in an iOS application).

  Args:
    ctx: The Skylark context.
  Returns:
    True if the target is archived as an IPA, or False if it is archived as a
    ZIP.
  """
  return ctx.outputs.archive.basename.endswith(".ipa")


def _create_unprocessed_archive(ctx,
                                bundle_name,
                                bundle_path_in_archive,
                                bundle_merge_files,
                                bundle_merge_zips,
                                root_merge_zips,
                                mnemonic,
                                progress_description):
  """Creates an archive containing the not-yet-signed bundle.

  This function registers an action that uses the underlying bundler.py tool to
  build an archive with the bundle contents, before the post-processing script
  is run (if present) and before it is signed. This is done because creating
  a ZIP in this way turns out to be much faster than performing a large number
  of small file copies (for targets with many resources).

  Args:
    ctx: The Skylark context.
    bundle_name: The name of the bundle.
    bundle_path_in_archive: The path to the bundle within the archive.
    bundle_merge_files: A list of bundlable file values that represent files
        that should be copied to specific locations in the bundle.
    bundle_merge_zips: A list of bundlable file values that represent ZIP
        archives that should be expanded into specific locations in the bundle.
    root_merge_zips: A list of bundlable file values that represent ZIP
        archives that should be expanded into specific locations relative to
        the root of the archive.
    mnemonic: The mnemonic to use for the bundling action.
    progress_description: The message that should be shown as the progress
        description for the bundling action.
  Returns:
    A `File` representing the unprocessed archive.
  """
  unprocessed_archive = file_support.intermediate(
      ctx, "%{name}.unprocessed.zip")

  control = struct(
      bundle_merge_files=_bundlable_files_for_control(bundle_merge_files),
      bundle_merge_zips=_bundlable_files_for_control(bundle_merge_zips),
      bundle_path=bundle_path_in_archive,
      output=unprocessed_archive.path,
      root_merge_zips=_bundlable_files_for_control(root_merge_zips),
  )
  control_file = file_support.intermediate(ctx, "%{name}.bundler-control")
  ctx.file_action(
      output=control_file,
      content=control.to_json()
  )

  bundler_inputs = (
      list(bundling_support.bundlable_file_sources(
          bundle_merge_files + bundle_merge_zips + root_merge_zips)) +
      [control_file]
  )

  ctx.action(
      inputs=bundler_inputs,
      outputs=[unprocessed_archive],
      executable=ctx.executable._bundletool,
      arguments=[control_file.path],
      mnemonic=mnemonic,
      progress_message="Bundling %s: %s" % (progress_description, bundle_name)
  )
  return unprocessed_archive


def _process_and_sign_archive(ctx,
                              bundle_name,
                              bundle_path_in_archive,
                              output_archive,
                              unprocessed_archive,
                              mnemonic,
                              progress_description):
  """Post-processes and signs an archived bundle.

  Args:
    ctx: The Skylark context.
    bundle_name: The name of the bundle.
    bundle_path_in_archive: The path to the bundle inside the archive.
    output_archive: The `File` representing the processed and signed archive.
    unprocessed_archive: The `File` representing the archive containing the
        bundle that has not yet been processed or signed.
    mnemonic: The mnemonic to use for the bundling action.
    progress_description: The message that should be shown as the progress
        description for the bundling action.
  Returns:
    Tuple containing:
        1. The path to the directory that represents the root of the expanded
        processed and signed files (before zipping). This is useful to external
        tools that want to access the directory directly instead of unzipping
        the final archive again.
        2. The entitlements file used to sign, potentially None.
  """
  script_inputs = [unprocessed_archive]

  entitlements = None
  # Use the entitlements from the internal provider if it's present (to support
  # rules that manipulate them before passing them to the bundler); otherwise,
  # use the file that was provided instead.
  if getattr(ctx.attr, "entitlements", None):
    if AppleEntitlementsInfo in ctx.attr.entitlements:
      entitlements = (
          ctx.attr.entitlements[AppleEntitlementsInfo].final_entitlements)
    else:
      entitlements = ctx.file.entitlements

  if entitlements:
    script_inputs.append(entitlements)

  provisioning_profile = getattr(ctx.file, "provisioning_profile", None)
  if provisioning_profile:
    script_inputs.append(provisioning_profile)

  signing_command_lines = ""
  if not ctx.attr._skip_signing:
    paths_to_sign = [
        codesigning_support.path_to_sign(
            "$WORK_DIR/" + bundle_path_in_archive + "/Frameworks/*",
            optional=True),
        codesigning_support.path_to_sign("$WORK_DIR/" + bundle_path_in_archive),
    ]
    signing_command_lines = codesigning_support.signing_command_lines(
        ctx, paths_to_sign, entitlements)


  ipa_post_processor = ctx.executable.ipa_post_processor
  ipa_post_processor_path = ""
  if ipa_post_processor:
    ipa_post_processor_path = ipa_post_processor.path
    script_inputs.append(ipa_post_processor)

  # The directory where the archive contents will be collected. This path is
  # also passed out via the AppleBundleInfo provider so that external tools can
  # access the bundle layout directly, saving them an extra unzipping step.
  work_dir = paths.replace_extension(output_archive.path, ".archive-root")

  # Only compress the IPA for optimized (release) builds. For debug builds,
  # zip without compression, which will speed up the build.
  should_compress = (ctx.var["COMPILATION_MODE"] == "opt")

  process_and_sign_script = file_support.intermediate(
      ctx, "%{name}.process-and-sign.sh")
  ctx.template_action(
      template=ctx.file._process_and_sign_template,
      output=process_and_sign_script,
      executable=True,
      substitutions={
          "%output_path%": output_archive.path,
          "%ipa_post_processor%": ipa_post_processor_path or "",
          "%signing_command_lines%": signing_command_lines,
          "%should_compress%": "1" if should_compress else "",
          "%unprocessed_archive_path%": unprocessed_archive.path,
          "%work_dir%": work_dir,
      },
  )

  platform_support.xcode_env_action(
      ctx,
      inputs=script_inputs,
      outputs=[output_archive],
      executable=process_and_sign_script,
      mnemonic=mnemonic + "ProcessAndSign",
      progress_message="Processing and signing %s: %s" % (
          progress_description, bundle_name)
  )
  return (work_dir, entitlements)


def _experimental_create_and_sign_bundle(
    ctx,
    bundle_dir,
    bundle_name,
    bundle_merge_files,
    bundle_merge_zips,
    mnemonic,
    progress_description):
  """Bundles and signs the current target.

  THIS IS CURRENTLY EXPERIMENTAL. It can be enabled by building with the
  `bazel_rules_apple.experimental_bundling` define set to `bundle_and_archive`
  or `bundle_only` but it should not be used for production builds yet.
  """
  control_file = file_support.intermediate(
      ctx, "%{name}.experimental-bundler-control")
  bundler_inputs = (
      list(bundling_support.bundlable_file_sources(bundle_merge_files +
                                                   bundle_merge_zips)) +
      [control_file]
  )

  entitlements = attrs.get(ctx.file, "entitlements")
  if entitlements:
    bundler_inputs.append(entitlements)

  signing_command_lines = ""
  if not ctx.attr._skip_signing:
    paths_to_sign = [
        codesigning_support.path_to_sign(
            "$WORK_DIR/" + bundle_dir.basename + "/Frameworks/*",
            optional=True),
        codesigning_support.path_to_sign("$WORK_DIR/" + bundle_dir.basename),
    ]
    signing_command_lines = codesigning_support.signing_command_lines(
        ctx, paths_to_sign, entitlements)

  # TODO(allevato): Add a `bundle_post_processor` attribute.

  control = struct(
      bundle_merge_files=_bundlable_files_for_control(bundle_merge_files),
      bundle_merge_zips=_bundlable_files_for_control(bundle_merge_zips),
      code_signing_commands=signing_command_lines,
      output=bundle_dir.path,
  )
  ctx.file_action(
      output=control_file,
      content=control.to_json()
  )

  platform_support.xcode_env_action(
      ctx,
      inputs=bundler_inputs,
      outputs=[bundle_dir],
      executable=ctx.executable._bundletool_experimental,
      arguments=[control_file.path],
      mnemonic=mnemonic,
      progress_message="Bundling and signing %s: %s" % (
          progress_description, bundle_name)
  )


def _run(
    ctx,
    mnemonic,
    progress_description,
    bundle_id,
    binary_artifact,
    additional_bundlable_files=depset(),
    additional_resource_sets=[],
    embedded_bundles=[],
    framework_files=depset(),
    is_dynamic_framework=False,
    deps_objc_providers=[],
    suppress_bundle_infoplist=False,
    version_keys_required=True):
  """Implements the core bundling logic for an Apple bundle archive.

  Args:
    ctx: The Skylark context. Required.
    mnemonic: The mnemonic to use for the final bundling action. Required.
    progress_description: The human-readable description of the bundle being
        created in the progress message. For example, in the progress message
        "Bundling iOS application: <name>", the string passed into this
        argument would be "iOS application". Required.
    bundle_id: Bundle identifier to set to the bundle. Required.
    binary_artifact: The binary artifact to bundle. Required.
    additional_bundlable_files: An optional list of additional bundlable files
        that should be copied into the final bundle at locations denoted by
        their bundle path.
    additional_resource_sets: An optional list of `AppleResourceSet` values that
        represent resources not included by dependencies that should also be
        processed among the other resources in the target (for example, app
        icons, launch images, launch storyboards, and settings bundle files).
    embedded_bundles: A list of values (as returned by
        `bundling_support.embedded_bundle`) that denote bundles such as
        extensions or frameworks that should be included in the bundle being
        built.
    framework_files: An optional set of bundlable files that should be copied
        into the framework that this rule produces. If any files are present,
        this is implicitly noted to be a framework bundle, and additional
        provider keys (such as framework search paths) will be propagated
        appropriately.
    is_dynamic_framework: If True, create this bundle as a dynamic framework.
    deps_objc_providers: objc providers containing information about the
        dependencies of the binary target.
    suppress_bundle_infoplist: If True, ensure the Info.plist was created for
        the main bundle.
    version_keys_required: If True, the merged Info.plist file is required
        to have entries for CFBundleShortVersionString and CFBundleVersion.
        NOTE: Almost every type of bundle for Apple's platforms should get
        version numbers; so this is done a something only needed to opt out of
        the require for the exceptional cases (like unittest bundles).
  Returns:
    A tuple containing three values:
    1. A list of modern providers that should be propagated by the calling rule.
    2. A dictionary of legacy providers that should be propagated by the calling
       rule.
    3. A set of additional outputs that should be returned by the calling rule.
  """
  _validate_attributes(ctx, bundle_id)
  if suppress_bundle_infoplist:
    if bundle_id:
      fail("Internal Error: Suppressing bundle Info.plist, but got a " +
           "bundle_id?")
    if version_keys_required:
      fail("Internal Error: Suppressing bundle Info.plist, but expected " +
           "version keys in one?")

  # A list of files that should be used as the outputs of the rule invoking this
  # instance of the bundler, but which should not necessarily be propagated to
  # bundles that embed this bundle. For example, the application/extension
  # bundle itself is a main output but not an extra output because we don't
  # want extensions to be treated as separate outputs from the application that
  # depends on them.
  main_outputs = []

  # A list of extra outputs that should be returned by the calling rule and also
  # propagated by bundles that depend on the invoking target. For example, the
  # dSYM bundles of extensions should be propagated up to depending applications
  # so that they are generated when the application is built.
  extra_outputs = []

  # A list of output files included in the local_outputs output group. These are
  # must be requested explicitly by including "local_outputs" in the
  # --output_groups flag of the build command line.
  local_outputs = []

  # The name of the target is used as the name of the executable in the binary,
  # which we also need to write into the Info.plist file over whatever the user
  # already has there.
  bundle_name = bundling_support.bundle_name(ctx)

  # bundle_merge_files collects the files (or directories of files) from
  # providers and actions that should be copied into the bundle by the final
  # packaging action.
  bundle_merge_files = [_convert_native_bundlable_file(bf)
                        for bf in additional_bundlable_files]

  # bundle_merge_zips collects ZIP files from providers and actions that should
  # be expanded into the bundle by the final packaging action.
  bundle_merge_zips = []

  # Collects the ZIP files that should be merged into the root of an archive.
  # archive. Note that this only applies if an IPA is being built; it is
  # ignored for ZIP archives created from non-app artifacts like extensions.
  root_merge_zips = []

  # Collects ZIP files representing frameworks that should be propagated to the
  # bundle inside which the current bundle is embedded.
  propagated_framework_zips = []

  # Keeps track of whether this is a device build or a simulator build.
  is_device = platform_support.is_device_build(ctx)

  # If this is a device build for which code signing is required, copy the
  # provisioning profile into the bundle with the expected name.
  provisioning_profile = getattr(ctx.file, "provisioning_profile", None)
  if (is_device and provisioning_profile and not ctx.attr._skip_signing):
    bundle_merge_files.append(bundling_support.contents_file(
        ctx, provisioning_profile,
        codesigning_support.embedded_provisioning_profile_name(ctx)))

  # The path to the .app bundle inside the IPA archive.
  bundle_path_in_archive = (ctx.attr._path_in_archive_format %
                            bundling_support.bundle_name_with_extension(ctx))

  # Start by collecting resources for the bundle being built. The empty string
  # for the bundle path indicates that resources should appear at the top level
  # of the bundle.
  target_infoplists = list(_safe_files(ctx, "infoplists"))

  resource_sets = list(additional_resource_sets)

  framework_resource_sets = depset()

  if attrs.get(ctx.attr, "exclude_resources"):
    resource_sets.append(AppleResourceSet(infoplists=target_infoplists))
  else:
    for framework in attrs.get(ctx.attr, "frameworks", []):
      if _ResourceBundleInfo in framework:
        framework_resource_sets = (
            framework_resource_sets |
            framework[_ResourceBundleInfo].resource_sets)
      if ctx.attr._propagates_frameworks:
        propagated_framework_zips.append(framework[AppleBundleInfo].archive)

    # Add the transitive resource sets, except for those that have already been
    # included by a framework dependency.
    p = binary_support.get_binary_provider(ctx.attr.deps, AppleResourceInfo)
    if p:
      for rs in p.resource_sets:
        resource_sets.append(rs)

    # Finally, add any extra resources specific to the target being built
    # itself.
    target_resources = _safe_files(ctx, "strings")
    resource_sets.append(AppleResourceSet(
        infoplists=target_infoplists,
        resources=target_resources,
    ))

  # Iterate over each set of resources and register the actions. This
  # ensures that each bundle among the dependencies has its resources
  # processed independently.
  dedupe_unbundled = getattr(ctx.attr, "dedupe_unbundled_resources", False)
  resource_sets = apple_resource_set_utils.minimize(resource_sets,
                                                    framework_resource_sets,
                                                    dedupe_unbundled)
  process_results = resource_actions.process_resource_sets(
      ctx, bundle_id, resource_sets)

  bundle_merge_files.extend(process_results.bundle_merge_files)
  bundle_merge_zips.extend(process_results.bundle_merge_zips)

  if suppress_bundle_infoplist:
    # Remove any value (default is so pop won't fail if there was no entry for
    # the root).
    process_results.bundle_infoplists.pop(_ROOT_BUNDLE_DIR, None)
  else:
    # When not suppressed, ensure the root is there so merge will happen to
    # record the bundle_id, build info, etc.
    if _ROOT_BUNDLE_DIR not in process_results.bundle_infoplists:
      process_results.bundle_infoplists[_ROOT_BUNDLE_DIR] = []

  # Merge the Info.plists into binary format and collect the resulting PkgInfo
  # file as well. Keep track of the Info.plist for the main bundle while we do
  # this so that it can be propagated out (for situations where this bundle is a
  # child of another bundle and bundle ID consistency is checked).
  main_infoplist = None
  for bundle_dir, infoplists in process_results.bundle_infoplists.items():
    merge_infoplist_args = {
        "input_plists": list(infoplists),
    }

    bundles_to_datas = process_results.bundle_dir_to_resource_bundle_target_datas
    bundle_target_data = bundles_to_datas.get(bundle_dir)
    merge_infoplist_args["resource_bundle_target_data"] = bundle_target_data

    if not bundle_dir:
      # Compare to child plists (i.e., from extensions and nested binaries)
      # only if we're processing the main bundle and not a resource bundle.
      child_infoplists = [
          eb.target[AppleBundleInfo].infoplist for eb in embedded_bundles
          if eb.verify_bundle_id
      ]
      merge_infoplist_args["child_plists"] = child_infoplists
      merge_infoplist_args["bundle_id"] = bundle_id
      merge_infoplist_args["extract_from_ctxt"] = True
      merge_infoplist_args["include_xcode_env"] = True
      if version_keys_required:
        merge_infoplist_args["version_keys_required"] = True

    plist_results = plist_actions.merge_infoplists(
        ctx, bundle_dir, **merge_infoplist_args)

    if not bundle_dir:
      main_infoplist = plist_results.output_plist

    # The files below need to be merged with specific names in the final
    # bundle.
    bundle_merge_files.append(bundling_support.contents_file(
        ctx, plist_results.output_plist,
        optionally_prefixed_path("Info.plist", bundle_dir)))

    if plist_results.pkginfo:
      bundle_merge_files.append(bundling_support.contents_file(
          ctx, plist_results.pkginfo,
          optionally_prefixed_path("PkgInfo", bundle_dir)))

  # Some application/extension types require stub executables, so collect that
  # information if necessary.
  product_type = product_support.product_type(ctx)
  product_type_descriptor = product_support.product_type_descriptor(
      product_type)
  has_built_binary = False
  if product_type_descriptor and product_type_descriptor.stub:
    stub_descriptor = product_type_descriptor.stub
    bundle_merge_files.append(bundling_support.binary_file(
        ctx, binary_artifact, bundle_name, executable=True))
    if stub_descriptor.additional_bundle_path:
      # TODO(b/34684393): Figure out if macOS ever uses stub binaries for any
      # product types, and if so, is this the right place for them?
      bundle_merge_files.append(bundling_support.contents_file(
          ctx, binary_artifact, stub_descriptor.additional_bundle_path,
          executable=True))
    # TODO(b/34047985): This should be conditioned on a flag, not just
    # compilation mode.
    if ctx.var["COMPILATION_MODE"] == "opt":
      support_zip = product_actions.create_stub_zip_for_archive_merging(
          ctx, binary_artifact, stub_descriptor)
      root_merge_zips.append(bundling_support.bundlable_file(support_zip, "."))
  elif hasattr(ctx.attr, "deps"):
    if not ctx.attr.deps:
      fail("Library dependencies must be provided for this product type.")
    if not binary_artifact:
      fail("A binary artifact must be specified for this product type.")
    has_built_binary = True

    bundle_merge_files.append(bundling_support.binary_file(
        ctx, binary_artifact, bundle_name, executable=True))

  # Compute the Swift libraries that are used by the target currently being
  # built.
  uses_swift = swift_support.uses_swift(ctx.attr.deps)
  if uses_swift:
    swift_zip = swift_actions.zip_swift_dylibs(ctx, binary_artifact)

    if ctx.attr._propagates_frameworks:
      propagated_framework_zips.append(swift_zip)
    else:
      bundle_merge_zips.append(bundling_support.contents_file(
          ctx, swift_zip, "Frameworks"))

    platform = platform_support.platform(ctx)
    root_merge_zips.append(bundling_support.bundlable_file(
        swift_zip, "SwiftSupport/%s" % platform.name_in_plist.lower()))

  # Add Clang runtime inputs when needed.
  if has_built_binary and clang_support.should_package_clang_runtime(ctx):
    clang_rt_zip = clang_support.register_runtime_lib_actions(ctx,
                                                              binary_artifact)
    bundle_merge_zips.append(
        bundling_support.contents_file(ctx, clang_rt_zip, "Frameworks"))

  # Include bitcode symbol maps when needed.
  if has_built_binary and binary_support.get_binary_provider(
      ctx.attr.deps,
      apple_common.AppleDebugOutputs):
    bitcode_maps_zip = bitcode_actions.zip_bitcode_symbols_maps(
        ctx, binary_artifact)
    if bitcode_maps_zip:
      root_merge_zips.append(bundling_support.bundlable_file(
          bitcode_maps_zip, "BCSymbolMaps"))

  # Include any embedded bundles.
  for eb in embedded_bundles:
    apple_bundle = eb.target[AppleBundleInfo]
    if ctx.attr._propagates_frameworks:
      propagated_framework_zips += list(apple_bundle.propagated_framework_zips)
      propagated_framework_files += list(apple_bundle.propagated_framework_files)
    else:
      if apple_bundle.propagated_framework_zips:
        bundle_merge_zips.extend([
            bundling_support.contents_file(ctx, f, "Frameworks")
            for f in apple_bundle.propagated_framework_zips
        ])
      if apple_bundle.propagated_framework_files:
        bundle_merge_files.extend(_bundlable_dynamic_framework_files(
            ctx, apple_bundle.propagated_framework_files))

    bundle_merge_zips.append(bundling_support.contents_file(
        ctx, apple_bundle.archive, eb.path))
    root_merge_zips.extend(list(apple_bundle.root_merge_zips))

  # Merge in any prebuilt frameworks (i.e., objc_framework dependencies).
  propagated_framework_files = []
  for objc in deps_objc_providers:
    files = objc.dynamic_framework_file
    if ctx.attr._propagates_frameworks:
      propagated_framework_files.extend(list(files))
    else:
      bundle_merge_files.extend(_bundlable_dynamic_framework_files(ctx, files))

  bundle_merge_files = _dedupe_bundle_merge_files(bundle_merge_files)

  # Perform the final bundling tasks.
  root_merge_zips_to_archive = root_merge_zips if _is_ipa(ctx) else []

  experimental_bundling = ctx.var.get("bazel_rules_apple.experimental_bundling",
                                      "off").lower()
  if experimental_bundling not in ("bundle_and_archive", "bundle_only", "off"):
    fail("Valid values for --define=bazel_rules_apple.experimental_bundling" +
         "are: bundle_and_archive, bundle_only, off.")
  # Only use experimental bundling for main app's bundle.
  if bundling_support.bundle_name_with_extension(ctx).endswith(".app"):
    experimental_bundling = "off"
  if experimental_bundling in ("bundle_and_archive", "bundle_only"):
    out_bundle = ctx.experimental_new_directory(
        bundling_support.bundle_name_with_extension(ctx))
    main_outputs.append(out_bundle)
    _experimental_create_and_sign_bundle(
        ctx, out_bundle, bundle_name, bundle_merge_files,
        bundle_merge_zips, mnemonic, progress_description)

  work_dir = None
  entitlements = None
  bundle_dir = None
  main_outputs.append(ctx.outputs.archive)
  if experimental_bundling in ("bundle_and_archive", "off"):
    unprocessed_archive = _create_unprocessed_archive(
        ctx, bundle_name, bundle_path_in_archive, bundle_merge_files,
        bundle_merge_zips, root_merge_zips_to_archive, mnemonic,
        progress_description)
    work_dir, entitlements = _process_and_sign_archive(
        ctx, bundle_name, bundle_path_in_archive, ctx.outputs.archive,
        unprocessed_archive, mnemonic, progress_description)
  else:
    # Create a dummy archive for the bundle_only case, because we have to create
    # something.
    ctx.file_action(
        output=ctx.outputs.archive,
        content="This is a dummy archive.",
    )

  additional_providers = []
  legacy_providers = {}

  debug_outputs = binary_support.get_binary_provider(ctx.attr.deps,
      apple_common.AppleDebugOutputs)
  if has_built_binary and debug_outputs:
    additional_providers.append(debug_outputs)
    # Create a .dSYM bundle with the expected name next to the archive in the
    # output directory.
    if ctx.fragments.objc.generate_dsym:
      bundle_extension = bundling_support.bundle_extension(ctx)
      symbol_bundle = debug_symbol_actions.create_symbol_bundle(ctx,
          debug_outputs, bundle_name, bundle_extension)
      extra_outputs.extend(symbol_bundle)

    if ctx.fragments.objc.generate_linkmap:
      linkmaps = debug_symbol_actions.collect_linkmaps(ctx, debug_outputs,
          bundle_name)
      extra_outputs.extend(linkmaps)

  objc_provider_args = {}
  if framework_files:
    framework_dir, bundled_framework_files = (
        _copy_framework_files(ctx, framework_files))
    if is_dynamic_framework:
      # TODO(cparsons): These will no longer be necessary once apple_binary
      # uses the values in the dynamic framework provider.
      objc_provider_args["dynamic_framework_dir"] = depset([framework_dir])
      objc_provider_args["dynamic_framework_file"] = bundled_framework_files

  objc_provider_args["providers"] = deps_objc_providers
  legacy_objc_provider = apple_common.new_objc_provider(**objc_provider_args)
  if is_dynamic_framework:
    framework_provider = apple_common.new_dynamic_framework_provider(
        objc=legacy_objc_provider,
        binary=binary_artifact,
        framework_files=bundled_framework_files,
        framework_dirs=depset([framework_dir]))
    additional_providers.extend([framework_provider])

  extension_safe = (getattr(ctx.attr, "extension_safe", False) or
                    getattr(ctx.attr, "_extension_safe", False))
  apple_bundle_info_args = {
      "archive": ctx.outputs.archive,
      "bundle_dir": bundle_dir,
      "bundle_extension": bundling_support.bundle_extension(ctx),
      "bundle_id": bundle_id,
      "bundle_name": bundle_name,
      "entitlements": entitlements,
      "extension_safe": extension_safe,
      "infoplist": main_infoplist,
      "minimum_os_version": platform_support.minimum_os(ctx),
      "product_type": product_support.product_type(ctx),
      "propagated_framework_files": depset(propagated_framework_files),
      "propagated_framework_zips": depset(propagated_framework_zips),
      "root_merge_zips": root_merge_zips if not _is_ipa(ctx) else [],
      "uses_swift": uses_swift,
  }
  if work_dir:
    apple_bundle_info_args["archive_root"] = work_dir
  legacy_providers["apple_bundle"] = struct(**apple_bundle_info_args)

  # Collect extra outputs from embedded bundles so that they also get included
  # as outputs of the rule.
  transitive_extra_outputs = depset(extra_outputs)
  propagate_embedded_extra_outputs = ctx.var.get(
      "bazel_rules_apple.propagate_embedded_extra_outputs", "no")
  if propagate_embedded_extra_outputs.lower() in ("true", "yes", "1"):
    embedded_bundle_targets = [eb.target for eb in embedded_bundles]
    for extra in providers.find_all(
        embedded_bundle_targets, AppleExtraOutputsInfo):
      transitive_extra_outputs += extra.files

  additional_providers.extend([
      AppleBundleInfo(**apple_bundle_info_args),
      AppleExtraOutputsInfo(files=transitive_extra_outputs),
      OutputGroupInfo(local_outputs=depset(local_outputs)),
      _ResourceBundleInfo(resource_sets=resource_sets),
  ])

  return (additional_providers,
          legacy_providers,
          depset(main_outputs) + transitive_extra_outputs)


def _copy_framework_files(ctx, framework_files):
  """Copies the files in `framework_files` to the right place in the framework.

  Args:
    ctx: The Skylark context.
    framework_files: A list of files to copy into the framework.
  Returns:
    A two-element tuple: the framework directory path, and a set containing the
    output files in their final locations.
  """
  bundle_name = bundling_support.bundle_name(ctx)
  framework_dir_name = "_frameworks/" + bundle_name + ".framework/"
  bundled_framework_files = []
  for framework_file in framework_files:
    output_file = ctx.new_file(
        framework_dir_name + framework_file.dest)
    ctx.action(
        outputs=[output_file],
        inputs=[framework_file.src],
        mnemonic="Cp",
        arguments=[
            output_file.dirname, framework_file.src.path, output_file.path],
        command='mkdir -p "$1" && cp "$2" "$3"',
        progress_message=(
            "Copying " + framework_file.src.path + " to " + output_file.path)
    )
    bundled_framework_files.append(output_file)
  return (ctx.outputs.archive.dirname + "/" + framework_dir_name,
          depset(bundled_framework_files))


# Define the loadable module that lists the exported symbols in this file.
bundler = struct(
    run=_run,
)
