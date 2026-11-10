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

import unittest

from tools.skills_bundle_validator import skills_bundle_validator as v


def _skill(name="flight-add", description="Adds a flight.", body="Do things."):
  return f"---\nname: {name}\ndescription: {description}\n---\n{body}\n"


class SkillsBundleValidatorTest(unittest.TestCase):

  def test_valid_skill(self):
    self.assertEqual(v.validate("flight-add", _skill()), [])

  def test_invalid_names(self):
    for name in ["Flight", "-a", "a-", "a--b", "a_b", "", "a" * 65]:
      with self.subTest(name=name):
        self.assertTrue(v.validate(name, _skill(name=name)))

  def test_name_must_match_directory(self):
    errors = v.validate("flight-add", _skill(name="other"))
    self.assertIn("must match its directory name", errors[0])

  def test_missing_frontmatter(self):
    self.assertTrue(v.validate("flight-add", "just a body\n"))

  def test_unterminated_frontmatter(self):
    self.assertTrue(v.validate("flight-add", "---\nname: flight-add\n"))

  def test_description_required_and_bounded(self):
    self.assertTrue(v.validate("flight-add", _skill(description="")))
    self.assertTrue(v.validate("flight-add", _skill(description="x" * 1025)))
    self.assertEqual(v.validate("flight-add", _skill(description="x" * 1024)), [])

  def test_body_limit(self):
    self.assertEqual(v.validate("flight-add", _skill(body="x" * 10000)), [])
    self.assertTrue(v.validate("flight-add", _skill(body="x" * 10001)))


if __name__ == "__main__":
  unittest.main()
