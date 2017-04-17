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

"""Defines common attributes used in all Apple bundling rules.

Note: The attributes for each rule are split into a few groupings:

- Tool attributes: Private label-typed attributes that have default values
  pointing to scripts and other common resources that are needed by all
  target types.
- Public attributes: Attributes that the user specifies on their targets.
- Private non-tool attributes: Attributes with default values that differ
  depending on the type of rule (application vs. extension, iOS vs. tvOS,
  etc.).

The last category of attributes in particular lets us achieve a sort of
"polymorphism" in our shared rule implementation functions, since they can
be effectively parameterized by grabbing rule-specific attributes from the
Skylark context.
"""

load("//apple/bundling:apple_bundling_aspect.bzl",
     "apple_bundling_aspect")
load("//apple:utils.bzl", "merge_dictionaries")


# Attributes that define tool dependencies.
def _tool_attributes():
  return {
      "_actoolwrapper": attr.label(
          cfg="host",
          executable=True,
          default=Label("//tools/actoolwrapper"),
      ),
      "_bundler_py": attr.label(
          cfg="host",
          single_file=True,
          default=Label("//apple/bundling:bundler_py"),
      ),
      "_debug_entitlements": attr.label(
          cfg="host",
          allow_files=True,
          single_file=True,
          default=Label("@bazel_tools//tools/objc:device_debug_entitlements.plist"),
      ),
      "_dsym_info_plist_template": attr.label(
          cfg="host",
          single_file=True,
          default=Label(
              "//apple/bundling:dsym_info_plist_template"),
      ),
      "_environment_plist": attr.label(
          cfg="host",
          executable=True,
          default=Label("//tools/environment_plist"),
      ),
      "_ibtoolwrapper": attr.label(
          cfg="host",
          executable=True,
          default=Label("//tools/ibtoolwrapper"),
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
          default=Label("//tools/mapcwrapper"),
      ),
      "_momcwrapper": attr.label(
          cfg="host",
          executable=True,
          default=Label("//tools/momcwrapper"),
      ),
      "_plisttool": attr.label(
          cfg="host",
          single_file=True,
          default=Label("//apple/bundling:plisttool"),
      ),
      "_process_and_sign_template": attr.label(
          single_file=True,
          default=Label(
              "//apple/bundling:process_and_sign_template"),
      ),
      "_realpath": attr.label(
          cfg="host",
          allow_files=True,
          single_file=True,
          default=Label("//tools/realpath"),
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
          default=Label("//tools/swiftstdlibtoolwrapper"),
      ),
      "_xcrunwrapper": attr.label(
          cfg="host",
          executable=True,
          default=Label("@bazel_tools//tools/objc:xcrunwrapper"),
      ),
  }


