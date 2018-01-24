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

"""Helpers for defining bundling rules uniformly.

A not-so-brief discussion of the motivation behind the `path_formats` argument
to `make_bundling_rule`:

To support the differing bundle directory structures between macOS and
iOS/tvOS/watchOS, we use a set of format strings to determine where various
types of files should go in the bundle. These format strings are:

* `_path_in_archive_format`: The path relative to the archive root where the
  .app/.appex/etc. bundle should be placed. The placeholder "%s" is replaced
  with the name of the bundle. For example, an iOS application uses
  "Payload/%s" for this attribute, so an application named "Foo.app" will be
  placed in the final IPA archive at "Payload/foo.app". Extensions, which
  aren't shipped separately, just use "%s" to put them at the root of the ZIP
  archive.

* `_bundle_contents_path_format`: The path relative to the bundle root where
  all of the bundle's contents should be placed; contents include the
  resources directory, binary directory, frameworks directory, plugins, code
  signature, Info.plist, and so forth. The placeholder "%s" is substituted by
  the destination path of a file relative to the bundle's contents. For
  example, iOS/tvOS/watchOS use simply "%s" as their contents path format,
  so a file like Info.plist is substituted in and stays the same; this path
  is then appended to the bundle root to yield ".../Foo.app/Info.plist".
  macOS apps have a Contents directory in their bundle root so they use
  "Contents/%s" as their contents path format, so Info.plist ends up in
  ".../Foo.app/Contents/Info.plist".

* `_bundle_binary_path_format`: The path relative to the bundle's contents
  where the executable binary should be placed. iOS/tvOS/watchOS places
  this directly in the bundle's contents so they use simply "%s"; by
  combining this with the formats above, the path to Foo.app's binary is
  ".../Foo.app/Foo". macOS apps have a "MacOS" directory in their contents,
  so their binary path format is "MacOS/%s" and combined with above this
  yields ".../Foo.app/Contents/MacOS/Foo".

* `_bundle_resources_path_format`: The path relative to the bundle's contents
  where resources should be placed. iOS/tvOS/watchOS places these directly in
  the bundle's contents so they use simply "%s"; by combining this with the
  formats above, the path to Foo.app's bar.strings file is
  ".../Foo.app/bar.strings". macOS apps have a "Resources" directory in their
  contents, so their resource path format is "Resources/%s" and combined with
  above this yields ".../Foo.app/Contents/Resources/bar.strings".

To better visualize, iOS, tvOS, and watchOS bundles have the following
structure, where the bundle, contents, binary, and resources paths are all
the same:

    Payload/
      Foo.app/                [bundle, contents, binary, and resources paths]
        Assets.car
        Foo (the binary)
        Info.plist
        OtherResource.strings
        PkgInfo
        PlugIns/
          SomeExtension.appex/...

On the other hand, macOS bundles have the following structure, where each of
those paths differs:

    Foo.app/                         [bundle path]
      Contents/                      [contents path]
        MacOS/                       [binary path]
          Foo (the binary)
        PlugIns/
          SomeExtension.appex/...
        Resources/                   [resources path]
          Assets.car
          OtherResource.strings

Each bundling rule created by the factory will choose the correct format strings
for their platform through either `simple_path_formats` or `macos_path_formats`.
"""

load(
    "@build_bazel_rules_apple//apple/bundling:apple_bundling_aspect.bzl",
    "apple_bundling_aspect",
)
load(
    "@build_bazel_rules_apple//apple/bundling:entitlements.bzl",
    "AppleEntitlementsInfo",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleVersionInfo",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "merge_dictionaries",
)


# Serves as an enum to express if an attribute is unsupported, mandatory, or
# optional.
_attribute_modes = struct(
  UNSUPPORTED = 1,
  MANDATORY = 2,
  OPTIONAL = 3,
)

def _is_valid_attribute_mode(mode):
  return (mode == _attribute_modes.UNSUPPORTED or
      mode == _attribute_modes.MANDATORY or
      mode == _attribute_modes.OPTIONAL)


# Private attributes on every rule that provide access to tools and other
# file dependencies.
_common_tool_attributes = {
    "_dsym_info_plist_template": attr.label(
        cfg="host",
        single_file=True,
        default=Label(
            "@build_bazel_rules_apple//apple/bundling:dsym_info_plist_template",
        ),
    ),
    "_environment_plist": attr.label(
        cfg="host",
        executable=True,
        default=Label("@build_bazel_rules_apple//tools/environment_plist"),
    ),
    "_plisttool": attr.label(
        cfg="host",
        default=Label("@build_bazel_rules_apple//tools/plisttool"),
        executable=True,
    ),
    "_realpath": attr.label(
        cfg="host",
        allow_files=True,
        single_file=True,
        default=Label("@build_bazel_rules_apple//tools/realpath"),
    ),
    "_xcrunwrapper": attr.label(
        cfg="host",
        executable=True,
        default=Label("@bazel_tools//tools/objc:xcrunwrapper"),
    ),
    "_xcode_config": attr.label(
        default=configuration_field(
            fragment="apple", name="xcode_config_label"),
    ),
}


