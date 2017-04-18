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

load("//apple:providers.bzl",
     "AppleResource",
     "AppleResourceSet",
     "apple_resource_set_utils",
    )
load("//apple:utils.bzl",
     "basename",
     "bash_array_string",
     "bash_quote",
     "dirname",
     "group_files_by_directory",
     "optionally_prefixed_path",
     "relativize_path",
     "remove_extension",
    )
load("//apple/bundling:bitcode_actions.bzl", "bitcode_actions")
load("//apple/bundling:bundling_support.bzl",
     "bundling_support")
load("//apple/bundling:codesigning_support.bzl",
     "codesigning_support")
load("//apple/bundling:dsym_actions.bzl", "dsym_actions")
load("//apple/bundling:file_actions.bzl", "file_actions")
load("//apple/bundling:file_support.bzl", "file_support")
load("//apple/bundling:platform_support.bzl",
     "platform_support")
load("//apple/bundling:plist_actions.bzl", "plist_actions")
load("//apple/bundling:product_actions.bzl",
     "product_actions")
load("//apple/bundling:product_support.bzl",
     "product_support")
load("//apple/bundling:provider_support.bzl",
     "provider_support")
load("//apple/bundling:resource_actions.bzl",
     "resource_actions")
load("//apple/bundling:resource_support.bzl",
     "resource_support")
load("//apple/bundling:swift_actions.bzl", "swift_actions")
load("//apple/bundling:swift_support.bzl", "swift_support")


# Directories inside .frameworks that should not be included in final
# application/extension bundles.
_FRAMEWORK_DIRS_TO_EXCLUDE = [
    "Headers", "Modules", "PrivateHeaders",
]


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


def _convert_native_bundlable_file(bf, bundle_dir=None):
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
    framework_name = basename(framework)
    for f in framework_files:
      relative_path = relativize_path(f.path, framework)
      first_segment = relative_path.partition("/")[0]
      if first_segment not in _FRAMEWORK_DIRS_TO_EXCLUDE:
        bundle_files.append(bundling_support.contents_file(
            ctx, f, "Frameworks/%s/%s" % (framework_name, relative_path)))

  return bundle_files


