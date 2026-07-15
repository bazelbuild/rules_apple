import SwiftUI

@main
struct ExampleAppClip: App {
  var body: some Scene {
    WindowGroup {
      VStack(spacing: 12) {
        Text("App Clip")
          .font(.title)
        Text("OK, I'm the App Clip.")
      }
      .padding()
    }
  }
}