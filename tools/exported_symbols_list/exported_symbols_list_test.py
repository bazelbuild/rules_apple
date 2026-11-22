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

import tempfile
import unittest
from pathlib import Path

from tools.exported_symbols_list.exported_symbols_list import (
    export_report,
    parse_nm_output,
    read_additional_exports,
    select_exports,
)


class ExportedSymbolsListTest(unittest.TestCase):
    def test_export_report_lists_policy_buckets_and_missing_roots(self) -> None:
        self.assertEqual(
            export_report(
                additional_exports={"_dynamic", "_missing"},
                allowlist=["_c_entry", "_dynamic", "_$s4Test4usedyyF"],
                client_imports={"_$s4Test4usedyyF", "_system"},
                client_input_count=2,
                defined_exports={
                    "_c_entry",
                    "_dynamic",
                    "_$s4Test4usedyyF",
                },
                framework_input_count=3,
                non_swift_exports={"_c_entry"},
                preserve_all_non_swift_exports=True,
                statically_used={"_$s4Test4usedyyF"},
            ),
            {
                "additional_export_symbols": ["_dynamic"],
                "additional_exports": 2,
                "allowlist_exports": 3,
                "allowlist_symbols": [
                    "_c_entry",
                    "_dynamic",
                    "_$s4Test4usedyyF",
                ],
                "client_imports": 2,
                "client_inputs": 2,
                "defined_exports": 3,
                "framework_inputs": 3,
                "missing_additional_exports": ["_missing"],
                "non_swift_export_symbols": ["_c_entry"],
                "non_swift_exports": 1,
                "preserve_all_non_swift_exports": True,
                "statically_used_export_symbols": ["_$s4Test4usedyyF"],
                "statically_used_exports": 1,
            },
        )

    def test_parse_nm_output_keeps_only_exportable_external_symbols(self) -> None:
        output = """
_Source.swift.bc:
---------------- (LTO,CODE) weak private external _$s4Test6hiddenyyF
---------------- (LTO,CODE) external [no dead strip] _$s4Test6publicyyF
0000000000000000 (__TEXT,__text) weak external _objc_symbol
                 (undefined) external _$s4Test6clientyyF
"""

        self.assertEqual(
            parse_nm_output(output),
            {
                "_$s4Test6clientyyF",
                "_$s4Test6publicyyF",
                "_objc_symbol",
            },
        )

    def test_parse_nm_output_ignores_headings_and_non_macho_names(self) -> None:
        output = """
_AncestorHashSlots.swift.bc:
archive.a(member.o):
---------------- (LTO,CODE) external symbol_without_macho_prefix
"""

        self.assertEqual(parse_nm_output(output), set())

    def test_select_exports_keeps_client_swift_and_all_non_swift(self) -> None:
        defined_exports = {
            "_$s4Test4usedyyF",
            "_$s4Test12dynamicSwiftyyF",
            "_$s4Test6unusedyyF",
            "_OBJC_CLASS_$_RuntimeDiscoveredType",
            "_c_entry_point",
        }
        client_imports = {
            "_$s4Test4usedyyF",
            "_unrelated_system_import",
        }

        statically_used, non_swift_exports, allowlist = select_exports(
            defined_exports,
            client_imports,
            {
                "_$s4Test12dynamicSwiftyyF",
                "_$s4Test14missingDynamicyyF",
            },
            preserve_all_non_swift_exports=True,
        )

        self.assertEqual(statically_used, {"_$s4Test4usedyyF"})
        self.assertEqual(
            non_swift_exports,
            {
                "_OBJC_CLASS_$_RuntimeDiscoveredType",
                "_c_entry_point",
            },
        )
        self.assertEqual(
            allowlist,
            {
                "_$s4Test4usedyyF",
                "_$s4Test12dynamicSwiftyyF",
                "_OBJC_CLASS_$_RuntimeDiscoveredType",
                "_c_entry_point",
            },
        )

    def test_select_exports_can_omit_unreferenced_non_swift_symbols(self) -> None:
        statically_used, non_swift_exports, allowlist = select_exports(
            {"_$s4Test4usedyyF", "_runtime_discovered"},
            {"_$s4Test4usedyyF"},
            set(),
            preserve_all_non_swift_exports=False,
        )

        self.assertEqual(statically_used, {"_$s4Test4usedyyF"})
        self.assertEqual(non_swift_exports, set())
        self.assertEqual(allowlist, {"_$s4Test4usedyyF"})

    def test_read_additional_exports_ignores_comments_and_blank_lines(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Additional.exp"
            path.write_text(
                "# Runtime lookup roots\n_$s4Test7dynamicyyF\n\n",
                encoding="utf8",
            )

            self.assertEqual(
                read_additional_exports([path]),
                {"_$s4Test7dynamicyyF"},
            )


if __name__ == "__main__":
    unittest.main()
