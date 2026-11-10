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

"""Implementation of apple_skills_bundle rule."""

load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "//apple/internal:providers.bzl",
    "new_appleresourcebundleinfo",
)
load(
    "//apple/internal:resources.bzl",
    "resources",
)

_BUNDLE_DIR = "Skills.skillsbundle"

def _apple_skills_bundle_impl(ctx):
    """Implementation of the apple_skills_bundle rule."""
    outputs = []
    seen = {}
    for src in ctx.files.skills:
        if src.basename != "SKILL.md":
            fail("%s: skill files must be named SKILL.md." % src.short_path)
        name = src.dirname.rpartition("/")[2]
        if name in seen:
            fail("Duplicate skill name '%s': %s and %s." % (name, seen[name], src.short_path))
        seen[name] = src.short_path

        out = ctx.actions.declare_file(
            "%s/%s/Skills/%s/SKILL.md" % (ctx.label.name, _BUNDLE_DIR, name),
        )
        ctx.actions.run(
            executable = ctx.executable._validator,
            inputs = [src],
            outputs = [out],
            arguments = [src.path, out.path, name],
            mnemonic = "AppleSkillsBundle",
            progress_message = "Validating app skill %s" % name,
        )
        outputs.append(out)

    parent_dir_param = partial.make(
        resources.bundle_relative_parent_dir,
        extension = "skillsbundle",
    )
    return [
        new_appleresourcebundleinfo(),
        resources.bucketize_typed(
            outputs,
            bucket_type = "unprocessed",
            parent_dir_param = parent_dir_param,
        ),
    ]

apple_skills_bundle = rule(
    implementation = _apple_skills_bundle_impl,
    attrs = {
        "_validator": attr.label(
            cfg = "exec",
            executable = True,
            default = Label("//tools/skills_bundle_validator"),
        ),
        "skills": attr.label_list(
            allow_empty = False,
            allow_files = [".md"],
            mandatory = True,
            doc = """
The `SKILL.md` files for the app skills. Each file must be named `SKILL.md` and live in a directory
named after the skill (1-64 lowercase letters, digits and hyphens), e.g. `skills/flight-add/SKILL.md`.
""",
        ),
    },
    doc = """
Packages Siri App Skills (https://developer.apple.com/documentation/appintents/orchestrating-complex-actions-with-app-skills)
into a `Skills.skillsbundle` directory in the top-level bundle. Each `SKILL.md` is validated for its
`name` and `description` frontmatter and the body size limit. Add the target to `resources` or
`deps` of an application, extension or framework target.
""",
)
