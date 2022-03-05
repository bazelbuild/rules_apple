#!/bin/bash

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

# Common utilities that are useful across a variety of Apple shell integration
# tests.


# Usage: assert_exists <path>
#
# Asserts that the file at the given path exists.
function assert_exists() {
  local path="$1"
  [ -f "$path" ] && return 0

  fail "Expected file '$path' to exist, but it did not"
  return 1
}


# Usage: assert_not_exists <path>
#
# Asserts that the file at the given path does not exist.
function assert_not_exists() {
  local path="$1"
  [ ! -f "$path" ] && return 0

  fail "Expected file '$path' to not exist, but it does"
  return 1
}


# Builds a regex to match a path in ZIP assert helpers by escaping some
# characters that might appear in filenames and preceding it by ^. Also
# follows it by $ unless the path ends in "/\?", which is used to check for
# either a file or a directory.
function quote_path_regex() {
  local path="$1"

  if echo "$path" | grep '/\?$' ; then
    echo "$path" | sed -e 's/\([.+]\)/\\\1/g' -e 's/^.*$/^&/g'
  else
    echo "$path" | sed -e 's/\([.+]\)/\\\1/g' -e 's/^.*$/^&$/g'
  fi
}


# Usage: assert_zip_contains <archive> <path_in_archive>
#
# Asserts that the file or directory at path `path_in_archive` exists in the
# zip `archive`. If the path ends in "/\?", it will assert that either a file or
# directory with that name is found.
function assert_zip_contains() {
  local archive="$1"
  local path="$2"

  local zip_contents=$(zipinfo -1 "$archive" || fail "Cannot list contents of $archive")
  echo "$zip_contents" | grep -e "$(quote_path_regex "$path")" > /dev/null \
      || fail "Archive $archive did not contain ${path};" \
              "contents were: $zip_contents"
}


# Usage: assert_zip_not_contains <archive> <path_in_archive>
#
# Asserts that the file or directory at path `path_in_archive` does not exist
# in the zip `archive`. If the path ends in "/\?", it will assert that neither a
# file nor directory with that name is found.
function assert_zip_not_contains() {
  local archive="$1"
  local path="$2"

  local zip_contents=$(zipinfo -1 "$archive" || fail "Cannot extract contents of $archive")
  echo "$zip_contents" | grep -e "$(quote_path_regex "$path")" > /dev/null \
      && fail "Archive $archive contained $path, but it should not;" \
              "contents were: $zip_contents" \
      || true
}

# Usage: assert_assets_contains <archive> <assets_path_in_archive> <image_name>
#
# Asserts that the Assets.car at `assets_path_in_archive` within the zip
# `archive` contains a reference to the image with name `image_name`.
function assert_assets_contains() {
  local archive="$1"
  local assets_path="$2"
  local image_name="$3"

  mkdir -p tempdir
  local unzipped_assets="tempdir/Assets.car"

  unzip_single_file "$archive" "$assets_path" > $unzipped_assets
  strings "$unzipped_assets" | grep -e "$image_name" > /dev/null \
      || fail "File $assets_path did not contain $image_name"
  rm -rf tempdir
}

# Usage: build_path <target_label>
#
# Returns the relative path to the BUILD file for the given target by stripping
# the leading slashes, then removing the target name portion (":foo") and
# appending "BUILD".
function build_path() {
  local target_label="$1"
  local no_slashes="${target_label#//}"
  echo "${no_slashes%%:*}/BUILD"
}


