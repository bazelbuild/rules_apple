import Darwin

struct PTY {
  let parent: Int32
  let child: Int32

  init() throws {
    var parentFd: Int32 = 0
    var childFd: Int32 = 0

    // NULL for name/pw/termios/winsize = defaults
    let result = openpty(&parentFd, &childFd, nil, nil, nil)
    guard result == 0 else {
      throw Errno(rawValue: errno)
    }

    self.parent = parentFd
    self.child = childFd
  }
}

/// Simple POSIX errno wrapper.
struct Errno: Error, RawRepresentable {
  /// The raw POSIX error number.
  let rawValue: Int32

  init(rawValue: Int32) {
    self.rawValue = rawValue
  }
}

extension Errno: CustomStringConvertible {
  var description: String {
    var buf = [CChar](repeating: 0, count: 256)
    strerror_r(rawValue, &buf, buf.count)
    return String(cString: buf)
  }
}
