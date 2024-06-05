// Copyright 2024 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ArgumentParser
import tools_codesigningtool_code_sign_process_options
import tools_imported_dynamic_framework_processor_process_dynamic_framework_options

/// ImportedFrameworkProcessor invocation that repackages and thins the incoming precompiled dynamic
/// framework into an output appropriate for the target being built.
public struct ProcessDynamicFramework: ParsableCommand {

  @OptionGroup
  private var sharedOptions: ProcessDynamicFrameworkOptions

  @OptionGroup(visibility: .hidden)
  private var codesignOptions: CodeSignProcessOptions

  public init() {}

  public func run() throws {
    // TODO(b/336345916): Implement flows necessary to take a potentially "fat" dynamic framework
    // and repackage its contents to a zipped form appropriate for the target being built.
  }

}
