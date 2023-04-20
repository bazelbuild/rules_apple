import Foundation
import TestRunnerKit
import ArgumentParser

public func main() {
    TestRunner.main()
}

struct TestRunner: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A test runner for Apple software",
        subcommands: [TestRunner.Test.self],
        defaultSubcommand: TestRunner.Test.self
    )
}
