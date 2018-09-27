import argparse
import base64
import json
import os
import plistlib
import re
import subprocess
import sys

def _check_output(args, inputstr=None):
    proc = subprocess.Popen(args,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE)
    return proc.communicate(input=inputstr)[0]


def mobileprovision(mobileprovision_file):
    plist_xml = subprocess.check_output([
        "security", "cms",
        "-D",
        "-i", mobileprovision_file,
    ])
    if hasattr(plistlib, "readPlistFromString"):
        # Python 2
        return plistlib.readPlistFromString(plist_xml)
    else:
        # Python 3
        return plistlib.readPlistFromBytes(plist_xml)


def fingerprint(identity):
    fingerprint = _check_output([
        "openssl", "x509", "-inform", "DER", "-noout", "-fingerprint",
    ], inputstr=identity).strip().decode("utf-8")
    fingerprint = fingerprint.replace("SHA1 Fingerprint=", "")
    fingerprint = fingerprint.replace(":", "")
    return fingerprint


def identities(mpf):
    for identity in mpf["DeveloperCertificates"]:
        yield fingerprint(identity.data)


def identities_codesign():
    ids = []
    output = _check_output([
        "security", "find-identity", "-v", "-p", "codesigning",
    ]).strip().decode("utf-8")
    for line in output.splitlines():
        m = re.search(r"([A-F0-9]{40})", line)
        if m:
            ids.append(m.group(0))
    return ids


def codesign_identity(args):
    if args.identity is not None:
        return args.identity

    mpf = mobileprovision(args.mobileprovision)
    ids_codesign = set(identities_codesign())
    for id_mpf in identities(mpf):
        if id_mpf in ids_codesign:
            return id_mpf

    # If we still don't have an identity, fall back to ad hoc signing.
    return "-"


def main(argv):
    parser = argparse.ArgumentParser(description='codesign wrapper')
    parser.add_argument('--mobileprovision', type=str, help='mobileprovision file')
    parser.add_argument('--codesign', type=str, help='path to codesign binary')
    parser.add_argument('--identity', type=str, help='specific identity to sign with')
    args, codesign_args = parser.parse_known_args()
    identity = codesign_identity(args)
    print("Signing identity: %s" % identity)
    os.execve(args.codesign, [args.codesign, "-v", "--sign", identity] + codesign_args, os.environ)


if __name__ == '__main__':
    sys.exit(main(sys.argv))
