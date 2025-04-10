// Copyright 2025 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI

struct ToggleImmersiveSpaceButton: View {

  @Environment(AppModel.self) private var appModel

  @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
  @Environment(\.openImmersiveSpace) private var openImmersiveSpace

  var body: some View {
    Button {
      Task { @MainActor in
        switch appModel.immersiveSpaceState {
        case .open:
          appModel.immersiveSpaceState = .inTransition
          await dismissImmersiveSpace()
        // Don't set immersiveSpaceState to .closed because there
        // are multiple paths to ImmersiveView.onDisappear().
        // Only set .closed in ImmersiveView.onDisappear().

        case .closed:
          appModel.immersiveSpaceState = .inTransition
          switch await openImmersiveSpace(id: appModel.immersiveSpaceID) {
          case .opened:
            // Don't set immersiveSpaceState to .open because there
            // may be multiple paths to ImmersiveView.onAppear().
            // Only set .open in ImmersiveView.onAppear().
            break

          case .userCancelled, .error:
            // On error, we need to mark the immersive space
            // as closed because it failed to open.
            fallthrough
          @unknown default:
            // On unknown response, assume space did not open.
            appModel.immersiveSpaceState = .closed
          }

        case .inTransition:
          // This case should not ever happen because button is disabled for this case.
          break
        }
      }
    } label: {
      Text(appModel.immersiveSpaceState == .open ? "Hide Immersive Space" : "Show Immersive Space")
    }
    .disabled(appModel.immersiveSpaceState == .inTransition)
    .animation(.none, value: 0)
    .fontWeight(.semibold)
  }
}
