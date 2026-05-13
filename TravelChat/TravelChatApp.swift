// Copyright (c) 2026 Tc Pun / TCPUN Studio
// Licensed under the MIT License. See LICENSE for details.

import SwiftUI

@main
struct TravelChatApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ChatView()
            }
        }
        .windowResizability(.contentSize)
    }
}
