#!/usr/bin/env python3

import logging
import subprocess
import os
import shutil


def shell(command: str, check_status: bool = True) -> str:
    "Runs given shell command and returns stdout output."
    log = logging.getLogger(__name__)
    try:
        log.debug("Running shell command: %s", command)
        output = subprocess.run(command, shell=True, check=check_status, capture_output=True).stdout
        return output.decode("utf-8").strip()
    except subprocess.CalledProcessError as e:
        log.error("Shell command failed: %s", e)
        raise e


def chmod(path, mode=0o777):
    "Sets path permission recursively."
    for dirpath, _, filenames in os.walk(path):
        os.chmod(dirpath, mode)
        for filename in filenames:
            os.chmod(os.path.join(dirpath, filename), mode)


def cp_r(src, dst):
    "Copies src recursively to dst and chmod with full access."
    os.makedirs(dst, exist_ok=True)  # create dst if it doesn't exist
    chmod(dst)  # pessimistically open up for writing
    shutil.copytree(src, dst, dirs_exist_ok=True)
    chmod(dst)  # full access to the copied files


def cp(src, dst):
    "Copies src file to dst and chmod with full access."
    chmod(dst)  # pessimistically open up for writing
    shutil.copy(src, dst)
    chmod(dst)  # full access to the copied files