# Usage: create_dump_plist [--suffix SUFFIX] <zip_label> <plist_path> <keys...>
#
# Concatenates a target named "dump_plist" to the BUILD file that owns
# `zip_label`, which dumps keys and values from a plist into text files
# that can be checked using assertions.
#
# `--suffix SUFFIX` is optional, and if present, will be used as a suffix
# on the `dump_plist` rule name and will be used as a suffix on all the
# keypath file names dumped into. This allows multiple plists to be dumpe
# from a single target directory.
#
# `zip_label` should be the absolute label of a bundling rule that outputs
# either a ZIP or IPA file.
#
# `plist_path` is the archive-root-relative path to the plist file to be
# dumped (for example, "Payload/app.app/Info.plist").
#
# The remaining arguments are keypaths in PlistBuddy notation representing
# the values to dump. Each value will be dumped to a file in the package's
# genfiles directory with the same name as the keypath, with colons in the
# keypath replaced by dots.
#
# Example:
#     create_dump_plist //app:app Payload/app.app/Info.plist \
#         CFBundleIdentifier CFBundleSupportedPlatforms:0
#     do_build ios //app:dump_plist
#     assert_equals "my.bundle.id" \
#         "$(cat "test-bin/app/CFBundleIdentifier")"
function create_dump_plist() {
  if [[ "$1" == "--suffix" ]]; then
    shift; SUFFIX="_$1"; shift
  else
    SUFFIX=
  fi
  local zip_label="$1"; shift
  local plist_path="$1"; shift

  local build_path="$(build_path "$zip_label")"

  # There is no convenient way to get an arbitrary value out of a Plist file on
  # Linux, so we create an action we run on a Mac to dump out the values we
  # care about to files in a genrule, and then assert on the contents of those
  # files.
  cat >> "${build_path}" <<EOF
genrule(
    name = "dump_plist${SUFFIX}",
    srcs = ["${zip_label}"],
    testonly = 1,
    outs = [
EOF

  for keypath in "$@"; do
    filename="${keypath//:/.}${SUFFIX}"
    echo "        \"${filename}\"," >> "${build_path}"
  done

  cat >> "${build_path}" <<EOF
    ],
    cmd =
        "INPUTS=\"\$(locations ${zip_label})\" ;" +
        "ZIP_INPUT=\`echo \$\${INPUTS} | tr \" \" \"\\\n\" | grep \"\\\\(ipa\\\\|zip\\\\)\$\$\"\`;" +
        "set -e && " +
        "temp=\$\$(mktemp -d \"\$\${TEST_TMPDIR:-/tmp}/dump_plist.XXXXXX\") && " +
        "/usr/bin/unzip -q \$\${ZIP_INPUT} -d \$\${temp} && " +
        "plist=\$\${temp}/${plist_path} && " +
EOF

  for keypath in "$@"; do
    filename="${keypath//:/.}${SUFFIX}"
    echo "        \"/usr/libexec/PlistBuddy -c \\\"Print ${keypath}\\\" \$\${plist} > \$(@D)/${filename} && \" +" \
        >> "${build_path}"
  done

  cat >> "${build_path}" <<EOF
        "rm -rf \$\${temp}",
    tags = ["requires-darwin"],
)
EOF
}