# Private attributes on every rule that provide access to tools used by the
# bundler.
_bundling_tool_attributes = {
    "_actoolwrapper": attr.label(
        cfg="host",
        executable=True,
        default=Label("@build_bazel_rules_apple//tools/actoolwrapper"),
    ),
    "_bundletool": attr.label(
        cfg="host",
        executable=True,
        default=Label("@build_bazel_rules_apple//tools/bundletool"),
    ),
    "_bundletool_experimental": attr.label(
        cfg="host",
        executable=True,
        default=Label("@build_bazel_rules_apple//tools/bundletool:bundletool_experimental"),
    ),
    "_clangrttool": attr.label(
        cfg="host",
        executable=True,
        default=Label("@build_bazel_rules_apple//tools/clangrttool"),
    ),
    "_ibtoolwrapper": attr.label(
        cfg="host",
        executable=True,
        default=Label("@build_bazel_rules_apple//tools/ibtoolwrapper"),
    ),
    "_ios_runner": attr.label(
        cfg="host",
        allow_files=True,
        single_file=True,
        default=Label("@bazel_tools//tools/objc:ios_runner.sh.mac_template"),
    ),
    "_mapcwrapper": attr.label(
        cfg="host",
        executable=True,
        default=Label("@build_bazel_rules_apple//tools/mapcwrapper"),
    ),
    "_momcwrapper": attr.label(
        cfg="host",
        executable=True,
        default=Label("@build_bazel_rules_apple//tools/momcwrapper"),
    ),
    "_process_and_sign_template": attr.label(
        single_file=True,
        default=Label("@build_bazel_rules_apple//tools/bundletool:process_and_sign_template"),
    ),
    "_std_redirect_dylib": attr.label(
        cfg="host",
        allow_files=True,
        single_file=True,
        default=Label("@bazel_tools//tools/objc:StdRedirect.dylib"),
    ),
    "_swiftstdlibtoolwrapper": attr.label(
        cfg="host",
        executable=True,
        default=Label("@build_bazel_rules_apple//tools/swiftstdlibtoolwrapper"),
    ),
}


def _attr_name(name, private=False):
  """Returns an attribute name, prefixed with an underscore if private.

  Args:
    name: The name of the attribute.
    private: True if the attribute should be private.
  Returns: The attribute name, prefixed with an underscore if private.
  """
  return ("_" + name) if private else name


def _code_signing(provision_profile_extension=None,
                  requires_signing_for_device=True,
                  skip_signing=False,
                  support_invalid_entitlements_are_warnings=False):
  """Returns code signing information for `make_bundling_rule`.

  Args:
    provision_profile_extension: The extension of the expected provisioning
        profile file, including the leading dot.
    requires_signing_for_device: True if the bundle must be signed to be
        deployed on a device, or false if it does not need to be signed.
    skip_signing: True if signing should be skipped entirely for the bundle.
    support_invalid_entitlements_are_warnings: True if the bundle allows
        allows the validation of requested entitlements vs. provisioning
        profile to be suppressed.

  Returns:
      A struct that can be passed as the `code_signing` argument to
      `make_bundling_rule`.
  """
  return struct(
      provision_profile_extension=provision_profile_extension,
      requires_signing_for_device=requires_signing_for_device,
      skip_signing=skip_signing,
      support_invalid_entitlements_are_warnings=support_invalid_entitlements_are_warnings)


def _device_families(allowed, mandatory=True):
  """Returns device family information for `make_bundling_rule`.

  Args:
    allowed: The list of allowed device families.
    mandatory: True if the user must provide a list of device families with the
        `families` attribute. This is ignored if `allowed` only contains one
        device family, in which case `families` is not available. Defaults to
        True.
  Returns: A struct that can be passed as the `device_families` argument to
      `make_bundling_rule`.
  """
  return struct(allowed=allowed, mandatory=mandatory)


def _macos_path_formats(path_in_archive_format="%s"):
  """Returns macOS-style bundle path format attributes.

  The returned dictionary can be passed in as the `path_formats` argument to the
  `make_bundling_rule`.

  Args:
    path_in_archive_format: The format string used to construct the path within
        the archive where the bundle will be placed; a single `%s` will be
        replaced with the name of the bundle.
  Returns:
    A dictionary of path format attributes for macOS bundles.
  """
  return {
      "_bundle_binary_path_format": attr.string(default="MacOS/%s"),
      "_bundle_contents_path_format": attr.string(default="Contents/%s"),
      "_bundle_resources_path_format": attr.string(default="Resources/%s"),
      "_path_in_archive_format": attr.string(default=path_in_archive_format),
  }


