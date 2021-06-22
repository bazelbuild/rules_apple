#!/usr/bin/env python

"""Very basic python script that takes a JSON dict from stdin,
and print all leafs"""

import sys
import json

def print_values(d):
    if isinstance(d, dict):
        for k, v in d.items():
            print_values(v)
    else:
        print(d)

if __name__ == "__main__":
    stdin = json.load(sys.stdin)
    print_values(stdin)