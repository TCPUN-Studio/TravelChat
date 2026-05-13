// Copyright (c) 2026 Tc Pun / TCPUN Studio
// Licensed under the MIT License. See LICENSE for details.

import Foundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String

    enum Role {
        case user, assistant
    }
}
