import Foundation
import SwiftCLI
import ColorizeSwift

// An interface containing code that interacts with external APIs (example: disk IO), and that can be mocked during testing
protocol InteractorProtocol: AnyObject {
    var verbose: Bool { get set }
    var env: [String: String] { get }
    var currentPath: URL { get }
    var tmpDir: URL { get set }
    func mkdir(at path: URL) throws
    func read(_ path: URL) throws -> String
    func write(_ string: String, to path: URL) throws
    func exists(path: URL) -> Bool
    func copyItem(at origin: URL, to destination: URL) throws
    func children(at path: URL) throws -> [URL]
    @discardableResult func run(_ cmd: String) throws -> String
    func getDeveloperDir() throws -> URL
    func print(_ kind: PrintKind, _ message: String)
}

final class Interactor: InteractorProtocol {
    static let shared: InteractorProtocol = Interactor()
    private let outputQueue = DispatchQueue(
        label: "output_queue",
        qos: .userInteractive,
        target: .global(qos: .userInteractive)
    )

    private let fileManager: FileManager

    // Always inject the shared instance, so it is possible to modify stored properties inside this interactor
    // and make the changes available to all consumers (example: tmpDir)
    private convenience init() {
        self.init(fileManager: FileManager.default)
    }

    init(fileManager: FileManager) {
        self.fileManager = fileManager
    }

    var verbose: Bool = false

    var env: [String: String] {
        ProcessInfo.processInfo.environment
    }

    var currentPath: URL {
        fileManager.currentDirectoryPath.asPath
    }

    lazy var tmpDir: URL = fileManager
        .temporaryDirectory
        .appendingPathComponent("test_runner_work_dir.\(UUID().uuidString)")

    func mkdir(at path: URL) throws {
        print(.verbose, "mkdir: \(path)")
        try fileManager.createDirectory(at: path, withIntermediateDirectories: true)
    }

    func read(_ path: URL) throws -> String {
        print(.verbose, "read: \(path)")
        return try String(contentsOf: path)
    }

    func write(_ string: String, to path: URL) throws {
        print(
            .verbose,
            """
            write: \(path). Content:
            \(string)
            """
        )
        try string.write(to: path, atomically: true, encoding: .utf8)
    }

    func exists(path: URL) -> Bool {
        return fileManager.fileExists(atPath: path.path)
    }

    func copyItem(at origin: URL, to destination: URL) throws {
        try fileManager.copyItem(
            at: origin.resolvingSymlinksInPath(),
            to: destination.resolvingSymlinksInPath()
        )
    }

    func children(at path: URL) throws -> [URL] {
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey]
        let enumerator = fileManager.enumerator(
            at: path,
            includingPropertiesForKeys: Array(resourceKeys),
            options: .producesRelativePathURLs
        )

        var children: [URL] = []
        while let element = enumerator?.nextObject() as? URL {
            if try element.resourceValues(forKeys: Set(resourceKeys)).isDirectory == true {
                continue
            }

            children.append(element)
        }
        return children
    }

    @discardableResult func run(_ cmd: String) throws -> String {
        print(.verbose, "run: \(cmd)")
        return try taskCapture(cmd).stdout
    }

    func getDeveloperDir() throws -> URL {
        try URL(filePath: run("xcode-select -p"))
    }

    func print(_ kind: PrintKind, _ message: String) {
        switch kind {
        case .verbose:
            guard verbose else { return }
            queuePrint("VERBOSE: ".yellow() + message)

        case .note:
            queuePrint("NOTE: ".yellow() + message)
        }
    }
}

private extension Interactor {
    func taskCapture(_ cmd: String) throws -> CaptureResult {
        return try Task.capture("/bin/zsh", arguments: ["-c", prepareCmd(cmd)])
    }

    func prepareCmd(_ cmd: String) -> String {
        return """
        set -euo pipefail
        \(cmd)
        """
    }

    // Below print code is inspired in the swiftlint implementation of print
    // See: https://github.com/realm/SwiftLint/blob/86b6392aa22bb4b91a8f033d4dd11c8e4ab87b8f/Source/SwiftLintFramework/Extensions/QueuedPrint.swift#L43
    func queuePrint(_ string: String) {
        outputQueue.sync {
            fputs(string + "\n", stdout)
            fflush(stdout) // Flush after puts, so the message shows in the terminal synchronously
        }
    }

}

enum PrintKind: Equatable {
    case verbose
    case note
}
