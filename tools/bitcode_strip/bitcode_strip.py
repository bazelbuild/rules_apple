# Lint as: python2, python3
# Copyright 2020 The Bazel Authors. All rights reserved.
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
#

from build_bazel_rules_apple.tools.wrapper_common import execute


def invoke(input_path, output_path):
  """Wraps bitcode_strip with the given input and output."""
  xcrunargs = ["xcrun",
               "bitcode_strip",
               input_path,
               "-r",
               "-keep_cs",
               "-o",
               output_path]

  execute.execute_and_filter_output(
      xcrunargs,
      print_output=True,
      raise_on_failure=True)
