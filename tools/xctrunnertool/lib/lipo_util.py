#!/usr/bin/env python3

import shutil
from lib.shell import shell
import logging


class LipoUtil:
    "Lipo utility class."

    def __init__(self):
        self.lipo_path = shutil.which("lipo")
        self.log = logging.getLogger(__name__)

    def has_arch(self, bin_path: str, arch: str) -> bool:
        "Returns True if the given binary has the given arch."
        cmd = f"{self.lipo_path} -info {bin_path}"
        output = shell(cmd, check_status=False)

        return arch in output

    def remove_arch(self, bin_path: str, arch: str):
        "Removes the given arch from the binary."
        if self.has_arch(bin_path, arch):
            cmd = f"{self.lipo_path} {bin_path} -remove {arch} -output {bin_path}"
            shell(cmd)
