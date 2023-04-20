import Foundation

extension String {
    var nonEmptyOrNil: String? {
        if self.isEmpty {
            return nil
        } else {
            return self
        }
    }

    var xmlEscaped: String {
        return replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "<", with: "&lt;")
    }

    var asPath: URL {
        return URL(filePath: self)
    }
}

// When describing a URL, customize the value: use its path
extension String.StringInterpolation {
    mutating func appendInterpolation(_ value: URL) {
        appendInterpolation(value.path)
    }
}