# Usage: create_dump_whole_plist [--suffix SUFFIX] <zip_label> <plist_path>
#
# Concatenates a target named "dump_whole_plist" to the BUILD file that owns
# `zip_label`, which dumps a plist into a text file that can be checked using
# assertions. Unlike create_dump_plist, this output is useful to checking
# that a given key/value pair is *not* present.
#
# `--suffix SUFFIX` is optional, and if present, will be used as a suffix
# on the `dump_whole_plist` rule name and will be used as a suffix on all the
# file name dumped into. This allows multiple plists to be dumped
# from a single target directory.
#
# `zip_label` should be the absolute label of a bundling rule that outputs
# either a ZIP or IPA file.
#
# `plist_path` is the archive-root-relative path to the plist file to be
# dumped (for example, "Payload/app.app/Info.plist").
#
# Example:
#     create_whole_dump_plist //app:app Payload/app.app/Info.plist
#     do_build ios //app:dump_plist
#     assert_contains "my.bundle.id" \
#         "$(cat "test-bin/app/dump_whole_plist.txt")"
function create_whole_dump_plist() {
  if [[ "$1" == "--suffix" ]]; then
    shift; SUFFIX="_$1"; shift
  else
    SUFFIX=
  fi
  local zip_label="$1"; shift
  local plist_path="$1"; shift

  local build_path="$(build_path "$zip_label")"

  cat >> "${build_path}" <<EOF
genrule(
    name = "dump_whole_plist${SUFFIX}",
    srcs = ["${zip_label}"],
    testonly = 1,
    outs = ["dump_whole_plist${SUFFIX}.txt"],
    cmd =
        "INPUTS=\"\$(locations ${zip_label})\" ;" +
        "ZIP_INPUT=\`echo \$\${INPUTS} | tr \" \" \"\\\n\" | grep \"\\\\(ipa\\\\|zip\\\\)\$\$\"\`;" +
        "set -e && " +
        "temp=\$\$(mktemp -d \"\$\${TEST_TMPDIR:-/tmp}/dump_plist.XXXXXX\") && " +
        "/usr/bin/unzip -q \$\${ZIP_INPUT} -d \$\${temp} && " +
        "plist=\$\${temp}/${plist_path} && " +
        "/usr/libexec/PlistBuddy -c Print \$\${plist} > \$@ && " +
        "rm -rf \$\${temp}",
    tags = ["requires-darwin"],
)
EOF
}


# Usage: create_dump_codesign <zip_label> <archive_path> <codesign_args...>
#
# Concatenates a target named "dump_codesign" to the BUILD file that owns
# `zip_label`, which dumps the results of executing `codesign` with the given
# arguments on a path inside the archive. The results are sent to a file named
# `codesign_output` in the genfiles directory for the target's package.
#
# `zip_label` should be the absolute label of a bundling rule that outputs
# either a ZIP or IPA file.
#
# `archive_path` should be the path within the archive on which codesign should
# be executed (for example, "Payload/app.app").
#
# `codesign_args` is a list of arguments that should be passed to the codesign
# invocation. They are inserted before the archive path.
function create_dump_codesign() {
  local zip_label="$1"; shift
  local archive_path="$1"; shift

  local build_path="$(build_path "$zip_label")"

  cat >> "${build_path}" <<EOF
genrule(
    name = "dump_codesign",
    srcs = ["${zip_label}"],
    testonly = 1,
    outs = ["codesign_output"],
    cmd =
        "INPUTS=\"\$(locations ${zip_label})\" ;" +
        "ZIP_INPUT=\`echo \$\${INPUTS} | tr \" \" \"\\\n\" | grep \"\\\\(ipa\\\\|zip\\\\)\$\$\"\`;" +
        "set -e && " +
        "temp=\$\$(mktemp -d \"\$\${TEST_TMPDIR:-/tmp}/dump_codesign.XXXXXX\") && " +
        "/usr/bin/unzip -q \$\${ZIP_INPUT} -d \$\${temp} && " +
        "codesign $@ \$\${temp}/${archive_path} &> \$@ && " +
        "rm -rf \$\${temp}",
    tags = ["requires-darwin"],
)
EOF
}


# Usage assert_is_codesigned <path>
#
# Asserts that the given bundle path is properly codesigned.
function assert_is_codesigned() {
  local bundle="$1"
  CODESIGN_OUTPUT="$(mktemp "${TMPDIR:-/tmp}/codesign_output.XXXXXX")"

  codesign -vvvv "$bundle" &> "$CODESIGN_OUTPUT" || echo "Should not fail"

  assert_contains "satisfies its Designated Requirement" "$CODESIGN_OUTPUT"
  assert_contains "valid on disk" "$CODESIGN_OUTPUT"

  rm -rf "$CODESIGN_OUTPUT"
}


