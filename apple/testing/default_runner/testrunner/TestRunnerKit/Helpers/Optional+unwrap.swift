import Foundation

extension Optional {
    public func unwrap(_ description: String? = nil, file: String = #fileID, line: Int = #line) throws -> Wrapped {
        guard let unwrapped = self else {
            throw TestRunnerError.unexpectedNil(description: description, file: file, line: line)
        }
        return unwrapped
    }
}
