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
"""Tests for preserved_framework_processor."""

from pathlib import Path
import tempfile
import unittest
from unittest import mock

from tools.preserved_framework_processor import preserved_framework_processor


class PreservedFrameworkProcessorTest(unittest.TestCase):
    def _write_file(self, path: Path, contents: str) -> Path:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents, encoding="utf-8")
        return path

    def _make_config(
        self,
        *,
        framework_binary: Path,
        framework_files: list[Path],
        temp_dir: Path,
    ) -> preserved_framework_processor.ProcessorConfig:
        return preserved_framework_processor.ProcessorConfig(
            framework_binary=framework_binary,
            framework_files=tuple(framework_files),
            output_zip=temp_dir / "out.zip",
            temp_path=temp_dir / "out" / "My.framework",
        )

    def _assert_runtime_symlinks(
        self,
        temp_path: Path,
        *,
        version: str,
        framework_name: str,
    ) -> None:
        self.assertTrue((temp_path / "Versions" / version / framework_name).exists())
        self.assertTrue(
            (temp_path / "Versions" / version / "Resources" / "Info.plist").exists()
        )
        self.assertTrue((temp_path / "Versions" / "Current").is_symlink())
        self.assertEqual(
            version, (temp_path / "Versions" / "Current").readlink().as_posix()
        )
        self.assertTrue((temp_path / framework_name).is_symlink())
        self.assertEqual(
            "Versions/Current/My",
            (temp_path / framework_name).readlink().as_posix(),
        )
        self.assertTrue((temp_path / "Resources").is_symlink())
        self.assertEqual(
            "Versions/Current/Resources",
            (temp_path / "Resources").readlink().as_posix(),
        )

    def test_copy_framework_file_preserves_mode(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            framework_dir = temp_path / "My.framework"
            framework_dir.mkdir()
            source = self._write_file(framework_dir / "My", "binary")
            source.chmod(0o755)

            output_dir = temp_path / "output"
            preserved_framework_processor._copy_framework_file(source, output_dir)

            copied_file = output_dir / "My"
            self.assertTrue(copied_file.exists())
            self.assertEqual(0o755, copied_file.stat().st_mode & 0o777)

    @mock.patch.object(
        preserved_framework_processor,
        "_get_framework_version_from_install_path",
    )
    @mock.patch.object(
        preserved_framework_processor,
        "_try_get_framework_version_from_structure",
    )
    def test_copy_versioned_framework_preserves_runtime_symlinks(
        self,
        mock_try_get_version: mock.Mock,
        mock_get_version: mock.Mock,
    ):
        del mock_get_version
        mock_try_get_version.return_value = "A"

        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            framework_dir = temp_path / "My.framework"
            version_dir = framework_dir / "Versions" / "A"
            resources_dir = version_dir / "Resources"
            resources_dir.mkdir(parents=True)
            binary = framework_dir / "My"
            binary_target = self._write_file(version_dir / "My", "binary")
            resources_file = self._write_file(resources_dir / "Info.plist", "plist")
            top_level_resources_file = self._write_file(
                framework_dir / "Resources" / "Info.plist",
                "plist",
            )

            (framework_dir / "Versions" / "Current").symlink_to(version_dir)
            # Source symlinks may be materialized as absolute targets in a Bazel
            # action's execroot, and top-level directories such as Resources may be
            # materialized instead of preserved as symlinks. The preserved bundle
            # should still emit canonical relative framework links.
            binary.symlink_to(binary_target)

            config = self._make_config(
                framework_binary=binary,
                framework_files=[top_level_resources_file, resources_file],
                temp_dir=temp_path,
            )

            preserved_framework_processor._copy_versioned_framework(
                config,
                framework_dir,
                "My",
            )

            self._assert_runtime_symlinks(
                config.temp_path, version="A", framework_name="My"
            )

    def test_copy_versioned_framework_without_current_in_source_structure(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            framework_dir = temp_path / "My.framework"
            version_dir = framework_dir / "Versions" / "A"
            resources_dir = version_dir / "Resources"
            resources_dir.mkdir(parents=True)
            binary = self._write_file(framework_dir / "My", "binary")
            resources_file = self._write_file(resources_dir / "Info.plist", "plist")

            config = self._make_config(
                framework_binary=binary,
                framework_files=[resources_file],
                temp_dir=temp_path,
            )

            preserved_framework_processor._copy_versioned_framework(
                config,
                framework_dir,
                "My",
            )

            self._assert_runtime_symlinks(
                config.temp_path, version="A", framework_name="My"
            )

    def test_update_modified_timestamps_normalizes_symlink_mtime(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            framework_dir = Path(temp_dir) / "My.framework"
            framework_dir.mkdir()
            target = self._write_file(framework_dir / "My", "binary")
            symlink = framework_dir / "Current"
            symlink.symlink_to("My")

            preserved_framework_processor._update_modified_timestamps(framework_dir)

            expected_timestamp = preserved_framework_processor._zip_timestamp()
            self.assertEqual(expected_timestamp, target.stat().st_mtime)
            self.assertEqual(expected_timestamp, symlink.lstat().st_mtime)


if __name__ == "__main__":
    unittest.main()
