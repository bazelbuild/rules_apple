import SwiftCLI
import Foundation

extension RunError: LocalizedError {
    public var errorDescription: String? {
        """
        Error executing command
        Exit status: \(exitStatus)
        Message: \(message ?? "none")
        """.red()
    }
}

extension CaptureError: LocalizedError {
    public var errorDescription: String? {
        """
        Error executing command
        Exit status: \(exitStatus)
        Stdout: \(captured.stdout)
        Stderr: \(captured.stderr)
        """.red()
    }
}
