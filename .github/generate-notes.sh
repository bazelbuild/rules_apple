#!/bin/bash

set -euo pipefail

readonly new_version=$1
readonly release_archive="rules_apple.$new_version.tar.gz"

sha=$(shasum -a 256 "$release_archive" | cut -d " " -f1)

cat <<EOF
## What's Changed

TODO

This release is compatible with: TODO

### MODULE.bazel Snippet

\`\`\`bzl
bazel_dep(name = "rules_apple", version = "$new_version", repo_name = "build_bazel_rules_apple")
\`\`\`

### Workspace Snippet

\`\`\`bzl
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "build_bazel_rules_apple",
    sha256 = "$sha",
    url = "https://github.com/bazelbuild/rules_apple/releases/download/$new_version/rules_apple.$new_version.tar.gz",
)

load(
    "@build_bazel_rules_apple//apple:repositories.bzl",
    "apple_rules_dependencies",
)

apple_rules_dependencies()

load(
    "@build_bazel_rules_swift//swift:repositories.bzl",
    "swift_rules_dependencies",
)

swift_rules_dependencies()

load(
    "@build_bazel_rules_swift//swift:extras.bzl",
    "swift_rules_extra_dependencies",
)

swift_rules_extra_dependencies()

load(
    "@build_bazel_apple_support//lib:repositories.bzl",
    "apple_support_dependencies",
)

apple_support_dependencies()
\`\`\`
EOF
