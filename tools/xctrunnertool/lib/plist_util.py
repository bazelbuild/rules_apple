#!/usr/bin/env python3

import plistlib


class PlistUtil:
    """Plist utility class."""

    def __init__(self, plist_path):
        self.plist_path = plist_path
        with open(plist_path, "rb") as content:
            self.plist = plistlib.load(content)

    def update(self, key, value):
        "Updates given plist key with given value."
        self.plist[key] = value
        plistlib.dump(self.plist, open(self.plist_path, "wb"))