def _code_signing_attributes(code_signing):
  """Returns rule attributes that manage code signing.

  Args:
    code_signing: A value returned by `rule_factory.code_signing` that provides
        information about if and how the bundle should be signed.
  Returns:
    A dictionary of attributes that should be used by rules that require code
    signing.
  """
  if not code_signing:
    fail("Internal error: code_signing must be provided.")

  # Configure the entitlements, provisioning_profile, and other private
  # attributes for targets that should be signed.
  code_signing_attrs = {
      "_requires_signing_for_device": attr.bool(
          default=code_signing.requires_signing_for_device
      ),
      "_skip_signing": attr.bool(default=code_signing.skip_signing),
  }
  if not code_signing.skip_signing:
    code_signing_attrs["entitlements"] = attr.label(
        providers=[[], [AppleEntitlementsInfo]],
    )
    if not code_signing.provision_profile_extension:
      fail("Internal error: If code_signing.skip_signing = False, then " +
           "code_signing.provision_profile_extension must be provided.")
    code_signing_attrs["provisioning_profile"] = attr.label(
        allow_files=[code_signing.provision_profile_extension],
        single_file=True,
    )
    if code_signing.support_invalid_entitlements_are_warnings:
      code_signing_attrs["invalid_entitlements_are_warnings"] = attr.bool(
          doc=("If True, only issue warnings (instead of errors) when " +
               "checking the requested entitlements against the " +
               "provisioning profile to ensure they are supported."),
      )

  return code_signing_attrs


def _make_bundling_rule(implementation,
                        additional_attrs={},
                        archive_extension=None,
                        binary_providers=[apple_common.AppleExecutableBinary],
                        bundle_id_attr_mode=_attribute_modes.MANDATORY,
                        code_signing=None,
                        device_families=None,
                        infoplists_attr_mode=_attribute_modes.MANDATORY,
                        needs_pkginfo=False,
                        path_formats=None,
                        platform_type=None,
                        product_type=None,
                        propagates_frameworks=False,
                        use_binary_rule=True,
                        **kwargs):
  """Creates and returns an Apple bundling rule with the given properties.

  Args:
    implementation: The implementation function for the rule.
    additional_attrs: Additional attributes that should be defined on the rule.
    archive_extension: The extension of the archive produced as an output of the
        new rule, including the leading dot (for example, `.ipa` or `.zip`).
    binary_providers: The providers that should restrict the `binary` attribute
        of the rule. Defaults to `[apple_common.AppleExecutableBinary]`.
    bundle_id_attr_mode: An `attribute_modes` for the `bundle_id` attribute.
    code_signing: A value returned by `rule_factory.code_signing` that provides
        information about if and how the bundle should be signed.
    device_families: A value returned by `rule_factory.device_families` that
        provides information about the allowed device families for the bundle.
    infoplists_attr_mode: An `attribute_modes` for the `infoplists` attribute.
    needs_pkginfo: True if the bundle should include a `PkgInfo` file.
    path_formats: A dictionary containing bundle path format attributes, as
        returned from `rule_factory.simple_path_formats` or
        `rule_factory.macos_path_formats`.
    platform_type: A member of the `apple_common.platform_type` enumeration that
        indicates which platform type for which this rule will build bundles.
    product_type: A value returned by `rule_factory.product_type` that provides
        information about the default product type for targets created by this
        rule and whether or not the attribute is private.
    propagates_frameworks: True if the targets created by this rule should
        propagate their framework/dylib dependencies to the bundles that embed
        them, rather than being bundled with the target itself.
    use_binary_rule: True if this depends on a full-fledged binary rule,
        such as apple_binary or apple_stub_binary.
    **kwargs: Additional arguments that are passed directly to `rule()`.

  Returns:
    The created rule.
  """
  if not archive_extension:
    fail("Internal error: archive_extension must be provided.")
  if not binary_providers:
    fail("Internal error: binary_providers must be provided.")
  if not _is_valid_attribute_mode(bundle_id_attr_mode):
    fail("Internal error: bundle_id_attr_mode is invalid.")
  if not device_families:
    fail("Internal error: device_families must be provided.")
  if not _is_valid_attribute_mode(infoplists_attr_mode):
    fail("Internal error: infoplists_attr_mode is invalid.")
  if not path_formats:
    fail("Internal error: path_formats must be provided.")
  if not platform_type:
    fail("Internal error: platform_type must be provided.")
  if not product_type:
    fail("Internal error: product_type must be provided.")

  # Add the private _allowed_families attribute, and if multiple device families
  # were present, add the public families attribute that requires the user to
  # specify the subset they want.
  allowed_device_families = device_families.allowed
  device_family_attrs = {
      "_allowed_families": attr.string_list(default=allowed_device_families),
  }
  if device_families.mandatory and len(allowed_device_families) > 1:
    device_family_attrs["families"] = attr.string_list(
        mandatory=True,
        allow_empty=False,
    )

  product_type_attrs = {
      _attr_name("product_type", product_type.private): attr.string(
          default=product_type.default,
      ),
  }

  configurable_attrs = {}
  if bundle_id_attr_mode != _attribute_modes.UNSUPPORTED:
    want_mandatory = (bundle_id_attr_mode == _attribute_modes.MANDATORY)
    configurable_attrs["bundle_id"] = attr.string(mandatory=want_mandatory)
  if infoplists_attr_mode != _attribute_modes.UNSUPPORTED:
    want_mandatory = (infoplists_attr_mode == _attribute_modes.MANDATORY)
    configurable_attrs["infoplists"] = attr.label_list(
        allow_files=[".plist"],
        mandatory=want_mandatory,
        non_empty=want_mandatory,
    )

  if use_binary_rule:
    binary_dep_attrs = {
      "binary": attr.label(
          mandatory=True,
          providers=binary_providers,
          single_file=True,
      ),
      # Even for rules that don't bundle a user-provided binary (like
      # watchos_application and some ios_application/extension targets), the
      # binary acts as a "choke point" where the split transition is applied
      # to all the deps, which gives us proper propagation of the platform
      # type, minimum OS version, and other such attributes.
      #
      # "deps" as a label list is used here for consistency in traversing
      # transitive dependencies (for example using aspects), but exactly one
      # dependency (the binary) should be set.
      "deps": attr.label_list(
          aspects=[apple_bundling_aspect],
          mandatory=True,
          providers=binary_providers,
      ),
    }
  else:
    binary_dep_attrs = {
      "deps": attr.label_list(
          aspects=[apple_bundling_aspect],
          cfg=apple_common.multi_arch_split,
      ),
      # Required by apple_common.multi_arch_split on 'deps'.
      "platform_type": attr.string(mandatory=True),
    }

  rule_args = dict(**kwargs)
  rule_args["attrs"] = merge_dictionaries(
      _common_tool_attributes,
      _bundling_tool_attributes,
      {
          "bundle_name": attr.string(mandatory=False),
          # TODO(b/36512239): Rename to "bundle_post_processor".
          "ipa_post_processor": attr.label(
              allow_files=True,
              executable=True,
              cfg="host",
          ),
          "minimum_os_version": attr.string(mandatory=False),
          "strings": attr.label_list(allow_files=[".strings"]),
          "version": attr.label(providers=[[AppleBundleVersionInfo]]),
          "_needs_pkginfo": attr.bool(default=needs_pkginfo),
          "_platform_type": attr.string(default=str(platform_type)),
          "_propagates_frameworks": attr.bool(default=propagates_frameworks),
      },
      configurable_attrs,
      _code_signing_attributes(code_signing),
      device_family_attrs,
      path_formats,
      product_type_attrs,
      binary_dep_attrs,
      additional_attrs,
  )

  archive_name = "%{name}" + archive_extension
  return rule(implementation,
              fragments=["apple", "objc"],
              outputs={"archive": archive_name},
              **rule_args)


