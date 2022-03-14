// Copyright 2022 The Bazel Authors. All rights reserved.
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

import Foundation

public protocol Log {
    func append(_ item: Any, terminator: String)
}

public extension Log {
    func append(_ item: Any) {
        append(item, terminator: "\n")
    }
}

public final class LogImp: Log {
    public init() {}

    public func append(_ item: Any, terminator: String) {
        print(item, terminator: terminator)
    }
}

public final class Logger {

    private let log: Log

    public init(log: Log) {
        self.log = log
    }

    func printHelloWorld(bundle: Bundle) {
        log.append("Hello World from \(bundle.bundleIdentifier ?? "<none>")")
        log.append("Here is the entire Info.plist dictionary: \(bundle.infoDictionary ?? [:])")
    }
}
