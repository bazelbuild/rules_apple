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

"""Smart deduplication related methods."""

def _create_owners_mapping(files, owner = None):
    """Creates an owners mapping for the given files with the given owner."""
    owner_depset = None
    if owner:
        owner_depset = depset([owner])
    owners = {}
    for file in files:
        owners[file.short_path] = owner_depset

    return owners

def _merge_owners_mappings(owners_mappings, default_owner = None, validate_all_files_owned = False):
    """Merges a list of owners mappings.

    During the propagation process, some owners mappings might have None values instead of depsets.
    In those cases, default_owner is set as the owner if it's not None.

    Args:
      owners_mappings: List of dictionary owners mappings to merge into one.
      default_owner: If not None, it will replace all the None values present in the
          owners_mappings.
      validate_all_files_owned: Validates that each resource has at least one owner as value.

    Returns:
      An owner mapping with the values merged.
    """
    default_owners_depset = None
    if default_owner:
        default_owners_depset = depset([default_owner])

    merged_owners_mapping = {}
    for owner_mapping in owners_mappings:
        for file_path, current_owners_depset in owner_mapping.items():
            owners_depset = merged_owners_mapping.get(file_path)
            transitive = []
            if owners_depset:
                transitive.append(owners_depset)

            # If there is no owner marked for this resource, use the default_owner as an owner, if
            # it exists.
            if current_owners_depset:
                transitive.append(current_owners_depset)
            elif default_owners_depset:
                transitive.append(default_owners_depset)
            elif validate_all_files_owned:
                fail(
                    "The given mapping has a file that doesn't have an owner, and " +
                    "validate_all_resources_owned was set. This is most likely a bug in " +
                    "rules_apple, please file a bug with reproduction steps.",
                )

            if transitive:
                # If there is only one transitive depset, avoid creating a new depset, just
                # propagate it.
                if len(transitive) == 1:
                    merged_depset = transitive[0]
                else:
                    merged_depset = depset(transitive = transitive)
            else:
                merged_depset = None
            merged_owners_mapping[file_path] = merged_depset
    return merged_owners_mapping

def _subtract_owners_mappings(minuend, subtrahend):
    """For each key in minuend, subtracts all the owners in subtrahend under the same key."""
    result = {}
    for file_path, owners in minuend.items():
        deduped_owners = [
            o
            for o in owners
            if file_path not in subtrahend or o not in subtrahend[file_path]
        ]
        if deduped_owners:
            result[file_path] = depset(deduped_owners)
    return result

def _write_debug_file(owners_mapping, avoided_owners_mapping, actions, output_file):
    """Writes a debug file describing the changes that smart deduplication performed.

    This method writes a file describing which files were removed from or added to the bundle
    because of smart deduplication. This file can be used in aiding debugging when the bundling
    result is not expected.

    The files listed in the debug file are the raw resources that will be processed, not the files
    that will be bundled inside the application. This makes it more apparent which xcassets will be
    bundled inside the Assets.car file.

    Args:
      owners_mapping: The owners mapping of a target's bundle.
      avoided_owners_mapping: The owners mapping describing dependency bundles.
      actions: The actions object as returned by ctx.actions.
      output_file: The File reference on where to write the file.
    """
    legacy_deduped = [x for x in owners_mapping.keys() if x not in avoided_owners_mapping.keys()]
    smart_deduped = _subtract_owners_mappings(owners_mapping, avoided_owners_mapping).keys()

    removed_by_smart_dedupe = sorted([x for x in legacy_deduped if x not in smart_deduped])
    added_by_smart_dedupe = sorted([x for x in smart_deduped if x not in legacy_deduped])

    contents = []
    if removed_by_smart_dedupe:
        contents.extend(["REMOVED", ""])
        contents.extend(removed_by_smart_dedupe)
        contents.append("")
    if added_by_smart_dedupe:
        contents.extend(["ADDED", ""])
        contents.extend(added_by_smart_dedupe)
        contents.append("")

    if not contents:
        contents.append("NO CHANGES")

    actions.write(output_file, "\n".join(contents))

smart_dedupe = struct(
    create_owners_mapping = _create_owners_mapping,
    merge_owners_mappings = _merge_owners_mappings,
    subtract_owners_mappings = _subtract_owners_mappings,
    write_debug_file = _write_debug_file,
)