# Usage assert_frameworks_not_resigned_given_output <path>
#
# If the output file from ipa_post_processor_verify_codesigning.sh was found,
# asserts that the frameworks in the bundle have not been resigned.
function assert_frameworks_not_resigned_given_output() {
  local bundle="$1"

  WORKDIR="$1"
  if [ "$APPLE_SDK_PLATFORM" != "MacOSX" ]; then
    CODESIGN_FMWKS_ORIGINAL_OUTPUT="$bundle/codesign_v_fmwks_output.txt"
    FRAMEWORK_DIR="$bundle/Frameworks"
  else
    CODESIGN_FMWKS_ORIGINAL_OUTPUT="$bundle/Contents/Resources/codesign_v_fmwks_output.txt"
    FRAMEWORK_DIR="$bundle/Contents/Frameworks"
  fi

  if [[ -d "$CODESIGN_FMWKS_ORIGINAL_OUTPUT" ]]; then
    CODESIGN_FMWKS_OUTPUT="$(mktemp "${TMPDIR:-/tmp}/codesign_fmwks_output.XXXXXX")"

    for fmwk in \
        $(find "$FRAMEWORK_DIR" -type d -maxdepth 1 -mindepth 1); do
      /usr/bin/codesign --display --verbose=3 "$fmwk" 2>&1 | egrep "^[^Executable=]" >> "$CODESIGN_FMWKS_OUTPUT"
    done

    assert_equals "$(cat $CODESIGN_FMWKS_OUTPUT)" "$(cat $CODESIGN_FMWKS_ORIGINAL_OUTPUT)"

    rm -rf "$CODESIGN_FMWKS_OUTPUT"
  fi
}


# Usage: current_archs <platform>
#
# Prints the architectures for the given platform that were specified in the
# configuration used to run the current test. For multiple architectures, the
# values will be printed on separate lines; the output here is typically meant
# to be captured into an array.
function current_archs() {
  local platform="$1"
  if [[ "$platform" == ios ]]; then
    # Fudge the ios platform name to match the expected command line option.
    platform=ios_multi
  fi

  for option in "${EXTRA_BUILD_OPTIONS[@]-}"; do
    case "$option" in
      --"${platform}"_cpus=*)
        value="$(echo "$option" | cut -d= -f2)"
        echo "$value" | tr "," "\n"
        return
        ;;
    esac
  done
}


# Usage: do_build <platform> <other options...>
#
# Helper function to invoke `bazel build` that applies --verbose_failures and
# log redirection for the test harness, along with any extra arguments that
# were passed in via the `apple_shell_test`'s attribute. The first argument is
# the platform required; the remaining arguments are passed directly to bazel.
#
# Test builds use "test-" as the output directory symlink prefix, so tests
# should expect to find their outputs in "test-bin".
#
# Example:
#     do_build ios --some_other_flag //foo:bar
function do_build() {
  do_action build "$@"
}


# Usage: do_test <platform> <other options...>
#
# Helper function to invoke `bazel test` that applies --verbose_failures and
# log redirection for the test harness, along with any extra arguments that
# were passed in via the `apple_shell_test`'s attribute. The first argument is
# the platform required; the remaining arguments are passed directly to bazel.
#
# Test builds use "test-" as the output directory symlink prefix, so tests
# should expect to find their outputs in "test-bin".
#
# Example:
#     do_test ios --some_other_flag //foo:bar_tests
function do_test() {
  do_action test "$@"
}

# Usage: do_coverage <platform> <other options...>
#
# Helper function to invoke `bazel coverage` that applies --verbose_failures and
# log redirection for the test harness, along with any extra arguments that
# were passed in via the `apple_shell_test`'s attribute. The first argument is
# the platform required; the remaining arguments are passed directly to bazel.
#
# Test builds use "test-" as the output directory symlink prefix, so tests
# should expect to find their outputs in "test-bin".
#
# Example:
#     do_coverage ios --some_other_flag //foo:bar_tests
function do_coverage() {
  do_action coverage "$@"
}


