import Foundation
import TestRunnerKit
import ArgumentParser

extension TestRunner {
    struct Test: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Execute tests"
        )

        @Option(help: "The test bundle containing the tests to execute")
        private var testBundle: URL

        @Option(help: "The application test host to use during the execution of the tests")
        private var testHost: URL?

        @Option(help: "Whether an xcresult bundle needs to be created")
        private var createXcresultBundle: BooleanAsString = .false

        @Option(help: "The device type to use for testing")
        private var deviceType: String

        @Option(help: "The OS version to use for testing")
        private var osVersion: String

        @Option(help: "A script in charge of creating an iOS simulator")
        private var simulatorCreator: URL

        @Option(help: "Whether the tests should be executed in random order")
        private var random: BooleanAsString = .false

        @Option(help: "Arguments to be passed through to xcodebuild")
        private var xcodebuildArgs: [String] = []

        @Option(help: "Template for an xctestrun file")
        private var xctestrunTemplate: URL

        @Option(help: "Whether the tests should reuse the simulator")
        private var reuseSimulator: BooleanAsString = .false

        @Option(help: "Custom test environment")
        private var testEnv: String?

        @Option(help: "The test type injected by bazel")
        private var testType: String

        @Option(help: "Test filters to use during test execution. See: https://github.com/bazelbuild/rules_apple/pull/1878")
        private var testFilter: String?

        @Option(help: "The manifest to be used when computing the test coverage")
        private var testCoverageManifest: URL?

        @Option(
            parsing: .remaining,
            help: "Additional test arguments injected with bazel using the '--test_arg' flag. See: https://github.com/bazelbuild/rules_apple/pull/1876"
        )
        private var testArgs: [String] = []

        func run() throws {
            let parsedTestArgs = try TestArgs.parse(testArgs)

            let input = TestAction.Input(
                testBundle: testBundle,
                testHost: testHost,
                createXcresultBundle: createXcresultBundle.value,
                deviceType: deviceType,
                osVersion: osVersion,
                simulatorCreator: simulatorCreator,
                random: random.value,
                xcodebuildArgs: xcodebuildArgs + parsedTestArgs.xcodebuildArgs,
                xctestrunTemplate: xctestrunTemplate,
                reuseSimulator: reuseSimulator.value,
                testEnv: testEnv,
                testType: testType,
                simulatorName: parsedTestArgs.simulatorName,
                testFilter: testFilter,
                testCoverageManifest: testCoverageManifest
            )
            try TestAction().execute(input: input)
        }
    }
}

private struct TestArgs: ParsableCommand {
    @Option(name: .customLong("simulator_name"), help: "The name of the simulator")
    var simulatorName: String?

    @Option(name: .customLong("xcodebuild_args"), help: "Arguments to be passed through to xcodebuild")
    var xcodebuildArgs: [String] = []
}

private enum BooleanAsString: String, CaseIterable, ExpressibleByArgument {
    case `true`
    case `false`

    var value: Bool {
        switch self {
        case .true:
            return true

        case .false:
            return false
        }
    }
}

extension URL: ExpressibleByArgument {
    public init?(argument: String) {
        self = URL(filePath: argument)
    }
}

extension Optional: ExpressibleByArgument where Wrapped == URL {
    public init?(argument: String) {
        if argument.isEmpty {
            self = nil
        } else {
            self = URL(filePath: argument)
        }
    }
}
