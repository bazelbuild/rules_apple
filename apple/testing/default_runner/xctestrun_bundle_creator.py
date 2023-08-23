#!/usr/bin/python3

import argparse
import json
import random
import string
import subprocess
import sys
import time
from typing import List, Optional


def _main(xctestrun_template: str, xctrunner_entitlements_template: str) -> None:
    None


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--xctestrun-template",
        required=True,
        help="The path to the xctestrun template to use",
    )
    parser.add_argument(
        "--xctrunner-entitlements-template",
        required=True,
        help="The path to the xctrunner entitlements template to use",
    )
    return parser


if __name__ == "__main__":
    args = _build_parser().parse_args()
    _main(args.xctestrun_template, args.xctrunner_entitlements_template)