# Usage: do_action <action> <platform> <other options...>
#
# Internal helper function to invoke `bazel <action>` that applies
# --verbose_failures and log redirection for the test harness, along with any
# extra arguments that were passed in via the `apple_shell_test`'s attribute.
# The first argument is the action to perform (i.e. `build` or `test`), followed
# by the platform required; the remaining arguments are passed directly to
# bazel.
#
# Test builds use "test-" as the output directory symlink prefix, so tests
# should expect to find their outputs in "test-bin".
#
# Example:
#     do_action build ios --some_other_flag //foo:bar
function do_action() {
  local action="$1"; shift
  local platform="$1"; shift

  local -a bazel_options=(
      "--announce_rc"
      "--symlink_prefix=test-"
      "--verbose_failures"
      # See the comment in rules_swift/tools/worker/BUILD for why this
      # workaround is necessary.
      "--define=RULES_SWIFT_BUILD_DUMMY_WORKER=1"
      # Used so that if there's a single configuration transition, its output
      # directory gets mapped into the bazel-bin symlink.
      "--use_top_level_targets_for_symlinks"
      # Explicitly pass these flags to ensure the external testing infrastructure
      # matches the internal one.
      "--incompatible_merge_genfiles_directory"
      # TODO: Remove this once we can use the late bound coverage attribute
      "--test_env=LCOV_MERGER=/usr/bin/true"
  )

  local bazel_version="$(bazel --version)"
  local bazel_major_version="$(echo "${bazel_version#bazel }" | cut -f1 -d.)"
  if [[ ( "${bazel_major_version}" != "no_version" ) && ( "${bazel_major_version}" -lt 4 ) ]]; then
	bazel_options+=("--incompatible_objc_compile_info_migration")
  fi

  if [[ -n "${XCODE_VERSION_FOR_TESTS-}" ]]; then
    local -a sdk_options=("--xcode_version=$XCODE_VERSION_FOR_TESTS")
    if [ -n "${sdk_options[*]}" ]; then
      bazel_options+=("${sdk_options[@]}")
    else
      fail "Could not find a valid version of Xcode"
    fi
  fi

  if is_device_build "$platform"; then
    bazel_options+=("--ios_signing_cert_name=-")
  fi

  if [[ -n "${EXTRA_BUILD_OPTIONS[@]-}" ]]; then
    bazel_options+=( "${EXTRA_BUILD_OPTIONS[@]}" )
  fi

  bazel_options+=( \
      --objccopt=-Werror --objccopt=-Wunused-command-line-argument \
      --objccopt=-Wno-unused-function --objccopt=-Wno-format \
      --objccopt=-Wno-unused-variable \
       "$@" \
  )

  echo "Executing: bazel ${action} ${bazel_options[*]}" >> "$TEST_log"
  bazel "${action}" "${bazel_options[@]}" >> "$TEST_log" 2>&1
}


# Usage: is_bitcode_build
#
# Returns a success code if the --apple_bitcode flag is set to either
# "embedded" or "embedded_markers"; otherwise, it returns a failure exit code.
function is_bitcode_build() {
  for option in "${EXTRA_BUILD_OPTIONS[@]-}"; do
    case "$option" in
      --apple-bitcode=none)
        return 1
        ;;
      --apple_bitcode=*)
        return 0
        ;;
    esac
  done

  return 1
}


# Usage: is_device_build <platform>
#
# Returns a success exit code if the current architectures correspond to a
# device build, or a failure exit code if they correspond to a simulator build.
# Intended to let individual tests skip all or part of their logic when running
# under multiple configurations.
function is_device_build() {
  local platform="$1"
  local archs="$(current_archs "$platform")"

  # For simplicity, we just test the entire architecture list string and assume
  # users aren't writing tests with multiple incompatible architectures.
  [[ "$platform" == macos ]] || [[ "$archs" == arm* ]]
}


