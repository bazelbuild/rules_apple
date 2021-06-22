#!/usr/bin/env python

import os.path
import json
import sys

def handle_directory_output(payload):
    if 'directoryOutput' not in payload.get('completed', {}):
        return
    obj = payload['completed']['directoryOutput'][0]
    print(os.path.join(*(obj['pathPrefix'] + [obj['name']])))

def handle_swiftmodule(payload):
    if payload.get('action', {}).get('type', '') == "SwiftCompile":
        module = payload['action']['primaryOutput']['uri']
        if not module.endswith('.swiftmodule'):
            return
        if module.startswith('file://'):
            print(module[7:])

def handle_indexstore(payload):
    if payload.get('action', {}).get('type', '') == "SwiftCompile":
        idxstore = [f for f in payload['action']['commandLine'] if f.endswith(".indexstore")]
        if len(idxstore) > 0:
            print(idxstore[0])

def main(action, file):
    with open(file) as bep_json_file:
        for line in bep_json_file:
            ev = json.loads(line)
            if action == "directory_output":
                handle_directory_output(ev)
            elif action == "swiftmodule":
                handle_swiftmodule(ev)
            elif action == "indexstore":
                handle_indexstore(ev)

if __name__ == "__main__":
    action, file = sys.argv[1], sys.argv[2]
    main(action, file)