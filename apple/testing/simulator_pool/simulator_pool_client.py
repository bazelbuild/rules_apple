#!/usr/bin/python3
# Copyright 2022 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
import json
import sys
import urllib.request
import urllib.parse
from typing import Optional


class SimulatorPoolClient:
    """Client for interacting with the simulator pool server."""

    def __init__(self, port: int):
        """Initialize the client with the server URL.

        Args:
            port: Port of the simulator pool server (e.g., 8080)
        """
        self.port = port

    def request_simulator(self, device_type: str, os_version: str, test_target: str, test_host: Optional[str]) -> Optional[str]:
        """Request a simulator from the pool.

        Args:
            device_type: Type of device (e.g., 'iPhone 14')
            os_version: iOS version (e.g., '16.0')
            test_target: Test target (e.g., 'MyAppTests')
            test_host: Test host (e.g., 'MyApp')

        Returns:
            Simulator UDID if available, None otherwise
        """
        try:
            # Build query parameters
            params = {
                'device_type': device_type,
                'os_version': os_version,
                'test_target': test_target,
                'test_host': test_host if test_host else '',
            }
            query_string = urllib.parse.urlencode(params)
            url = f"http://localhost:{self.port}/request?{query_string}"

            # Make the request
            with urllib.request.urlopen(url) as response:
                if response.status == 200:
                    data = json.loads(response.read().decode())
                    if data.get('success'):
                        return data.get('udid')
                    else:
                        print(f"No simulator available: {data.get('udid', '')}", file=sys.stderr)
                        return None
                else:
                    print(f"Request failed with status {response.status}", file=sys.stderr)
                    return None

        except urllib.error.HTTPError as e:
            if e.code == 400:
                error_data = json.loads(e.read().decode())
                print(f"Bad request: {error_data.get('error', 'Unknown error')}", file=sys.stderr)
            else:
                print(f"HTTP error {e.code}: {e.reason}", file=sys.stderr)
            return None
        except urllib.error.URLError as e:
            print(f"Connection error: {e.reason}", file=sys.stderr)
            return None
        except Exception as e:
            print(f"Unexpected error: {e}", file=sys.stderr)
            return None

    def return_simulator(self, simulator_udid: str) -> bool:
        """Return a simulator to the pool.

        Args:
            simulator_udid: UDID of the simulator to return

        Returns:
            True if successful, False otherwise
        """
        try:
            # Prepare the request data
            data = {
                'udid': simulator_udid
            }
            json_data = json.dumps(data).encode('utf-8')

            # Create the request
            url = f"http://localhost:{self.port}/return"
            req = urllib.request.Request(url, data=json_data, method='POST')
            req.add_header('Content-Type', 'application/json')

            # Make the request
            with urllib.request.urlopen(req) as response:
                if response.status == 200:
                    response_data = json.loads(response.read().decode())
                    success = response_data.get('success', False)
                    message = response_data.get('message', 'Unknown response')

                    if success:
                        print(f"Success: {message}", file=sys.stderr)
                    else:
                        print(f"Failed: {message}", file=sys.stderr)

                    return success
                else:
                    print(f"Return failed with status {response.status}", file=sys.stderr)
                    return False

        except urllib.error.HTTPError as e:
            if e.code == 400:
                error_data = json.loads(e.read().decode())
                print(f"Bad request: {error_data.get('error', 'Unknown error')}", file=sys.stderr)
            else:
                print(f"HTTP error {e.code}: {e.reason}", file=sys.stderr)
            return False
        except urllib.error.URLError as e:
            print(f"Connection error: {e.reason}", file=sys.stderr)
            return False
        except Exception as e:
            print(f"Unexpected error: {e}", file=sys.stderr)
            return False


def main():
    """Main entry point for the command line tool."""
    parser = argparse.ArgumentParser(
        description='Simulator Pool Client - Interact with the simulator pool server',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Request a simulator
  %(prog)s request --device-type "iPhone 14" --os-version "16.0"

  # Return a simulator
  %(prog)s return --udid "12345678-1234-1234-1234-123456789012"

  # Use custom port
  %(prog)s --port 9000 request --device-type "iPhone 14" --os-version "16.0"
        """
    )

    # Global options
    parser.add_argument(
        '--port',
        help='Simulator pool server port'
    )

    # Subcommands
    subparsers = parser.add_subparsers(dest='command', help='Available commands')

    # Request command
    request_parser = subparsers.add_parser(
        'request',
        help='Request a simulator from the pool'
    )
    request_parser.add_argument(
        '--device-type',
        required=True,
        help='Device type (e.g., "iPhone 14", "iPad Pro")'
    )
    request_parser.add_argument(
        '--os-version',
        required=True,
        help='iOS version (e.g., "16.0", "15.5")'
    )
    request_parser.add_argument(
        '--test-target',
        required=True,
        help='Test target (e.g., "MyAppTests")'
    )
    request_parser.add_argument(
        '--test-host',
        required=False,
        help='Test host (e.g., "MyApp")'
    )

    # Return command
    return_parser = subparsers.add_parser(
        'return',
        help='Return a simulator to the pool'
    )
    return_parser.add_argument(
        '--udid',
        required=True,
        help='Simulator UDID to return'
    )

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    # Create client
    client = SimulatorPoolClient(args.port)

    try:
        if args.command == 'request':
            # Request a simulator
            simulator_udid = client.request_simulator(args.device_type, args.os_version, args.test_target, args.test_host)
            while not simulator_udid:
                time.sleep(1)
                simulator_udid = client.request_simulator(args.device_type, args.os_version, args.test_target, args.test_host)
            print(simulator_udid)
            sys.exit(0)

        elif args.command == 'return':
            # Return a simulator
            success = client.return_simulator(args.udid)
            sys.exit(0 if success else 1)

    except KeyboardInterrupt:
        print("\nOperation cancelled by user", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
