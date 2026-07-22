import SwiftUI

@main
struct HostApp: App {
  var body: some Scene {
    WindowGroup {
      VStack(spacing: 12) {
        Text("Host Application")
          .font(.title)
        Text("This application contains an App Clip.")
      }
      .padding()
    }
  }
}