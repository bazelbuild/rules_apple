import Foundation

extension URL {
    var name: String {
        self.deletingPathExtension().lastPathComponent
    }

    static func + (lhs: URL, rhs: String) -> URL {
        lhs.appending(path: rhs)
    }

    static func += (lhs: inout URL, rhs: String) {
        lhs.append(path: rhs)
    }
}