# Usage: print_debug_entitlements <binary_path>
#
# Extracts and prints the debug entitlements from the appropriate Mach-O
# section of the given binary.
function print_debug_entitlements() {
  local binary="$1"

  # This monstrosity uses objdump to dump the hex content of the entitlements
  # section, strips off the leading addresses (and ignores lines that don't
  # look like hex), then runs it through `xxd` to turn the hex into ASCII.
  # The results should be the entitlements plist text, which we can compare
  # against.
  xcrun llvm-objdump -macho -section=__TEXT,__entitlements "$binary" | \
      sed -e 's/^[0-9a-f][0-9a-f]*[[:space:]][[:space:]]*//' \
          -e 'tx' -e 'd' -e ':x' | xxd -r -p
}


# Usage unzip_single_file <archive> <path_in_archive>
#
# Extracts and prints the contents of the file located at `path_in_archive`
# within the given zip `archive`.
function unzip_single_file() {
  local archive="$1"
  local path="$2"
  unzip -p "$archive" "$path" || fail "Unable to find $path in $archive"
}


# Usage: assert_binary_contains <archive> <path_in_archive> <symbol_regexp>
#
# Asserts that the binary at `path_in_archive` within the zip `archive`
# contains the string `symbol_regexp` in its objc runtime.
function assert_binary_contains() {
  local platform="$1"
  local archive="$2"
  local path="$3"
  local symbol_regexp="$4"

  mkdir -p tempdir
  local fat_path="tempdir/fat_binary"
  local thin_path="tempdir/thin_binary"

  unzip_single_file "$archive" "$path" > $fat_path
  local -a archs=( $(current_archs "$platform") )
  for arch in "${archs[@]}"; do
    assert_objdump_contains "$arch" "$fat_path" "$symbol_regexp"
  done
  rm -rf tempdir
}


# Usage: assert_binary_not_contains <archive> <path_in_archive> <symbol_regexp>
#
# Asserts that the binary at `path_in_archive` within the zip `archive`
# does not contain the string `symbol_regexp` in its objc runtime.
function assert_binary_not_contains() {
  local platform="$1"
  local archive="$2"
  local path="$3"
  local symbol_regexp="$4"

  mkdir -p tempdir
  local fat_path="tempdir/fat_binary"
  local thin_path="tempdir/thin_binary"

  unzip_single_file "$archive" "$path" > $fat_path
  local -a archs=( $(current_archs "$platform") )
  for arch in "${archs[@]}"; do
    assert_objdump_not_contains "$arch" "$fat_path" "$symbol_regexp"
  done
  rm -rf tempdir
}

# Usage: assert_objdump_contains <arch> <path> <symbol_regexp>
#
# Uses objdump and asserts that the binary at `path`
# contains the string `symbol_regexp` in its objc runtime.
function assert_objdump_contains() {
  local arch="$1"
  local path="$2"
  local symbol_regexp="$3"

  [[ -f "$path" ]] || fail "$path does not exist"
  local contents=$(objdump -t -macho -arch="$arch" "$path" | grep -v "*UND*")
  echo "$contents" | grep -e "$symbol_regexp" >& /dev/null && return 0
  fail "Expected binary '$path' to contain '$symbol_regexp' but it did not." \
      "contents were: $contents"
}

# Usage: assert_objdump_not_contains <arch> <path> <symbol_regexp>
#
# Uses objdump and asserts that the binary at `path`
# does not contain the string `symbol_regexp` in its objc runtime.
function assert_objdump_not_contains() {
  local arch="$1"
  local path="$2"
  local symbol_regexp="$3"

  [[ -f "$path" ]] || fail "$path does not exist"
  local contents=$(objdump -t -macho -arch="$arch" "$path" | grep -v "*UND*")
  echo "$contents" | grep -e "$symbol_regexp" >& /dev/null || return 0
  fail "Expected binary '$path' to not contain '$symbol_regexp' but it did."  \
      "contents were: $contents"
}

