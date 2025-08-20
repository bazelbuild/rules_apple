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
import os
import signal
import socket
import subprocess
import sys
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
from typing import Dict, Set, Optional, List
import apple.testing.default_runner.simulator_utils as simulator_utils
import random
import string

class Simulator:
    def __init__(self, udid: str, device_type: str, os_version: str):
        self.udid = udid
        self.device_type = device_type
        self.os_version = os_version

    def __hash__(self):
        return hash((self.udid, self.device_type, self.os_version))

class SimulatorPoolHandler(BaseHTTPRequestHandler):
    """HTTP request handler for simulator pool management."""

    # Class-level variables to store the pool
    available_simulators = set()
    all_simulators = set()

    @classmethod
    def set_simulator_pool(cls, simulator_pool: List[Simulator]):
        """Set the simulator pool for the handler class."""
        cls.available_simulators = set(simulator_pool)
        cls.all_simulators = set(simulator_pool)

    def do_GET(self):
        """Handle GET requests for requesting a simulator."""
        parsed_url = urlparse(self.path)

        if parsed_url.path == '/request':
            # Request a simulator UDID
            # Get device_type and os_version from query parameters
            query_params = parse_qs(parsed_url.query)
            device_type = query_params.get('device_type', [''])[0]
            os_version = query_params.get('os_version', [''])[0]

            if not device_type or not os_version:
                self._send_error_response(400, "Missing device_type or os_version query parameters")
                return

            simulator = self._get_available_simulator(device_type, os_version)

            response_data = {
                'udid': simulator.udid if simulator else '',
                'success': bool(simulator)
            }

            self._send_json_response(response_data)
        elif parsed_url.path == '/status':
            # Status endpoint
            response_data = {
                'status': 'running',
                'available_simulators': len(self.available_simulators),
                'total_simulators': len(self.all_simulators),
                'timestamp': time.time()
            }
            self._send_json_response(response_data)
        elif parsed_url.path == '/shutdown':
            # Graceful shutdown endpoint
            response_data = {
                'success': True,
                'message': 'Server shutdown initiated'
            }
            self._send_json_response(response_data)

            # Schedule shutdown after response is sent
            import threading
            def delayed_shutdown():
                time.sleep(0.1)  # Small delay to ensure response is sent
                os.kill(os.getpid(), signal.SIGTERM)

            threading.Thread(target=delayed_shutdown, daemon=True).start()
        else:
            self._send_error_response(404, "Endpoint not found")

    def do_POST(self):
        """Handle POST requests for returning a simulator."""
        parsed_url = urlparse(self.path)

        if parsed_url.path == '/return':
            # Return a simulator UDID
            content_length = int(self.headers.get('Content-Length', 0))
            if content_length == 0:
                self._send_error_response(400, "Missing request body")
                return

            try:
                request_data = json.loads(self.rfile.read(content_length))
                simulator_udid = request_data.get('udid')

                if not simulator_udid:
                    self._send_error_response(400, "Missing 'udid' in request body")
                    return

                success = self._return_simulator(simulator_udid)

                response_data = {
                    'success': success,
                    'message': f"Simulator {simulator_udid} {'returned to pool' if success else 'not found in pool'}"
                }

                self._send_json_response(response_data)

            except json.JSONDecodeError:
                self._send_error_response(400, "Invalid JSON in request body")
        else:
            self._send_error_response(404, "Endpoint not found")

    def _get_available_simulator(self, device_type: str, os_version: str) -> Optional[Simulator]:
        """Get an available simulator UDID from the pool. If there are no available simulators, return None."""
        if not self.available_simulators:
            return None
        for simulator in self.available_simulators:
            if simulator.device_type == device_type and simulator.os_version == os_version:
                self.available_simulators.remove(simulator)
                return simulator
        return None

    def _return_simulator(self, simulator_udid: str) -> bool:
        """Return a simulator UDID to the available pool."""
        for simulator in self.all_simulators:
            if simulator.udid == simulator_udid:
                self.available_simulators.add(simulator)
                return True
        return False

    def _send_json_response(self, data: Dict) -> None:
        """Send a JSON response."""
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def _send_error_response(self, status_code: int, message: str) -> None:
        """Send an error response."""
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()

        error_data = {
            'error': message,
            'status_code': status_code
        }
        self.wfile.write(json.dumps(error_data).encode())

    def log_message(self, format, *args):
        """Override to use stderr for logging."""
        print(f"[{self.log_date_time_string()}] {format % args}", file=sys.stderr)

def parse_simulators(simulator_pool_config_path: str):
    with open(simulator_pool_config_path, 'r') as f:
        simulator_pool_config = json.load(f)
    return [Simulator(simulator['udid'], simulator['device_type'], simulator['os_version']) for simulator in simulator_pool_config['simulators']]

