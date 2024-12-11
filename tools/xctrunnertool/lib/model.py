#!/usr/bin/env python3

from dataclasses import dataclass
from typing import List
import os


@dataclass
class Configuration:
    "Configuration for the generator"
    name: str
    xctests: List[str]
    platform: str
    output: str
    xcode_path: str
    xctrunner_name: str = "XCTRunner"
    xctrunner_app = "XCTRunner.app"
    tmp_output: str = ""
    developer_dir: str = ""
    libraries_dir: str = ""
    frameworks_dir: str = ""
    private_frameworks_dir: str = ""
    dylib_dir: str = ""
    xctrunner_app_name: str = ""
    xctrunner_path: str = ""
    xctrunner_template_path: str = ""
    xctrunner_bundle_identifier: str = ""
    xctrunner_info_plist_path: str = ""

    def __post_init__(self):
        self.developer_dir = f"{self.xcode_path}/Platforms/{self.platform}/Developer"
        self.libraries_dir = f"{self.developer_dir}/Library"
        self.frameworks_dir = f"{self.libraries_dir}/Frameworks"
        self.private_frameworks_dir = f"{self.libraries_dir}/PrivateFrameworks"
        self.dylib_dir = f"{self.developer_dir}/usr/lib"
        self.xctrunner_template_path = (
            f"{self.libraries_dir}/Xcode/Agents/XCTRunner.app"
        )
        self.xctrunner_bundle_identifier = f"com.apple.test.{self.xctrunner_name}"
        self.xctrunner_info_plist_path = f"{self.output}/Info.plist"
