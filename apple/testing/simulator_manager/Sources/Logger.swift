import os.log

extension Logger {
  static func simulatorManager(category: String) -> Logger {
    Logger(
      subsystem: "com.example.tools.simulator_manager",
      category: category
    )
  }
}
