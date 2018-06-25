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

"""Actions related to codesigning."""

load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@build_bazel_rules_apple//apple/bundling:codesigning_support.bzl",
    "codesigning_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:entitlements.bzl",
    "AppleEntitlementsInfo",
)
load(
    "@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:intermediates.bzl",
    "intermediates",
)

def _post_process_and_sign_archive_action(
    ctx,
    archive_codesigning_path,
    frameworks_path,
    input_archive,
    output_archive):
  """Post-processes and signs an archived bundle.

  Args:
    ctx: The target's rule context.
    archive_codesigning_path: The codesigning path relative to the archive.
    frameworks_path: The Frameworks path relative to the archive.
    input_archive: The `File` representing the archive containing the bundle
      that has not yet been processed or signed.
    output_archive: The `File` representing the processed and signed archive.
  """
  input_files = [input_archive]

  entitlements = None
  # Use the entitlements from the internal provider if it's present (to support
  # rules that manipulate them before passing them to the bundler); otherwise,
  # use the file that was provided instead.
  if getattr(ctx.attr, "entitlements", None):
    if AppleEntitlementsInfo in ctx.attr.entitlements:
      entitlements = (
          ctx.attr.entitlements[AppleEntitlementsInfo].final_entitlements
      )
    else:
      entitlements = ctx.file.entitlements

  if entitlements:
    input_files.append(entitlements)

  provisioning_profile = getattr(ctx.file, "provisioning_profile", None)
  if provisioning_profile:
    input_files.append(provisioning_profile)

  signing_command_lines = ""
  if not ctx.attr._skip_signing:
    paths_to_sign = [
        codesigning_support.path_to_sign(
            paths.join("$WORK_DIR", frameworks_path) + "/",
            optional=True, glob="*",
        ),
    ]
    is_device = platform_support.is_device_build(ctx)
    if is_device or codesigning_support.should_sign_simulator_bundles(ctx):
      paths_to_sign.append(
          codesigning_support.path_to_sign(
              paths.join("$WORK_DIR", archive_codesigning_path)
          ),
      )
    signing_command_lines = codesigning_support.signing_command_lines(
        ctx, paths_to_sign, entitlements)

  ipa_post_processor = ctx.executable.ipa_post_processor
  ipa_post_processor_path = ""
  if ipa_post_processor:
    ipa_post_processor_path = ipa_post_processor.path
    input_files.append(ipa_post_processor)

  # The directory where the archive contents will be collected. This path is
  # also passed out via the AppleBundleInfo provider so that external tools can
  # access the bundle layout directly, saving them an extra unzipping step.
  work_dir = paths.replace_extension(output_archive.path, ".archive-root")

  # Only compress the IPA for optimized (release) builds. For debug builds,
  # zip without compression, which will speed up the build.
  should_compress = (ctx.var["COMPILATION_MODE"] == "opt")

  process_and_sign_template = intermediates.file(
      ctx.actions, ctx.label.name, "process-and-sign.sh")
  ctx.actions.expand_template(
      template=ctx.file._process_and_sign_template,
      output=process_and_sign_template,
      is_executable=True,
      substitutions={
          "%ipa_post_processor%": ipa_post_processor_path or "",
          "%output_path%": output_archive.path,
          "%should_compress%": "1" if should_compress else "",
          "%signing_command_lines%": signing_command_lines,
          "%unprocessed_archive_path%": input_archive.path,
          "%work_dir%": work_dir,
      },
  )

  platform_support.xcode_env_action(
      ctx,
      inputs=input_files,
      outputs=[output_archive],
      executable=process_and_sign_template,
      mnemonic="ProcessAndSign",
      progress_message="Processing and signing %s" % ctx.label.name,
  )

codesigning_actions = struct(
    post_process_and_sign_archive_action=_post_process_and_sign_archive_action
)