# To support the differing bundle directory structures between macOS and
# iOS/tvOS/watchOS, we use a set of format strings to determine where various
# types of files should go in the bundle. These format strings are:
#
# * `_path_in_archive_format`: The path relative to the archive root where the
#   .app/.appex/etc. bundle should be placed. The placeholder "%s" is replaced
#   with the name of the bundle. For example, an iOS application uses
#   "Payload/%s" for this attribute, so an application named "Foo.app" will be
#   placed in the final IPA archive at "Payload/foo.app". Extensions, which
#   aren't shipped separately, just use "%s" to put them at the root of the ZIP
#   archive.
#
# * `_bundle_contents_path_format`: The path relative to the bundle root where
#   all of the bundle's contents should be placed; contents include the
#   resources directory, binary directory, frameworks directory, plugins, code
#   signature, Info.plist, and so forth. The placeholder "%s" is substituted by
#   the destination path of a file relative to the bundle's contents. For
#   example, iOS/tvOS/watchOS use simply "%s" as their contents path format,
#   so a file like Info.plist is substituted in and stays the same; this path
#   is then appended to the bundle root to yield ".../Foo.app/Info.plist".
#   macOS apps have a Contents directory in their bundle root so they use
#   "Contents/%s" as their contents path format, so Info.plist ends up in
#   ".../Foo.app/Contents/Info.plist".
#
# * `_bundle_binary_path_format`: The path relative to the bundle's contents
#   where the executable binary should be placed. iOS/tvOS/watchOS places
#   this directly in the bundle's contents so they use simply "%s"; by
#   combining this with the formats above, the path to Foo.app's binary is
#   ".../Foo.app/Foo". macOS apps have a "MacOS" directory in their contents,
#   so their binary path format is "MacOS/%s" and combined with above this
#   yields ".../Foo.app/Contents/MacOS/Foo".
#
# * `_bundle_resources_path_format`: The path relative to the bundle's contents
#   where resources should be placed. iOS/tvOS/watchOS places these directly in
#   the bundle's contents so they use simply "%s"; by combining this with the
#   formats above, the path to Foo.app's bar.strings file is
#   ".../Foo.app/bar.strings". macOS apps have a "Resources" directory in their
#   contents, so their resource path format is "Resources/%s" and combined with
#   above this yields ".../Foo.app/Contents/Resources/bar.strings".
#
# To better visualize, iOS, tvOS, and watchOS bundles have the following
# structure, where the bundle, contents, binary, and resources paths are all
# the same:
#
#     Payload/
#       Foo.app/                [bundle, contents, binary, and resources paths]
#         Assets.car
#         Foo (the binary)
#         Info.plist
#         OtherResource.strings
#         PkgInfo
#         PlugIns/
#           SomeExtension.appex/...
#
# On the other hand, macOS bundles have the following structure, where each of
# those paths differs:
#
#     Foo.app/                         [bundle path]
#       Contents/                      [contents path]
#         MacOS/                       [binary path]
#           Foo (the binary)
#         PlugIns/
#           SomeExtension.appex/...
#         Resources/                   [resources path]
#           Assets.car
#           OtherResource.strings
#
# Since the three modern Apple platforms use simpler bundle structures, those
# default values are provided here. The macOS rules override them with the
# appropriate values for that platform.


# Attributes that define the simpler iOS/tvOS/watchOS bundle directory
# structure.
def simple_path_format_attributes():
  return {
      "_bundle_binary_path_format": attr.string(default="%s"),
      "_bundle_contents_path_format": attr.string(default="%s"),
      "_bundle_resources_path_format": attr.string(default="%s"),
  }


# Attributes that define the special macOS bundle directory structure.
def macos_path_format_attributes():
  return {
      "_bundle_binary_path_format": attr.string(default="MacOS/%s"),
      "_bundle_contents_path_format": attr.string(default="Contents/%s"),
      "_bundle_resources_path_format": attr.string(default="Resources/%s"),
  }


# Attributes that are common to all packaging rules with or without
# user-provided binaries.
def common_rule_without_binary_attributes():
  return merge_dictionaries(
      _tool_attributes(),
      simple_path_format_attributes(),
      {
          "bundle_id": attr.string(
              mandatory=True,
          ),
          "deps": attr.label_list(
              aspects=[apple_bundling_aspect],
              providers=[
                  ["apple_resource"],
                  ["objc"],
                  ["swift"],
              ],
          ),
          "infoplists": attr.label_list(
              allow_files=[".plist"],
              mandatory=True,
              non_empty=True,
          ),
          # TODO(b/36512239): Rename to "archive_post_processor".
          "ipa_post_processor": attr.label(
              allow_files=True,
              executable=True,
              cfg="host",
          ),
          "provisioning_profile": attr.label(
              allow_files=[".mobileprovision"],
              single_file=True,
          ),
          "strings": attr.label_list(allow_files=[".strings"]),
          # Whether or not the target should host a Frameworks directory or
          # propagate its frameworks to the target in which it is embedded. For
          # example, applications host frameworks (False, the default), but
          # extensions have their frameworks bundled with the host application
          # instead.
          "_propagates_frameworks": attr.bool(default=False),
          # Whether to skip all code signing. This is useful for artifacts that
          # contain binaries but are meant for distribution to other developers
          # to use in their own projects, where they will do their own signing
          # and handle their own provisioning.
          "_skip_signing": attr.bool(default=False),
      }
  )


# Attributes that are common to all packaging rules with user-provided
# binaries.
def common_rule_attributes():
  return merge_dictionaries(common_rule_without_binary_attributes(), {
      "binary": attr.label(
          allow_rules=["apple_binary"],
          aspects=[apple_bundling_aspect],
          single_file=True,
      ),
  })
