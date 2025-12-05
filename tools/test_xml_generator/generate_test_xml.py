#!/usr/bin/env python3

# Copyright 2024 The Bazel Authors. All rights reserved.
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

"""
Post-action script to generate proper JUnit XML from iOS/macOS test output.

This script runs after test execution and parses the test log to create
a properly formatted JUnit XML file that can be consumed by CI systems.

Environment Variables:
    TEST_LOG_FILE: Path to the test log file (contains xcodebuild output)
    XML_OUTPUT_FILE: Path where the JUnit XML should be written
    TEST_EXIT_CODE: Exit code from the test run
    TEST_XCRESULT_BUNDLE_PATH: Optional path to XCResult bundle
    SIMULATOR_UDID: Optional simulator ID
"""

import os
import sys
import re
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple


class TestCase:
    """Represents a single test case."""
    
    def __init__(self, classname: str, name: str):
        self.classname = classname
        self.name = name
        self.time = 0.0
        self.status = 'unknown'
        self.failure_message = None
        self.failure_type = None
        self.failure_details = None
        self.system_out = []
        self.system_err = []


class TestLogParser:
    """Parser for XCTest output logs."""
    
    # Regex patterns for parsing XCTest output
    # Updated to handle method names with underscores and complex characters
    # Precompile all patterns once at class level
    TEST_START_PATTERN = re.compile(
        r"Test Case '-\[([^\s]+) ([^\]]+)\]' started"
    )
    TEST_PASS_PATTERN = re.compile(
        r"Test Case '-\[([^\s]+) ([^\]]+)\]' passed \(([\d\.]+) seconds\)\."
    )
    TEST_FAIL_PATTERN = re.compile(
        r"Test Case '-\[([^\s]+) ([^\]]+)\]' failed \(([\d\.]+) seconds\)\."
    )
    FAILURE_PATTERN = re.compile(
        r"(.*):(\d+): error: -\[([^\s]+) ([^\]]+)\] : (.+)"
    )
    SUITE_START_PATTERN = re.compile(
        r"Test Suite '([^']+)' started at (.+)"
    )
    SUITE_FINISH_PATTERN = re.compile(
        r"Test Suite '([^']+)' (passed|failed) at (.+)"
    )
    
    # Alternative pattern for Swift Testing (Xcode 16+)
    SWIFT_TEST_START_PATTERN = re.compile(
        r"Test ([^\s/]+)/([^\s]+) started"
    )
    SWIFT_TEST_PASS_PATTERN = re.compile(
        r"Test ([^\s/]+)/([^\s]+) passed after ([\d\.]+) seconds\."
    )
    SWIFT_TEST_FAIL_PATTERN = re.compile(
        r"Test ([^\s/]+)/([^\s]+) failed after ([\d\.]+) seconds\."
    )
    
    def __init__(self, log_content: str):
        self.log_content = log_content
        # Store lines as a list for efficient iteration
        self.lines = log_content.split('\n') if log_content else []
    
    def parse(self) -> List[TestCase]:
        """Parse the log content and extract test cases."""
        test_cases = []
        current_test = None
        failure_context = []
        
        # Pre-compile pattern checks for faster iteration
        for line in self.lines:
            # Quick check to skip most lines that don't match any pattern
            # Most lines are output, not test case markers
            if 'Test Case' not in line and 'Test ' not in line:
                if current_test:
                    failure_context.append(line)
                    # Keep only last 20 lines for context
                    if len(failure_context) > 20:
                        failure_context.pop(0)
                continue
            
            # Check for test start (XCTest format)
            if "Test Case '-[" in line and 'started' in line:
                start_match = self.TEST_START_PATTERN.search(line)
                if start_match:
                    classname, method = start_match.groups()
                    current_test = TestCase(classname, method)
                    failure_context = []
                    continue
            
            # Check for test start (Swift Testing format)
            if 'Test ' in line and 'started' in line and 'Test Case' not in line:
                swift_start_match = self.SWIFT_TEST_START_PATTERN.search(line)
                if swift_start_match:
                    classname, method = swift_start_match.groups()
                    current_test = TestCase(classname, method)
                    failure_context = []
                    continue
            
            # Check for test pass (XCTest)
            if current_test and 'passed' in line:
                pass_match = self.TEST_PASS_PATTERN.search(line)
                if pass_match:
                    classname, method, time = pass_match.groups()
                    if current_test.classname == classname and current_test.name == method:
                        current_test.time = float(time)
                        current_test.status = 'passed'
                        test_cases.append(current_test)
                        current_test = None
                        failure_context = []
                    continue
                
                # Check for test pass (Swift Testing)
                swift_pass_match = self.SWIFT_TEST_PASS_PATTERN.search(line)
                if swift_pass_match:
                    classname, method, time = swift_pass_match.groups()
                    if current_test.classname == classname and current_test.name == method:
                        current_test.time = float(time)
                        current_test.status = 'passed'
                        test_cases.append(current_test)
                        current_test = None
                        failure_context = []
                    continue
            
            # Check for test failure (XCTest)
            if current_test and 'failed' in line:
                fail_match = self.TEST_FAIL_PATTERN.search(line)
                if fail_match:
                    classname, method, time = fail_match.groups()
                    if current_test.classname == classname and current_test.name == method:
                        current_test.time = float(time)
                        current_test.status = 'failed'
                        
                        # Look for failure details in context
                        self._extract_failure_details(current_test, failure_context)
                        
                        test_cases.append(current_test)
                        current_test = None
                        failure_context = []
                    continue
                
                # Check for test failure (Swift Testing)
                swift_fail_match = self.SWIFT_TEST_FAIL_PATTERN.search(line)
                if swift_fail_match:
                    classname, method, time = swift_fail_match.groups()
                    if current_test.classname == classname and current_test.name == method:
                        current_test.time = float(time)
                        current_test.status = 'failed'
                        
                        # Look for failure details in context
                        self._extract_failure_details(current_test, failure_context)
                        
                        test_cases.append(current_test)
                        current_test = None
                        failure_context = []
                    continue
            
            # Collect context for potential failures
            if current_test:
                failure_context.append(line)
                # Keep only last 20 lines for context
                if len(failure_context) > 20:
                    failure_context.pop(0)
        
        return test_cases
    
    def _extract_failure_details(self, test_case: TestCase, context_lines: List[str]):
        """Extract failure details from context lines."""
        failure_index = -1
        
        for i, line in enumerate(context_lines):
            failure_match = self.FAILURE_PATTERN.search(line)
            if failure_match:
                file, line_num, fc, fm, message = failure_match.groups()
                failure_index = i
                
                # Clean up the file path to make it more readable
                clean_path = self._clean_file_path(file)
                
                # Build comprehensive failure message with context
                message_parts = [message.strip()]
                
                # Look ahead for additional context (Received/Expected values, etc.)
                for j in range(i + 1, min(i + 15, len(context_lines))):
                    next_line = context_lines[j].strip()
                    
                    # Stop at the next test case
                    if next_line.startswith('Test Case'):
                        break
                    
                    # Include important context lines
                    if any(keyword in next_line for keyword in ['Received:', 'Expected:', 'Actual:', 'but was:', 'but got:']):
                        message_parts.append(next_line)
                    # Include assertion failure details
                    elif next_line and not next_line.startswith('Test '):
                        # Check if it's a continuation of error details
                        if any(char in next_line for char in [':', '=']) or 'failed' in next_line.lower():
                            # Limit length to avoid too much noise
                            if len('\n'.join(message_parts)) < 500:
                                message_parts.append(next_line)
                
                # Build full failure message
                full_message = '\n'.join(message_parts)
                
                test_case.failure_message = full_message
                test_case.failure_type = 'XCTestFailure'
                test_case.failure_details = f"{clean_path}:{line_num}: {full_message}"
                
                # Include broader context in system-err
                start_idx = max(0, i - 5)
                end_idx = min(len(context_lines), i + 15)
                test_case.system_err = context_lines[start_idx:end_idx]
                return
        
        # If no specific failure pattern found, use generic failure
        if not test_case.failure_message:
            test_case.failure_message = "Test failed (see system-err for details)"
            test_case.failure_type = 'TestFailure'
            test_case.failure_details = '\n'.join(context_lines[-10:])
            test_case.system_err = context_lines[-10:]
    
    def _clean_file_path(self, file_path: str) -> str:
        """Clean up file path to make it more readable.
        
        Removes simulator device paths and other Bazel/system noise.
        """
        # Remove simulator device paths
        # Format: /Users/.../CoreSimulator/Devices/{UUID}/data/{workspace_path}
        if '/CoreSimulator/Devices/' in file_path:
            parts = file_path.split('/data/', 1)
            if len(parts) == 2:
                return parts[1]
        
        # Remove Bazel execroot paths
        if '/execroot/_main/' in file_path:
            parts = file_path.split('/execroot/_main/', 1)
            if len(parts) == 2:
                return parts[1]
        
        if '/execroot/__main__/' in file_path:
            parts = file_path.split('/execroot/__main__/', 1)
            if len(parts) == 2:
                return parts[1]
        
        # Return last few meaningful components
        parts = file_path.split('/')
        if len(parts) > 3:
            # Find first meaningful component (skip UUID-like paths)
            for i in range(len(parts) - 1, max(0, len(parts) - 5), -1):
                if parts[i] and not parts[i].startswith('.') and '-' not in parts[i][:8]:
                    return '/'.join(parts[i:])
        
        return file_path


