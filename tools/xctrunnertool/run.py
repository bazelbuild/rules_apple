#!/usr/bin/env python3

import argparse
import sys
import shutil
import os

from lib.logger import Logger
from lib.shell import shell, chmod, cp, cp_r
from lib.model import Configuration
from lib.plist_util import PlistUtil
from lib.lipo_util import LipoUtil
from lib.dependencies import FRAMEWORK_DEPS, PRIVATE_FRAMEWORK_DEPS, DYLIB_DEPS


class DefaultHelpParser(argparse.ArgumentParser):
    """Argument parser error."""

    def error(self, message):
        sys.stderr.write(f"error: {message}\n")
        self.print_help()
        sys.exit(2)


def main(argv) -> None:
    "Script entrypoint."
    parser = DefaultHelpParser()
    parser.add_argument(
        "--name",
        required=True,
        help="Bundle name for the merged test bundle",
    )
    parser.add_argument(
        "--xctest",
        required=True,
        action="append",
        help="Path to xctest archive to merge",
    )
    parser.add_argument(
        "--platform",
        default="iPhoneOS.platform",
        help="Runtime platform. Default is iPhoneOS.platform",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Output path for merged test bundle.",
    )
    args = parser.parse_args()

    # Generator configuration
    xcode_path = shell("xcode-select -p").strip()
    config = Configuration(
        name=args.name,
        xctests=args.xctest,
        platform=args.platform,
        output=args.output,
        xcode_path=xcode_path,
    )

    # Shared logger
    log = Logger("make_xctrunner.log").get(__name__)

    # Log configuration
    log.info("Bundle: %s", config.name)
    log.info("Runner: %s", config.xctrunner_app)
    xctest_names = ", ".join([os.path.basename(x) for x in config.xctests])
    log.info("XCTests: %s", xctest_names)
    log.info("Platform: %s", config.platform)
    log.info("Output: %s", config.output)
    log.info("Xcode: %s", config.xcode_path)

    # copy XCTRunner.app template
    log.info("Copying XCTRunner.app template to %s", config.output)
    chmod(config.output)  # open up for writing
    shutil.rmtree(config.output, ignore_errors=True)  # clean up any existing bundle
    cp_r(config.xctrunner_template_path, config.output)

    # XCTRunner is multi-archs. When launching XCTRunner on arm64e device, it
    # will be launched as arm64e process by default. If the test bundle is arm64e
    # bundle, the XCTRunner which hosts the test bundle will fail to be
    # launched. So removing the arm64e arch from XCTRunner can resolve this
    # case.
    lipo = LipoUtil()
    lipo.remove_arch(bin_path=f"{config.output}/{config.xctrunner_name}", arch="arm64e")

    # Create PlugIns and Frameworks directories
    os.makedirs(f"{config.output}/PlugIns", exist_ok=True)
    os.makedirs(f"{config.output}/Frameworks", exist_ok=True)

    # Move each xctest bundle into PlugIns directory
    for xctest in config.xctests:
        name = os.path.basename(xctest)
        log.info(
            "Copying xctest '%s' to %s",
            xctest,
            f"{config.output}/PlugIns/{name}",
        )
        cp_r(xctest, f"{config.output}/PlugIns/{name}")

    # Update Info.plist with bundle info
    plist = PlistUtil(plist_path=config.xctrunner_info_plist_path)
    plist.update("CFBundleName", config.xctrunner_name)
    plist.update("CFBundleExecutable", config.xctrunner_name)
    plist.update("CFBundleIdentifier", config.xctrunner_bundle_identifier)

    # Copy dependencies to the bundle and remove unwanted architectures
    for framework in FRAMEWORK_DEPS:
        log.info("Bundling fwk: %s", framework)
        fwk_path = f"{config.frameworks_dir}/{framework}"

        # Older Xcode versions may not have some of the frameworks
        if not os.path.exists(fwk_path):
            log.warning("Framework '%s' not available at %s", framework, fwk_path)
            continue

        cp_r(
            fwk_path,
            f"{config.output}/Frameworks/{framework}",
        )  # copy to the bundle
        fwk_binary = framework.replace(".framework", "")
        bin_path = f"{config.output}/Frameworks/{framework}/{fwk_binary}"
        lipo.remove_arch(bin_path, "arm64e")

    for framework in PRIVATE_FRAMEWORK_DEPS:
        log.info("Bundling fwk: %s", framework)
        cp_r(
            f"{config.private_frameworks_dir}/{framework}",
            f"{config.output}/Frameworks/{framework}",
        )
        fwk_binary = framework.replace(".framework", "")
        bin_path = f"{config.output}/Frameworks/{framework}/{fwk_binary}"
        lipo.remove_arch(bin_path, "arm64e")

    for dylib in DYLIB_DEPS:
        log.info("Bundling dylib: %s", dylib)
        cp(
            f"{config.dylib_dir}/{dylib}",
            f"{config.output}/Frameworks/{dylib}",
        )
        lipo.remove_arch(f"{config.output}/Frameworks/{dylib}", "arm64e")

    chmod(config.output)  # full access to final bundle
    log.info("Bundle: %s", config.output)

    # need to copy the template to the root of the main bundle as well
    cp_r(
        config.xctrunner_template_path,
        f"{config.output}/{config.xctrunner_app}/",
    )
    chmod(f"{config.output}/")  # full access to final bundle

    # Zip the bundle as <name>.app.zip
    # log.info("Zipping the bundle...")
    # shutil.make_archive(
    #     f"{config.output_dir}/{config.name}.app",
    #     "zip",
    #     config.output_dir,
    #     config.xctrunner_app,
    # )

    # Move the zip to the user given output path
    shutil.move(
        config.output,
        config.output,
    )
    log.info("Output: %s", f"{config.output}")

    log.info("Done.")


if __name__ == "__main__":
    main(sys.argv[1:])