def _validate_attributes(ctx):
  """Validates the target's attributes and fails the build if any are invalid.

  Args:
    ctx: The Skylark context.
  """
  families = platform_support.families(ctx)
  allowed_families = ctx.attr._allowed_families
  for family in families:
    if family not in allowed_families:
      fail(("One or more of the provided device families \"%s\" is not in the " +
            "list of allowed device families \"%s\"") % (
                families, allowed_families))


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

    other_file = path_to_files.get(bf.dest)
    if other_file:
      if other_file.short_path != this_file.short_path:
        fail(("Multiple files would be placed at \"%s\" in the bundle, " +
              "which is not allowed: [%s,%s]") % (bf.dest,
                                                  this_file.short_path,
                                                  other_file.short_path))
    else:
      deduped_bundlable_files.append(bf)
      path_to_files[bf.dest] = this_file

  return deduped_bundlable_files


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
      resources=_dedupe_files(resource_set.resources),
      structured_resources=_dedupe_files(resource_set.structured_resources),
      structured_resource_zips=_dedupe_files(
          resource_set.structured_resource_zips),
      swift_module=resource_set.swift_module,
  )


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

  bundler_py = ctx.file._bundler_py
  bundler_inputs = (
      list(bundling_support.bundlable_file_sources(
          bundle_merge_files + bundle_merge_zips + root_merge_zips)) +
      [bundler_py, control_file]
  )

  ctx.action(
      inputs=bundler_inputs,
      outputs=[unprocessed_archive],
      command=[
          "/bin/bash", "-c",
          "python2.7 %s %s" % (bundler_py.path, control_file.path),
      ],
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
    The path to the directory that represents the root of the expanded
    processed and signed files (before zipping). This is useful to external
    tools that want to access the directory directly instead of unzipping the
    final archive again.
  """
  script_inputs = [unprocessed_archive]

  entitlements = None
  if hasattr(ctx.file, "entitlements") and ctx.file.entitlements:
    entitlements = ctx.file.entitlements
    script_inputs.append(entitlements)

  signing_command_lines = ""
  if not ctx.attr._skip_signing:
    signing_command_lines = codesigning_support.signing_command_lines(
        ctx, bundle_path_in_archive, entitlements)

  post_processor = ctx.executable.ipa_post_processor
  post_processor_path = ""
  if post_processor:
    post_processor_path = post_processor.path
    script_inputs.append(post_processor)

  # The directory where the archive contents will be collected. This path is
  # also passed out via the apple_bundle provider so that external tools can
  # access the bundle layout directly, saving them an extra unzipping step.
  work_dir = remove_extension(output_archive.path) + ".archive-root"

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
          "%post_processor%": post_processor_path or "",
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
  return work_dir


def _farthest_directory_matching(path, extension):
  """Returns the part of a path with the given extension closest to the root.

  For example, if `path` is `"foo/bar.bundle/baz.bundle"`, passing `".bundle"`
  as the extension will return `"foo/bar.bundle"`.

  Args:
    path: The path.
    extension: The extension of the directory to find.
  Returns:
    The portion of the path that ends in the given extension that is closest
    to the root of the path.
  """
  prefix, ext, _ = path.partition("." + extension)
  if ext:
    return prefix + ext

  fail("Expected path %r to contain %r, but it did not" % (
      path, "." + extension))


def _run(
    ctx,
    mnemonic,
    progress_description,
    bundle_id,
    additional_bundlable_files=depset(),
    additional_resources=depset(),
    embedded_bundles=[],
    framework_files=depset(),
    is_dynamic_framework=False):
  """Implements the core bundling logic for an Apple bundle archive.

  Args:
    ctx: The Skylark context. Required.
    mnemonic: The mnemonic to use for the final bundling action. Required.
    progress_description: The human-readable description of the bundle being
        created in the progress message. For example, in the progress message
        "Bundling iOS application: <name>", the string passed into this
        argument would be "iOS application". Required.
    bundle_id: Bundle identifier to set to the bundle. Required.
    additional_bundlable_files: An optional list of additional bundlable files
        that should be copied into the final bundle at locations denoted by
        their bundle path.
    additional_resources: An optional set of additional resources not included
        by dependencies that should also be passed to the resource processing
        logic (for example, app icons, launch images, and launch storyboards).
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
  Returns:
    A tuple containing two values:
    1. A dictionary with two providers: an `objc` provider containing the
       transitive dependencies of the artifacts used by the current rule, and
       an `apple_bundle` provider with additional metadata about the bundle
       (such as its final Info.plist file).
    2. A set of additional outputs that should be returned by the calling rule.
  """
  _validate_attributes(ctx)

  # A list of additional implicit outputs that should be returned by the
  # calling rule.
  additional_outputs = []

  # The name of the target is used as the name of the executable in the binary,
  # which we also need to write into the Info.plist file over whatever the user
  # already has there.
  bundle_name = bundling_support.bundle_name(ctx)

  # bundle_merge_files collects the files (or directories of files) from
  # providers and actions that should be copied into the bundle by the final
  # packaging action.
  bundle_merge_files = [
      _convert_native_bundlable_file(
          bf, bundle_dir=bundling_support.path_in_contents_dir(ctx, "")
      ) for bf in additional_bundlable_files
  ]

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

  bundle_dirs = []
  resource_sets = []

  if (hasattr(ctx.attr, "exclude_resources") and ctx.attr.exclude_resources):
    resource_sets.append(AppleResourceSet(infoplists=target_infoplists))
  else:
    # Collect the set of bundle_dirs from all framework dependencies, which
    # will be used to deduplicate resources (by excluding them from the
    # depending app/extension).
    framework_bundle_dirs = depset()
    if hasattr(ctx.attr, "frameworks"):
      for framework in getattr(ctx.attr, "frameworks", []):
        if hasattr(framework, "bundle_dirs"):
          for bundle_dir in framework.bundle_dirs.bundle_dirs:
            framework_bundle_dirs = framework_bundle_dirs | [bundle_dir]
        if ctx.attr._propagates_frameworks:
          propagated_framework_zips.append(framework.apple_bundle.archive)

    # Add the transitive resource sets, except for those that have already been
    # included by a framework dependency.
    apple_resource_providers = provider_support.binary_or_deps_providers(
        ctx, "AppleResource")
    for p in apple_resource_providers:
      for rs in p.resource_sets:
        # Don't propagate empty bundle directory, as this is indicative of
        # root-level resources.
        # TODO(b/36512244): Implement root-level resource deduping.
        if rs.bundle_dir:
          bundle_dirs.append(rs.bundle_dir)
        bundle_dir_or_empty = rs.bundle_dir or ""
        # TODO(b/36512244): Ensure that there aren't two differing bundles
        # with different names, as one would get silently dropped.
        if bundle_dir_or_empty not in framework_bundle_dirs:
          resource_sets.append(rs)

    # Finally, add any extra resources specific to the target being built
    # itself.
    target_resources = (
        depset(additional_resources) + _safe_files(ctx, "strings"))
    resource_sets.append(AppleResourceSet(
        infoplists=target_infoplists,
        resources=target_resources,
    ))

  # We need to keep track of the Info.plist for the main bundle so that it can
  # be propagated out (for situations where this bundle is a child of another
  # bundle and bundle ID consistency is checked).
  main_infoplist = None

  # Collects the compiled storyboard artifacts for later linking.
  compiled_storyboards = []

  # Iterate over each set of resources and register the actions. This
  # ensures that each bundle among the dependencies has its resources
  # processed independently.
  resource_sets = [_dedupe_resource_set_files(rs)
                   for rs in apple_resource_set_utils.minimize(resource_sets)]
  for r in resource_sets:
    ri = resource_support.resource_info(bundle_id, bundle_dir=r.bundle_dir)
    process_result = resource_actions.process_resources(ctx, r.resources, ri)
    compiled_storyboards.extend(list(process_result.compiled_storyboards))
    bundle_merge_files.extend(list(process_result.bundle_merge_files))
    bundle_merge_zips.extend(list(process_result.bundle_merge_zips))

    # Merge structured resources verbatim, preserving their owner-relative
    # paths.
    if r.objc_bundle_imports:
      # TODO(b/33618143): Remove the ugly special case for objc_bundle.
      bundle_merge_files.extend([
          bundling_support.resource_file(
              ctx, f, optionally_prefixed_path(
                  relativize_path(
                      f.short_path,
                      _farthest_directory_matching(f.short_path, "bundle")),
                  r.bundle_dir))
          for f in r.objc_bundle_imports
      ])

    bundle_merge_files.extend([
        bundling_support.resource_file(
            ctx, f, optionally_prefixed_path(
                relativize_path(f.short_path, f.owner.package),
                r.bundle_dir))
        for f in r.structured_resources
    ])
    bundle_merge_zips.extend([
        bundling_support.resource_file(ctx, f, r.bundle_dir)
        for f in r.structured_resource_zips
    ])

    # Merge the plists into binary format and collect the resulting PkgInfo
    # file as well.
    infoplists = list(r.infoplists) + list(process_result.partial_infoplists)
    if infoplists:
      merge_infoplist_args = {
          "input_plists": list(infoplists),
          "bundle_id": bundle_id,
      }

      # Compare to child plists (i.e., from extensions and nested binaries)
      # only if we're processing the main bundle and not a resource bundle.
      if not r.bundle_dir:
        child_infoplists = [
            eb.apple_bundle.infoplist for eb in embedded_bundles
            if eb.verify_bundle_id
        ]
        merge_infoplist_args["child_plists"] = child_infoplists
        merge_infoplist_args["executable_bundle"] = True

      plist_results = plist_actions.merge_infoplists(
          ctx, r.bundle_dir, **merge_infoplist_args)

      if not r.bundle_dir:
        main_infoplist = plist_results.output_plist

      # The files below need to be merged with specific names in the final
      # bundle.
      bundle_merge_files.append(bundling_support.contents_file(
          ctx, plist_results.output_plist,
          optionally_prefixed_path("Info.plist", r.bundle_dir)))

      if plist_results.pkginfo:
        bundle_merge_files.append(bundling_support.contents_file(
            ctx, plist_results.pkginfo,
            optionally_prefixed_path("PkgInfo", r.bundle_dir)))

  # Compile any storyboards and create the script that runs ibtool again
  # during the bundling stage to link them. This is necessary to resolve
  # references between different storyboards, and to copy the results to the
  # correct location in the bundle in a platform-agnostic way; for example,
  # storyboards in watchOS applications don't retain the .storyboardc folder.
  if compiled_storyboards:
    linked_storyboards = resource_actions.ibtool_link(
        ctx, compiled_storyboards)
    bundle_merge_zips.append(bundling_support.resource_file(
        ctx, linked_storyboards, "."))

  # Some application/extension types require stub executables, so collect that
  # information if necessary.
  product_info = product_support.product_type_info_for_target(ctx)
  if product_info:
    # We explicitly don't use bash_quote here because we don't want to escape
    # the environment variable substitutions.
    stub_binary = product_actions.copy_stub_for_bundle(ctx, product_info)
    bundle_merge_files.append(bundling_support.binary_file(
        ctx, stub_binary, bundle_name, executable=True))
    if product_info.bundle_path:
      # TODO(b/34684393): Figure out if macOS ever uses stub binaries for any
      # product types, and if so, is this the right place for them?
      bundle_merge_files.append(bundling_support.contents_file(
          ctx, stub_binary, product_info.bundle_path, executable=True))
    # TODO(b/34047985): This should be conditioned on a flag, not just
    # compilation mode.
    if ctx.var["COMPILATION_MODE"] == "opt":
      support_zip = product_actions.create_stub_zip_for_archive_merging(
          ctx, product_info)
      root_merge_zips.append(bundling_support.bundlable_file(support_zip, "."))
  elif hasattr(ctx.file, "binary"):
    if not ctx.file.binary:
      fail("Library dependencies must be provided for this product type.")
    bundle_merge_files.append(bundling_support.binary_file(
        ctx, ctx.file.binary, bundle_name, executable=True))

  # Compute the Swift libraries that are used by the target currently being
  # built.
  if swift_support.uses_swift(ctx):
    swift_zip = swift_actions.zip_swift_dylibs(ctx)

    if ctx.attr._propagates_frameworks:
      propagated_framework_zips.append(swift_zip)
    else:
      bundle_merge_zips.append(bundling_support.contents_file(
          ctx, swift_zip, "Frameworks"))

    platform, _ = platform_support.platform_and_sdk_version(ctx)
    root_merge_zips.append(bundling_support.bundlable_file(
        swift_zip, "SwiftSupport/%s" % platform.name_in_plist.lower()))

  # Include bitcode symbol maps when needed.
  if (str(ctx.fragments.apple.bitcode_mode) == "embedded" and
      getattr(ctx.attr, "binary", None) and
      apple_common.AppleDebugOutputs in ctx.attr.binary):
    bitcode_maps_zip = bitcode_actions.zip_bitcode_symbols_maps(ctx)
    root_merge_zips.append(bundling_support.bundlable_file(
        bitcode_maps_zip, "BCSymbolMaps"))

  # Include any embedded bundles.
  for eb in embedded_bundles:
    apple_bundle = eb.apple_bundle
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
  objc_providers = provider_support.binary_or_deps_providers(ctx, "objc")
  propagated_framework_files = []
  for objc in objc_providers:
    files = objc.dynamic_framework_file
    if ctx.attr._propagates_frameworks:
      propagated_framework_files.extend(list(files))
    else:
      bundle_merge_files.extend(_bundlable_dynamic_framework_files(ctx, files))

  bundle_merge_files = _dedupe_bundle_merge_files(bundle_merge_files)

  # Perform the final bundling tasks.
  root_merge_zips_to_archive = root_merge_zips if _is_ipa(ctx) else []
  unprocessed_archive = _create_unprocessed_archive(
      ctx, bundle_name, bundle_path_in_archive, bundle_merge_files,
      bundle_merge_zips, root_merge_zips_to_archive, mnemonic,
      progress_description)
  work_dir = _process_and_sign_archive(
      ctx, bundle_name, bundle_path_in_archive, ctx.outputs.archive,
      unprocessed_archive, mnemonic, progress_description)

  additional_providers = {}

  # Create a .dSYM bundle with the expected name next to the .ipa in the output
  # directory. We still have to check for the existence of the AppleDebugOutputs
  # provider because some binary rules, such as apple_static_library, do not
  # propagate it.
  if (ctx.fragments.objc.generate_dsym and
      getattr(ctx.attr, "binary", None) and
      apple_common.AppleDebugOutputs in ctx.attr.binary):
    additional_outputs.extend(dsym_actions.create_symbol_bundle(ctx))
    additional_providers["AppleDebugOutputs"] = (
        ctx.attr.binary[apple_common.AppleDebugOutputs])

  objc_provider_args = {}
  if framework_files:
    framework_dir, bundled_framework_files = (
        _copy_framework_files(ctx, framework_files))
    if is_dynamic_framework:
      objc_provider_args["dynamic_framework_dir"] = depset([framework_dir])
      objc_provider_args["dynamic_framework_file"] = bundled_framework_files
    else:
      objc_provider_args["framework_dir"] = depset([framework_dir])
      objc_provider_args["static_framework_file"] = bundled_framework_files

  objc_provider_args["providers"] = objc_providers

  providers = {
      "apple_bundle": struct(
          archive=ctx.outputs.archive,
          archive_root=work_dir,
          infoplist=main_infoplist,
          propagated_framework_files=depset(propagated_framework_files),
          propagated_framework_zips=depset(propagated_framework_zips),
          root_merge_zips=root_merge_zips if not _is_ipa(ctx) else [],
          uses_swift=swift_support.uses_swift(ctx),
          bundle_id=bundle_id,
      ),
      "objc": apple_common.new_objc_provider(**objc_provider_args),
      "bundle_dirs": struct(**{"bundle_dirs": bundle_dirs})
  }
  for key, provider in additional_providers.items():
    providers[key] = provider

  return providers, depset(additional_outputs)


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
        framework_dir_name + framework_file.bundle_path)
    ctx.action(
        outputs=[output_file],
        inputs=[framework_file.file],
        mnemonic="Cp",
        arguments=[
            output_file.dirname, framework_file.file.path, output_file.path],
        command='mkdir -p "$1" && cp "$2" "$3"',
        progress_message=(
            "Copying " + framework_file.file.path + " to " + output_file.path)
    )
    bundled_framework_files.append(output_file)
  return (ctx.outputs.archive.dirname + "/" + framework_dir_name,
          depset(bundled_framework_files))


# Define the loadable module that lists the exported symbols in this file.
bundler = struct(
    run=_run,
)