# Usage: assert_contains_bitcode_maps <platform> <archive> <binary_path>
#
# Asserts that the IPA at `archive` contains bitcode symbol map of the binary
# at `path` for each architecture being built for the `platform`.
#
# To support legacy shell tests and newer Starlark tests, this function can take
# the `archive` and `binary_path` arguments in two forms:
#
# - If `archive` is a directory, then `binary_path` is assumed to be the
#   path to the binary relative to `archive`.
# - If `archive` is a file, it is assumed to be an .ipa or .zip archive and
#   `binary_path` is treated as the relative path to the binary inside that
#   archive.
function assert_ipa_contains_bitcode_maps() {
  local platform="$1" ; shift
  local archive_zip_or_dir="$1" ; shift
  local bc_symbol_maps_root="$1" ; shift
  local bc_symbol_maps_dir="${bc_symbol_maps_root}/BCSymbolMaps"

  for binary in "$@" ; do
    if [[ -d "$archive_zip_or_dir" ]] ; then
      assert_exists "$archive_zip_or_dir/$binary"
      ln -s "$archive_zip_or_dir/$binary" "$TEST_TMPDIR"/tmp_bin
    else
      assert_zip_contains "$archive_zip_or_dir" "$binary"
      unzip_single_file "$archive_zip_or_dir" "$binary" > "$TEST_TMPDIR"/tmp_bin
    fi

    # Verify that there is a Bitcode symbol map for each UUID in the DWARF info.
    dwarfdump -u "$TEST_TMPDIR"/tmp_bin | while read line ; do
      local -a uuid_and_arch=(
        $(echo "$line" | sed -e 's/UUID: \([^ ]*\) (\([^)]*\)).*/\1 \2/') )
      local uuid=${uuid_and_arch[0]}

      if [[ -d "$archive_zip_or_dir" ]] ; then
        assert_exists "${archive_zip_or_dir}/${bc_symbol_maps_dir}/${uuid}.bcsymbolmap"
      else
        assert_zip_contains "$archive_zip_or_dir" \
          "${bc_symbol_maps_dir}/${uuid}.bcsymbolmap"
      fi
    done

    rm "$TEST_TMPDIR"/tmp_bin
  done
}

# Usage: assert_plist_is_binary <archive> <path_in_archive>
#
# Asserts that the IPA/zip at `archive` contains a binary plist file at
# `path_in_archive`.
function assert_plist_is_binary() {
  local archive="$1"
  local path_in_archive="$2"

  assert_zip_contains "$archive" "$path_in_archive"
  unzip_single_file "$archive" "$path_in_archive" | \
      grep -sq "^bplist00" || fail "Expected binary file for $path_in_archive"
}

# Usage: assert_strings_is_binary <archive> <path_in_archive>
#
# Asserts that the IPA/zip at `archive` contains a binary strings file at
# `path_in_archive`.
function assert_strings_is_binary() {
  local archive="$1"
  local path_in_archive="$2"
  assert_plist_is_binary "$archive" "$path_in_archive"
}

# Usage: assert_plist_is_text <archive> <path_in_archive>
#
# Asserts that the IPA/zip at `archive` contains a text plist file at
# `path_in_archive`.
function assert_plist_is_text() {
  local archive="$1"
  local path_in_archive="$2"

  assert_zip_contains "$archive" "$path_in_archive"
  unzip_single_file "$archive" "$path_in_archive" | \
      grep -sq "^bplist00" && fail "Expected text file for $path_in_archive" \
      || true
}

# Usage: assert_strings_is_text <archive> <path_in_archive>
#
# Asserts that the IPA/zip at `archive` contains a text strings file at
# `path_in_archive`.
function assert_strings_is_text() {
  local archive="$1"
  local path_in_archive="$2"
  assert_plist_is_text "$archive" "$path_in_archive"
}
