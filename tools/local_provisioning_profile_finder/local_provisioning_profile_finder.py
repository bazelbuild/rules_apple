import argparse
import datetime
import plistlib
import shutil
import subprocess
import sys
import os
from typing import List, Optional, Tuple
from tempfile import mkstemp


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("name", help="The name (or UUID) of the profile to find")
    parser.add_argument("output", help="The path to copy the profile to")
    parser.add_argument(
        "--local_profiles",
        nargs="*",
        help="All local provisioning profiles to search through",
    )
    parser.add_argument(
        "--fallback_profiles",
        nargs="*",
        help="Fallback provisioning profiles to use if not found locally",
    )
    parser.add_argument(
        "--team_id",
        help="The team ID of the profile to find, useful for disambiguation",
        default=None,
        type=str,
    )
    return parser


def _profile_contents(profile: str, keychain_file: str) -> Tuple[str, datetime.datetime, str]:
    output = subprocess.check_output(["security", "cms", "-D", "-k", keychain_file, "-i", profile])
    plist = plistlib.loads(output)
    return plist["Name"], plist["UUID"], plist["CreationDate"], plist["TeamIdentifier"][0]


def _find_newest_profile(
    expected_specifier: str, team_id: Optional[str], profiles: List[str]
) -> Optional[str]:
    newest_path: Optional[str] = None
    newest_date: Optional[datetime.datetime] = None
     # set up a temporary keychain path
    keychain_file = mkstemp(prefix="local-profile-keychain-")[1]
    os.remove(keychain_file)
    try:
        subprocess.check_call(["security", "create-keychain", "-p", "", keychain_file])
    except Exception as exp:
        raise subprocess.CalledProcessError("Error creating temporary keychain at path %s: %s" % (keychain_file, exp))

    for profile in profiles:
        profile_name, profile_uuid, creation_date, actual_team_id = _profile_contents(profile, keychain_file)
        if profile_name != expected_specifier and profile_uuid != expected_specifier:
            continue
        if team_id and team_id != actual_team_id:
            continue
        # TODO: Skip expired profiles
        if not newest_date or creation_date > newest_date:
            newest_path = profile
            newest_date = creation_date

    os.remove(keychain_file)
    return newest_path


def _find_profile(
    name: str,
    team_id: Optional[str],
    output: str,
    local_profiles: List[str],
    fallback_profiles: List[str],
) -> None:
    profile = _find_newest_profile(
        name, team_id, local_profiles + fallback_profiles
    )
    if not profile:
        sys.exit(
            f"\033[31merror:\033[39m no provisioning profile was found named '{name}'"
        )

    shutil.copyfile(profile, output)


if __name__ == "__main__":
    args = _build_parser().parse_args()
    _find_profile(
        args.name,
        args.team_id,
        args.output,
        args.local_profiles or [],
        args.fallback_profiles or [],
    )