class JUnitXMLGenerator:
    """Generator for JUnit XML format."""
    
    def __init__(self, test_cases: List[TestCase], suite_name: str = 'iOS/macOS Tests'):
        self.test_cases = test_cases
        self.suite_name = suite_name
    
    def generate(self) -> str:
        """Generate JUnit XML string."""
        # Group tests by class
        test_suites = self._group_by_class()
        
        # Calculate totals once
        total_tests = len(self.test_cases)
        total_failures = sum(1 for t in self.test_cases if t.status == 'failed')
        total_time = sum(t.time for t in self.test_cases)
        
        # Create XML structure
        testsuites = ET.Element('testsuites')
        testsuites.set('name', self.suite_name)
        testsuites.set('tests', str(total_tests))
        testsuites.set('failures', str(total_failures))
        testsuites.set('errors', '0')
        testsuites.set('time', str(total_time))
        testsuites.set('timestamp', datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'))
        
        # Create test suites
        for suite_name, tests in test_suites.items():
            testsuite = ET.SubElement(testsuites, 'testsuite')
            testsuite.set('name', suite_name)
            testsuite.set('tests', str(len(tests)))
            
            suite_failures = sum(1 for t in tests if t.status == 'failed')
            testsuite.set('failures', str(suite_failures))
            testsuite.set('errors', '0')
            testsuite.set('time', str(sum(t.time for t in tests)))
            
            for test in tests:
                self._add_test_case(testsuite, test)
        
        # Use faster XML serialization - avoid minidom pretty printing
        # which is very slow for large XML documents
        xml_str = ET.tostring(testsuites, encoding='unicode')
        
        # Use simple string formatting for indentation (much faster than minidom)
        return self._pretty_print_fast(xml_str)
    
    def _pretty_print_fast(self, xml_str: str) -> str:
        """Fast pretty-print using simple string manipulation."""
        # Add newlines and indentation
        result = ['<?xml version="1.0" ?>']
        depth = 0
        i = 0
        
        while i < len(xml_str):
            # Find next tag
            if xml_str[i] == '<':
                # Find end of tag
                end = xml_str.find('>', i)
                if end == -1:
                    break
                
                tag = xml_str[i:end+1]
                
                # Adjust depth for closing tags before adding indentation
                if tag.startswith('</'):
                    depth -= 1
                
                # Add indented line
                if tag.startswith('</') or not tag.endswith('/>'):
                    result.append('  ' * depth + tag)
                else:
                    result.append('  ' * depth + tag)
                
                # Adjust depth for opening tags
                if not tag.startswith('</') and not tag.endswith('/>') and not tag.startswith('<?'):
                    depth += 1
                
                i = end + 1
            else:
                # Text content
                text_end = xml_str.find('<', i)
                if text_end == -1:
                    break
                text = xml_str[i:text_end].strip()
                if text:
                    # Text content on same line as tag
                    if result:
                        result[-1] += text
                i = text_end
        
        return '\n'.join(result)
    
    def _group_by_class(self) -> Dict[str, List[TestCase]]:
        """Group test cases by class name."""
        suites = {}
        for test in self.test_cases:
            classname = test.classname
            if classname not in suites:
                suites[classname] = []
            suites[classname].append(test)
        return suites
    
    def _add_test_case(self, parent: ET.Element, test: TestCase):
        """Add a test case element to the parent."""
        testcase = ET.SubElement(parent, 'testcase')
        testcase.set('classname', test.classname)
        testcase.set('name', test.name)
        testcase.set('time', str(test.time))
        
        if test.status == 'failed':
            failure = ET.SubElement(testcase, 'failure')
            failure.set('message', test.failure_message or 'Test failed')
            failure.set('type', test.failure_type or 'TestFailure')
            if test.failure_details:
                failure.text = test.failure_details
        
        if test.system_out:
            system_out = ET.SubElement(testcase, 'system-out')
            system_out.text = '\n'.join(test.system_out)
        
        if test.system_err:
            system_err = ET.SubElement(testcase, 'system-err')
            system_err.text = '\n'.join(test.system_err)


def main():
    """Main entry point."""
    # Get environment variables
    test_log_file = os.environ.get('TEST_LOG_FILE')
    xml_output_file = os.environ.get('XML_OUTPUT_FILE')
    test_exit_code = os.environ.get('TEST_EXIT_CODE', '0')
    
    print("=" * 80)
    print("Test XML Generator - Post Action")
    print("=" * 80)
    
    # Validate inputs
    if not test_log_file:
        print("Warning: TEST_LOG_FILE environment variable not set", file=sys.stderr)
        print("Skipping XML generation")
        sys.exit(0)
    
    if not os.path.exists(test_log_file):
        print(f"Warning: Test log file not found: {test_log_file}", file=sys.stderr)
        print("Skipping XML generation")
        sys.exit(0)
    
    if not xml_output_file:
        print("Warning: XML_OUTPUT_FILE environment variable not set", file=sys.stderr)
        print("Skipping XML generation")
        sys.exit(0)
    
    print(f"Test Log File: {test_log_file}")
    print(f"XML Output File: {xml_output_file}")
    print(f"Test Exit Code: {test_exit_code}")
    print()
    
    # Read test log
    try:
        with open(test_log_file, 'r', encoding='utf-8', errors='replace') as f:
            log_content = f.read()
    except Exception as e:
        print(f"Error reading test log: {e}", file=sys.stderr)
        sys.exit(0)  # Don't fail the build
    
    # Parse test results
    print("Parsing test log...")
    parser = TestLogParser(log_content)
    test_cases = parser.parse()
    
    if not test_cases:
        print("Warning: No test cases found in log output")
        print("This might be expected if tests didn't run or output format is different")
        # Create minimal XML
        testsuites = ET.Element('testsuites')
        testsuites.set('name', 'Tests')
        testsuites.set('tests', '0')
        testsuites.set('failures', '0')
        testsuites.set('errors', '0')
        xml_content = '<?xml version="1.0" ?>\n' + ET.tostring(testsuites, encoding='unicode')
    else:
        print(f"Found {len(test_cases)} test cases")
        
        passed = sum(1 for t in test_cases if t.status == 'passed')
        failed = sum(1 for t in test_cases if t.status == 'failed')
        print(f"  Passed: {passed}")
        print(f"  Failed: {failed}")
        print()
        
        # Generate JUnit XML
        print("Generating JUnit XML...")
        generator = JUnitXMLGenerator(test_cases)
        xml_content = generator.generate()
    
    # Write XML file
    try:
        # Ensure output directory exists
        os.makedirs(os.path.dirname(xml_output_file), exist_ok=True)
        
        with open(xml_output_file, 'w', encoding='utf-8') as f:
            f.write(xml_content)
        
        print(f"✓ Successfully wrote JUnit XML to: {xml_output_file}")
    except Exception as e:
        print(f"Error writing XML file: {e}", file=sys.stderr)
        sys.exit(0)  # Don't fail the build
    
    print("=" * 80)
    
    # Always exit successfully - we don't want XML generation issues to fail the test
    sys.exit(0)


if __name__ == '__main__':
    main()