def is_port_in_use(host: str, port: int) -> bool:
    """Check if a port is already in use."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(1)
            result = s.connect_ex((host, port))
            return result == 0
    except Exception:
        return False

def kill_processes_on_port(host: str, port: int) -> bool:
    """Kill any processes using the specified port."""
    try:
        # Use lsof to find processes using the port
        if host == 'localhost' or host == '127.0.0.1':
            # For localhost, we can use lsof to find the process
            cmd = ['lsof', '-ti', f':{port}']
            result = subprocess.run(cmd, capture_output=True, text=True)

            if result.returncode == 0 and result.stdout.strip():
                pids = result.stdout.strip().split('\n')
                killed_count = 0

                for pid in pids:
                    if pid.strip():
                        try:
                            # Try graceful shutdown first
                            os.kill(int(pid), signal.SIGTERM)
                            time.sleep(1)

                            # Check if process is still running
                            try:
                                os.kill(int(pid), 0)  # Signal 0 doesn't kill, just checks if process exists
                                # Process still running, force kill
                                os.kill(int(pid), signal.SIGKILL)
                                time.sleep(0.5)
                            except OSError:
                                pass  # Process is dead

                            killed_count += 1
                            print(f"Killed process {pid} using port {port}", file=sys.stderr)

                        except (OSError, ValueError) as e:
                            print(f"Error killing process {pid}: {e}", file=sys.stderr)

                # Wait a bit for port to be released
                time.sleep(2)
                return killed_count > 0
        else:
            # For non-localhost, we can't easily kill remote processes
            print(f"Warning: Cannot kill processes on remote host {host}", file=sys.stderr)
            return False

    except Exception as e:
        print(f"Error checking/killing processes on port {port}: {e}", file=sys.stderr)
        return False

    return False

def ensure_port_available(host: str, port: int, force_kill: bool = True) -> bool:
    """Ensure the port is available, optionally killing existing processes."""
    if not is_port_in_use(host, port):
        return True

    # Check if there's already a simulator pool server running
    server_status = check_server_status(host, port)
    if server_status['running']:
        print(f"Port {port} is in use by another simulator pool server:", file=sys.stderr)
        if server_status['data']:
            print(f"  Available simulators: {server_status['data'].get('available_simulators', 'unknown')}", file=sys.stderr)
            print(f"  Total simulators: {server_status['data'].get('total_simulators', 'unknown')}", file=sys.stderr)

    if not force_kill:
        print(f"Port {port} is already in use. Use --force-kill to kill existing processes.", file=sys.stderr)
        return False

    print(f"Port {port} is in use. Attempting to kill existing processes...", file=sys.stderr)
    if kill_processes_on_port(host, port):
        # Check again if port is now available
        time.sleep(1)
        if not is_port_in_use(host, port):
            print(f"Port {port} is now available", file=sys.stderr)
            return True
        else:
            print(f"Port {port} is still in use after killing processes", file=sys.stderr)
            return False
    else:
        print(f"Failed to free port {port}", file=sys.stderr)
        return False

def check_server_status(host: str, port: int) -> Dict[str, any]:
    """Check if there's already a simulator pool server running on the port."""
    try:
        import urllib.request
        import urllib.error

        url = f"http://{host}:{port}/status"
        with urllib.request.urlopen(url, timeout=5) as response:
            if response.status == 200:
                data = json.loads(response.read().decode())
                return {
                    'running': True,
                    'data': data
                }
    except (urllib.error.URLError, urllib.error.HTTPError):
        pass
    except Exception:
        pass

    return {'running': False, 'data': None}

def signal_handler(signum, frame):
    """Handle shutdown signals gracefully."""
    print(f"\nReceived signal {signum}, shutting down server...", file=sys.stderr)
    sys.exit(0)

def run_server(host: str, port: int, simulator_pool: List[Simulator], force_kill: bool = True):
    """Run the simulator pool server."""
    # Set up signal handlers for graceful shutdown
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    # Ensure port is available before starting
    if not ensure_port_available(host, port, force_kill):
        print(f"Failed to start server: port {port} is not available", file=sys.stderr)
        sys.exit(1)

    # Set the pool on the handler class before creating the server
    SimulatorPoolHandler.set_simulator_pool(simulator_pool)

    server_address = (host, port)
    httpd = HTTPServer(server_address, SimulatorPoolHandler)

    print(f"Simulator pool server starting on {host}:{port}", file=sys.stderr)
    print("Available endpoints:", file=sys.stderr)
    print("  GET  /request?device_type=<type>&os_version=<version> - Request a simulator UDID", file=sys.stderr)
    print("  POST /return  - Return a simulator UDID (body: {\"udid\": \"<simulator_udid>\"})", file=sys.stderr)
    print("  GET  /status   - Get server status and pool information", file=sys.stderr)
    print("  GET  /shutdown - Gracefully shutdown the server", file=sys.stderr)

    try:
        httpd.serve_forever()

    except KeyboardInterrupt:
        print("\nShutting down server...", file=sys.stderr)
        httpd.shutdown()

def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description='Simulator Pool HTTP Server')
    parser.add_argument('--host', default='localhost', help='Host to bind to (default: localhost)')
    parser.add_argument('--port', type=int, help='Port to bind to')
    parser.add_argument('--simulator-pool-config-path', help='Path to the simulator pool config file')
    parser.add_argument('--force-kill', action='store_true', default=True,
                       help='Kill existing processes using the port (default: True)')
    parser.add_argument('--no-force-kill', dest='force_kill', action='store_false',
                       help='Do not kill existing processes using the port')

    args = parser.parse_args()

    simulator_pool = parse_simulators(args.simulator_pool_config_path)

    run_server(args.host, args.port, simulator_pool, args.force_kill)

if __name__ == '__main__':
    main()