def _product_type(default, private=False):
  """Returns code signing information for `make_bundling_rule`.

  Args:
    default: The default value for the product type identifier.
    private: True if the attribute should be defined privately (that is, the
        user cannot override it in a target).
  Returns: A struct that can be passed as the `product_type` argument to
      `make_bundling_rule`.
  """
  return struct(default=default, private=private)


def _simple_path_formats(path_in_archive_format=""):
  """Returns simple (mobile) bundle path format attributes.

  The returned dictionary can be passed in as the `path_formats` argument to the
  `make_bundling_rule`.

  Args:
    path_in_archive_format: The format string used to construct the path within
        the archive where the bundle will be placed; a single `%s` will be
        replaced with the name of the bundle.
  Returns:
    A dictionary of path format attributes for iOS, tvOS, and watchOS bundles.
  """
  return {
      "_bundle_binary_path_format": attr.string(default="%s"),
      "_bundle_contents_path_format": attr.string(default="%s"),
      "_bundle_resources_path_format": attr.string(default="%s"),
      "_path_in_archive_format": attr.string(default=path_in_archive_format),
  }


# Define the loadable module that lists the exported symbols in this file.
rule_factory = struct(
    attribute_modes=_attribute_modes,
    bundling_tool_attributes=_bundling_tool_attributes,
    code_signing=_code_signing,
    code_signing_attributes=_code_signing_attributes,
    common_tool_attributes=_common_tool_attributes,
    device_families=_device_families,
    macos_path_formats=_macos_path_formats,
    make_bundling_rule=_make_bundling_rule,
    product_type=_product_type,
    simple_path_formats=_simple_path_formats,
)
