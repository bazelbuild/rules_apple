# Copyright 2026 The Bazel Authors. All rights reserved.
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

"""Validates a Siri App Skill SKILL.md and copies it to the output path."""

import re
import shutil
import sys

_NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
_MAX_NAME_LENGTH = 64
_MAX_DESCRIPTION_LENGTH = 1024
_MAX_BODY_LENGTH = 10000


def validate(name, text, path="SKILL.md"):
  """Returns a list of error strings for the skill `name` with contents `text`."""
  if len(name) > _MAX_NAME_LENGTH or not _NAME_RE.match(name):
    return [
        f"{path}: invalid skill name '{name}'. Use 1-{_MAX_NAME_LENGTH} lowercase"
        " letters, digits and single hyphens, not starting or ending with a hyphen."
    ]

  lines = text.split("\n")
  if lines[0].rstrip() != "---":
    return [f"{path}: must start with a '---' delimited frontmatter block."]
  end = next(
      (i for i, line in enumerate(lines[1:], 1) if line.rstrip() == "---"), None
  )
  if end is None:
    return [f"{path}: frontmatter block is not terminated by '---'."]

  fields = {}
  for line in lines[1:end]:
    key, sep, value = line.partition(":")
    if sep and key.strip() not in fields:
      fields[key.strip()] = value.strip()

  errors = []
  if fields.get("name") != name:
    errors.append(
        f"{path}: frontmatter name '{fields.get('name', '')}' must match its"
        f" directory name '{name}'."
    )
  description = fields.get("description", "")
  if not description or len(description) > _MAX_DESCRIPTION_LENGTH:
    errors.append(
        f"{path}: frontmatter description must be non-empty and at most"
        f" {_MAX_DESCRIPTION_LENGTH} characters."
    )
  body = "\n".join(lines[end + 1 :]).strip()
  if len(body) > _MAX_BODY_LENGTH:
    errors.append(
        f"{path}: body is {len(body)} characters; the limit is {_MAX_BODY_LENGTH}."
    )
  return errors


def main(argv):
  if len(argv) != 4:
    print("usage: skills_bundle_validator <input> <output> <skill-name>", file=sys.stderr)
    return 2
  src, out, name = argv[1:]
  with open(src, encoding="utf-8") as f:
    errors = validate(name, f.read(), src)
  if errors:
    print("\n".join("error: " + e for e in errors), file=sys.stderr)
    return 1
  shutil.copyfile(src, out)
  return 0


if __name__ == "__main__":
  sys.exit(main(sys.argv))
