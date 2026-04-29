import argparse
import datetime
import json
import plistlib
import shutil
import subprocess
import sys
from typing import List, Optional, Tuple

_USE_SECURITY = sys.platform == "darwin"

def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "name", nargs="?", help="The name (or UUID) of the profile to find"
    )
    parser.add_argument("output", nargs="?", help="The path to copy the profile to")
    parser.add_argument(
        "--control",
        help="Path to a JSON control file with the profile search parameters",
    )
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


def _args_from_control(control: str) -> argparse.Namespace:
    with open(control) as control_file:
        control_data = json.load(control_file)
    return argparse.Namespace(
        name=control_data["name"],
        output=control_data["output"],
        local_profiles=control_data.get("local_profiles", []),
        fallback_profiles=control_data.get("fallback_profiles", []),
        team_id=control_data.get("team_id"),
    )


def _profile_contents(profile: str) -> Tuple[str, datetime.datetime, str]:
    if _USE_SECURITY:
        output = subprocess.check_output(
            ["security", "cms", "-D", "-i", profile],
        )
    else:
        # We call it this way to silence the "Verification successful" message
        # for the non-error case
        try:
            output = subprocess.run(
                ["openssl", "smime", "-inform", "der", "-verify", "-noverify", "-in", profile],
                check=True,
                stderr=subprocess.PIPE,
                stdout=subprocess.PIPE,
            ).stdout
        except subprocess.CalledProcessError as e:
            print(e.stderr, file=sys.stderr)
            raise e
    plist = plistlib.loads(output)
    return plist["Name"], plist["UUID"], plist["CreationDate"], plist["TeamIdentifier"][0]


def _find_newest_profile(
    expected_specifier: str, team_id: Optional[str], profiles: List[str]
) -> Optional[str]:
    newest_path: Optional[str] = None
    newest_date: Optional[datetime.datetime] = None
    for profile in profiles:
        profile_name, profile_uuid, creation_date, actual_team_id = _profile_contents(profile)
        if profile_name != expected_specifier and profile_uuid != expected_specifier:
            continue
        if team_id and team_id != actual_team_id:
            continue
        # TODO: Skip expired profiles
        if not newest_date or creation_date > newest_date:
            newest_path = profile
            newest_date = creation_date

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
    if args.control:
        args = _args_from_control(args.control)
    if not args.name or not args.output:
        _build_parser().error(
            "name and output are required unless --control is provided"
        )
    _find_profile(
        args.name,
        args.team_id,
        args.output,
        args.local_profiles or [],
        args.fallback_profiles or [],
    )
