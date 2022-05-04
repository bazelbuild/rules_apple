This document outlines the processes we follow to maintain the 4 Apple
rules repos (this doc is not duplicated across the repos):

- [`apple_support`](https://github.com/bazelbuild/apple_support)
- [`rules_apple`](https://github.com/bazelbuild/rules_apple)
- [`rules_swift`](https://github.com/bazelbuild/rules_swift)
- [`Tulsi`](https://github.com/bazelbuild/tulsi)

# Maintainers

The current maintainers can be seen in the [CODEOWNERS](CODEOWNERS)
file.

# Upstream changes

While these rulesets are now maintained outside of Google, Google still
pushes their internal changes to the `upstream` branch on each repo.
This branch is not intended to be relied on directly, and does not
accept contribution, but can be cherry-picked from by the maintainer's
discretion. In general we try to take all upstream changes so that we
diverge less.

## Cherry-pick process

When a new commit is pushed to the `upstream` branch there are a few
things to do.

- Cherry-pick the commit onto the `master` branch with `git cherry-pick -x
  SHA`. Including `-x` makes it easier to trace back to the upstream
  commit.
- Submit a PR with this change.
- Comment on the upstream commit with the link to the PR so it can be.
  traced back in the future.
- Push more commits to the PR if compatibility changes are necessary.
  It's up to your discretion to resolve conflicts in subsequent commits
  or during the cherry pick. Sometimes the former may be preferred if
  there are significant conflicts so that it's easier to review.
- Get a review from a maintainer.
- Merge using the "Rebase and Merge" strategy. This way original
  authorship is maintained.

### Tips

- You can see the upstream commits
  [here](https://github.com/bazelbuild/rules_apple/compare/upstream) and
  know which ones have been cherry picked or not based on whether or not
  they have a comment. This is why it's important to comment on the
  commit after you cherry-pick it.
- You can find RSS feeds for the commits
  [here](https://github.com/bazelbuild/rules_apple/commits/upstream.atom).
- If for some reason a cherry-pick PR cannot be merged because of
  external vs Google compatibility, create a PR or issue that indicates
  when it can be merged in the future.
- If for some reason a commit should never be cherry picked, comment on
  it to indicate why and so it appears triaged for the future.
- When cherry picking multiple tulsi commits, be sure to land the
  version bumps in the same order as they were upstream

# Reviews

In general normal PRs and cherry-pick PRs should receive reviews from
other maintainers before merging.

## Trivial changes

As a maintainer you can use your best judgement if you believe a fix is
trivial enough that it does not need review. This also applies for
merging external contributors changes.

## Significant changes

In general significant changes and new rules should be generally agreed
upon by multiple maintainers. This way we can keep the rules generally
applicable, and maintainable for the long term.

# Releases

Releases should be cut on a relatively regular schedule, often to align
with bazel releases since they often require rules changes for
compatibility, but they can also be cut more frequently as desired. Here
is the recommended process:

- Check that all repos are up to date with cherry picks, and that all
  open cherry-pick PRs have been merged.
- Lightly triage open PRs and issues to make sure that anything that
  should be merged or fixed before the new release has been.
- Compare the current HEAD of the repo with the last release using a
  command such as `git log 0.21.1...HEAD` or [on
  GitHub](https://github.com/bazelbuild/rules_apple/compare/0.21.1...HEAD),
  and collect the most notable user facing commits for the release
  notes.
- Starting with `apple_support` create a new release with this template
  for the notes:

```
- NOTABLE CHANGE 1
- NOTABLE CHANGE 2
- This release is tested with Bazel N.N.N

Please use the release asset from your Bazel WORKSPACE instead of
GitHub's asset to reduce download size and improve reproducibility.

SHA-256 digest: `TBD`
```

- Download the source archive GitHub produced with the release,
  unarchive it, and create a release archive with this command:
  `COPYFILE_DISABLE=1 tar czvf REPO_NAME.RELEASE_VERSION.tar.gz *` (ideally
  this would be scripted in the future and more artifacts would be excluded to
  reduce download size, but this method avoids potentially gitignored artifacts
  in the archives).
- Update the release with the archive, and update the sha256 with the
  output of `shasum -a 256 ARCHIVE`.
- Update the `apple_support` `README.md` with the new version and sha256
  to make it easier for users to copy and paste to their `WORKSPACE`.
- Update the `swift/repositories.bzl` file in `rules_swift` with the new
  `apple_support` release.
- Repeat the steps above to create a release on `rules_swift`.
- Update the `rules_swift` `README.md` with the new version and sha256
  to make it easier for users to copy and paste to their `WORKSPACE`.
- Update the `apple/repositories.bzl` file in `rules_apple` with the new
  `apple_support` and `rules_swift` releases.
- Repeat the steps above to create a release on `rules_apple`.
- Update the `rules_apple` `README.md` with the new version and sha256
  to make it easier for users to copy and paste to their `WORKSPACE`.
- Update the `Tulsi` `WORKSPACE` with the new version of `rules_apple`.

### Notes

- The rules aren't currently following true semantic versioning, but in
  general the minor version should be bumped for most changes, and the
  patch only for very small releases.
- It's highly recommended that rules maintainers track more closely with
  the HEAD of the rules repos than with the releases.
- In general before releasing the HEAD of the rules repos should be
  tested on non-trivial projects, ideally that is mostly covered by the
  point above.
- Not all rules repos will have changes every time you go to create a
  new release, in those cases you can skip those repos and the version
  bumps associated with them.
- Rules repos can be released on a separate cadence if needed, but given
  the current frequency it's best to intentionally do them all at once.
- If we go a long time without a new release of the rules, but while
  still updating bazel versions, you can update the most recent release
  to show that it has been tested with the newer version, rather than
  the repo being entirely inactive.
