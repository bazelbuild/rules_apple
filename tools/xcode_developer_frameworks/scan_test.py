from pathlib import Path
import tempfile
import unittest

from tools.xcode_developer_frameworks import scan


class ScanTest(unittest.TestCase):

    def test_discover_frameworks_returns_sorted_framework_names(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            frameworks_dir = Path(tmp)
            (frameworks_dir / "XcodeKit.framework").mkdir()
            (frameworks_dir / "Python3.framework").mkdir()
            (frameworks_dir / "README.txt").write_text("ignore me")

            self.assertEqual(
                scan.discover_frameworks(frameworks_dir),
                ["Python3", "XcodeKit"],
            )

    def test_render_build_generates_developer_framework_import_targets(self) -> None:
        rendered = scan.render_build(["XcodeKit"])

        self.assertIn(
            'load("@rules_apple//apple:apple.bzl", "xcode_developer_framework_import")',
            rendered,
        )
        self.assertIn("xcode_developer_framework_import(", rendered)
        self.assertIn('name = "XcodeKit"', rendered)
        self.assertIn('framework_name = "XcodeKit"', rendered)
        self.assertIn('"XcodeKit.framework/**"', rendered)
        self.assertIn('"XcodeKit.framework.dSYM/**"', rendered)
        self.assertIn('name = "XcodeKit_framework_files"', rendered)
        self.assertIn('framework_imports = [":XcodeKit_framework_files"]', rendered)
        self.assertIn('"usr/lib/**"', rendered)

    def test_render_build_does_not_set_linker_imports_attribute(self) -> None:
        # Companion-archive wiring is a per-consumer concern. The generated
        # target stays minimal; consumers wrap it with their own
        # xcode_developer_framework_import that sets `linker_imports`.
        rendered = scan.render_build(["XcodeKit", "Python3"])
        self.assertNotIn("linker_imports =", rendered)

    def test_discover_usr_lib_files_returns_sorted_relative_paths(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            usr_lib_dir = Path(tmp)
            (usr_lib_dir / "libXcodeExtension.a").write_text("")
            (usr_lib_dir / "libAppleTextureConverter.a").write_text("")
            (usr_lib_dir / "nested").mkdir()
            (usr_lib_dir / "nested" / "libFoo.a").write_text("")

            self.assertEqual(
                scan.discover_usr_lib_files(usr_lib_dir),
                [
                    "usr/lib/libAppleTextureConverter.a",
                    "usr/lib/libXcodeExtension.a",
                    "usr/lib/nested/libFoo.a",
                ],
            )

    def test_discover_usr_lib_files_returns_empty_when_missing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(
                scan.discover_usr_lib_files(Path(tmp) / "absent"),
                [],
            )


if __name__ == "__main__":
    unittest.main()
