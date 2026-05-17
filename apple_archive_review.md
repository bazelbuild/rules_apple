# apple_archive Pre-Review Notes

These are the issues I would address before asking maintainers for review.

## Findings

### Medium: apple_archive accepts unsupported bundle shapes too silently

The `apple_archive` rule accepts any target that provides `AppleBundleInfo`. The implementation then packages immediately without checking whether the wrapped bundle is an application-like product or whether its archive is a directory.

For a packaging-only rule this broad provider requirement is convenient, but it also means unsupported bundles can produce malformed archives instead of failing clearly. This is especially relevant while some application targets, such as direct watchOS applications, can still produce zipped archives.

Suggested fix:

- Fail early when `bundle_info.archive.is_directory` is false.
- Optionally restrict accepted product/platform tuples to the specific application products that `apple_archive` is meant to package.

### Medium/Low: archive test helper does not understand watchOS or visionOS Payload roots

`test/starlark_tests/rules/apple_verification_test.bzl` currently treats only iOS and tvOS application archives as having a `Payload/<bundle>.app` root when the archive is not a directory.

`apple_archive` packages every non-macOS application archive under `Payload`, so direct watchOS or visionOS archive content tests would compute the wrong `BUNDLE_ROOT`.

Suggested fix:

- Update the helper to treat all non-macOS application archives produced by `apple_archive` as Payload-rooted.
- Add direct watchOS and visionOS `apple_archive` coverage if those platforms are intended to be supported.

### Low: two watchOS fixture bundle_name changes look accidental

Two watchOS test fixture `bundle_name` changes look unrelated to the `apple_archive` migration:

- `ios_with_swift_watchos_no_swift` changed from `companion` to `ios_with_swift_watchos_no_swift`.
- `ios_no_swift_watchos_with_swift` changed from `companion` to `ios_no_swift_watchos_with_swift`.

A third nearby fixture still uses `bundle_name = "companion"`. Since the tests use `$BUNDLE_ROOT`, these changes do not look necessary for keeping IPA/ZIP tests working and they alter the generated app bundle name inside the archive.

Suggested fix:

- Revert these `bundle_name` changes unless there was an intentional collision or fixture-name reason.

### Low: generated apple_archive docs file is executable

`doc/rules-apple_archive.md` was added with mode `100755`. That looks accidental for generated Markdown documentation.

Suggested fix:

- Change the file mode to `100644`.

### Low: BundleSymlinkError is not caught by the bundletool CLI wrapper

`tools/bundletool/bundletool.py` defines and raises `BundleSymlinkError`, but `_main` only catches `BundleConflictError`.

The unit tests cover the exception directly, but malformed symlink input through the CLI would get a Python traceback instead of the clean `ERROR:` path used for bundle conflicts.

Suggested fix:

- Catch `BundleSymlinkError` alongside `BundleConflictError` in `_main`.
- Add a CLI-level test if that behavior is important.

## Open Questions

- Should `ios_app_clip` also be forced to tree artifact mode and/or supported by `apple_archive`? It still outputs `.ipa` today.
- Should the generated docs mention visionOS explicitly? The implementation returns `.ipa` for all non-macOS platforms, but the current rule documentation focuses on iOS, tvOS, and watchOS.

## Validation Run

All of the following passed:

- `bazel test //tools/bundletool:bundletool_test`
- `bazel test //tools/imported_dynamic_framework_processor:imported_dynamic_framework_processor_test`
- `bazel test //tools/dossier_codesigningtool:dossier_codesigning_reader_test --test_output=errors`
- `bazel build //test/starlark_tests/targets_under_test/ios:ipa_with_app //test/starlark_tests/targets_under_test/macos:app_zip //test/starlark_tests/targets_under_test/watchos:ipa_ios_with_swift_watchos_with_swift --apple_generate_dsym --objc_generate_linkmap`
- `bazel build //test/starlark_tests/targets_under_test/watchos:single_target_app //test/starlark_tests/targets_under_test/watchos:app --apple_generate_dsym --objc_generate_linkmap`
- `bazel test //doc:check_apple_archive`
- Targeted Starlark tests around iOS IPA output, macOS archive output, watchOS Swift support, output groups, dossiers, dSYMs, linkmaps, and Apple symbols files.
- `buildifier -mode=check` over changed `BUILD` and `.bzl` files.

## Overall Read

The overall direction looks coherent. The provider extraction for symbols, SwiftSupport, WatchKit support, Messages support, dSYMs, linkmaps, and dossiers appears aligned with moving archive packaging out of the application rules.

The main gaps are direct watchOS behavior, early validation in `apple_archive`, and a few test/doc cleanup items that look accidental or incomplete.
