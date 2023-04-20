import Foundation

enum TestRunnerError: Equatable, Error, LocalizedError {
    case unexpectedNil(description: String? = nil, file: String = #fileID, line: Int = #line)
    case missingDeveloperDir
    case missingTempDir
    case emptyTestBundle
    case logContainTestFalseNegative
    case missingTestHostWhenUsingIntelHack
    case warningsWhenExportingCoverage(String)
    case warningsWhenExportingCoverageJson(String)

    var errorDescription: String? {
        let errorMessage: String

        switch self {
        case let .unexpectedNil(description, file, line):
            errorMessage = [
                "unexpected nil encountered at \(file):\(line)",
                description
            ].compactMap { $0 }.joined(separator: "\n")
        case .missingDeveloperDir:
            errorMessage = "the environmental variable 'DEVELOPER_DIR' is not defined"
        case .missingTempDir:
            errorMessage = "the environmental variable 'TEST_TMPDIR' is not defined"
        case .emptyTestBundle:
            errorMessage = "no tests were executed, is the test bundle empty?"
        case .logContainTestFalseNegative:
            errorMessage = "test logs contain a false negative test"
        case .missingTestHostWhenUsingIntelHack:
            errorMessage = "running 'x86_64' tests on 'arm64' macs using 'xcodebuild' requires a test host"
        case let .warningsWhenExportingCoverage(warnings):
            errorMessage = """
                llvm-cov produced warnings while exporting coverage report. Warnings:
                \(warnings)
                """
        case let .warningsWhenExportingCoverageJson(warnings):
            errorMessage = """
                llvm-cov produced warnings while exporting json coverage report. Warnings:
                \(warnings)
                """
        }

        return errorMessage.red()
    }
}
