# How to Contribute

We'd love to accept your patches and contributions to this project. There are
just a few small guidelines you need to follow.

## Formatting

Starlark files should be formatted by buildifier.
We suggest using a pre-commit hook to automate this.
First [install pre-commit](https://pre-commit.com/#installation),
then run

```shell
pre-commit install
```

Otherwise the Buildkite CI will yell at you about formatting/linting violations.

## File or claim an issue

Please let us know what you're working on if you want to change or add to the
project. Before undertaking something, please file an issue or claim an existing
issue.

All significant changes/additions should also be discussed before they can be
accepted. This gives all participants a chance to validate the design and to
avoid duplication of effort. Ensuring that there is an issue for discussion
before working on a PR helps everyone provide input/discussion/advice and
avoid a PR having to get restarted based on useful feedback.

We use [labels](https://github.com/bazelbuild/rules_apple/labels) for the
issues and pull requests to help track priorities, things being considered,
deferred, etc. A project owner will try to update labels every week or so, as
workloads permit.

## Contributor License Agreement

Contributions to this project must be accompanied by a Contributor License
Agreement. You (or your employer) retain the copyright to your contribution;
this simply gives us permission to use and redistribute your contributions as
part of the project. Head over to <https://cla.developers.google.com/> to see
your current agreements on file or to sign a new one.

You generally only need to submit a CLA once, so if you've already submitted one
(even if it was for a different project), you probably don't need to do it
again.

## Setting up your development environment

To enforce a consistent code style through our code base, we use `buildifier`
from the [bazelbuild/buildtools](https://github.com/bazelbuild/buildtools) to
format `BUILD` and `*.bzl` files. We also use `buildifier --lint=warn` to check
for common issues.

You can download `buildifier` from
[bazelbuild/buildtools Releases Page](https://github.com/bazelbuild/buildtools/releases).

Bazel's CI is configured to ensure that files in pull requests are formatted
correctly and that there are no lint issues.

## Code reviews

All submissions, including submissions by project members, require review. We
use GitHub pull requests for this purpose. Consult
[GitHub Help](https://help.github.com/articles/about-pull-requests/) for more
information on using pull requests.

## Community Guidelines

This project follows [Google's Open Source Community
Guidelines](https://opensource.google.com/conduct/).
